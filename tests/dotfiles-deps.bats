#!/usr/bin/env bats
# Tests for bin/dotfiles-deps — the read-only registry accessor over deps.tsv
# (tools) and apps.tsv (apps). It NEVER installs. Tool presence is probed via
# `command -v`, so tests drive a restricted PATH of stub executables; OS is set
# per-case via the OS env var (mirrors ensure_tool's OS override).

DEPS="${BATS_TEST_DIRNAME}/../bin/dotfiles-deps"

# stub_bin <name>... — make a fresh dir holding no-op executables for each name,
# and echo the dir. Running the accessor with PATH=<dir> makes ONLY these tools
# probe-present (everything else absent). bash is symlinked in so the accessor's
# own `#!/usr/bin/env bash` shebang still resolves under the stripped PATH.
stub_bin() {
  local dir; dir="$(mktemp -d)"
  ln -s "$(command -v bash)" "$dir/bash"
  local n
  for n in "$@"; do
    printf '#!/usr/bin/env bash\n' > "$dir/$n"
    chmod +x "$dir/$n"
  done
  printf '%s\n' "$dir"
}

@test "list core: emits the stow row (probe, pkgs, required, desc), tab-separated" {
  run "$DEPS" list core
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow"$'\t'"stow"$'\t'"stow"$'\t'"yes"$'\t'"stow not found"* ]]
}

@test "list core: includes bat (multi-word probe survives as one field) and excludes other groups" {
  run "$DEPS" list core
  [ "$status" -eq 0 ]
  [[ "$output" == *"bat batcat"$'\t'"bat"$'\t'"bat"$'\t'"no"* ]]
  [[ "$output" != *"fswatch"* ]]   # watcher group, not core
  [[ "$output" != *$'\t'"gh"$'\t'* ]]
}

@test "list watcher: combined fswatch/inotifywait row carries both probe alternatives" {
  run "$DEPS" list watcher
  [ "$status" -eq 0 ]
  [[ "$output" == *"fswatch inotifywait"$'\t'"fswatch"$'\t'"inotify-tools"$'\t'"yes"* ]]
}

@test "apps: emits all five app rows, key<TAB>label<TAB>default (key may differ from label)" {
  run "$DEPS" apps
  [ "$status" -eq 0 ]
  [[ "$output" == *"eza"$'\t'"eza"$'\t'"Y"* ]]
  [[ "$output" == *"onepassword"$'\t'"1Password"$'\t'"Y"* ]]
  [[ "$output" == *"nerdfont"$'\t'"FiraCode Nerd Font"$'\t'"Y"* ]]
  [ "$(echo "$output" | grep -c .)" -eq 5 ]
}

@test "check test: exits 0 when all required tools are present" {
  local bin; bin="$(stub_bin bats parallel)"
  run env PATH="$bin" OS=Darwin "$DEPS" check test
  [ "$status" -eq 0 ]
  rm -rf "$bin"
}

@test "check test: missing required tool exits 1 with the macOS install hint" {
  local bin; bin="$(stub_bin parallel)"   # bats absent
  run env PATH="$bin" OS=Darwin "$DEPS" check test
  [ "$status" -eq 1 ]
  [[ "$output" == *"brew install bats-core"* ]]
  rm -rf "$bin"
}

@test "check test: missing required tool exits 1 with the Linux install hint" {
  local bin; bin="$(stub_bin parallel)"   # bats absent
  run env PATH="$bin" OS=Linux "$DEPS" check test
  [ "$status" -eq 1 ]
  [[ "$output" == *"sudo apt-get install bats"* ]]
  rm -rf "$bin"
}

@test "check core: a missing non-required tool (fish) does NOT fail the preflight" {
  local bin; bin="$(stub_bin stow git)"   # fish/tmux/curl/bat absent but non-required
  run env PATH="$bin" OS=Darwin "$DEPS" check core
  [ "$status" -eq 0 ]
  rm -rf "$bin"
}

@test "check watcher: satisfied when EITHER fswatch or inotifywait is present (combined row)" {
  local bin; bin="$(stub_bin inotifywait)"   # fswatch absent, inotifywait present
  run env PATH="$bin" OS=Linux "$DEPS" check watcher
  [ "$status" -eq 0 ]
  rm -rf "$bin"
}

@test "check watcher: fails when neither file-event backend is present" {
  local bin; bin="$(stub_bin true)"   # neither fswatch nor inotifywait
  run env PATH="$bin" OS=Darwin "$DEPS" check watcher
  [ "$status" -eq 1 ]
  [[ "$output" == *"brew install fswatch"* ]]
  rm -rf "$bin"
}

@test "check watcher: macOS-only deps ('-' linux pkg) never fail the Linux preflight" {
  local bin; bin="$(stub_bin inotifywait)"   # backend present; coreutils/flock absent
  run env PATH="$bin" OS=Linux "$DEPS" check watcher
  [ "$status" -eq 0 ]   # coreutils/flock are linux-pkg '-' and non-required
  rm -rf "$bin"
}

@test "unknown verb exits 2 with usage" {
  run "$DEPS" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

# --- registry lint -------------------------------------------------------------
# The TSVs are hand-edited data; these guard the invariants the accessor and
# installer rely on (and claw back the static checks the old per-call form gave).

DEPS_TSV="${BATS_TEST_DIRNAME}/../deps.tsv"
APPS_TSV="${BATS_TEST_DIRNAME}/../apps.tsv"
LIB="${BATS_TEST_DIRNAME}/../bin/dotfiles-install-lib"

# Emit only data rows (drop comments and blank lines).
data_rows() { grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$1"; }

@test "lint deps.tsv: every data row has exactly 6 tab-separated fields" {
  run bash -c "awk -F'\t' 'NF!=6 {print NR\": \"NF\" fields\"; bad=1} END{exit bad}' <(grep -vE '^[[:space:]]*#|^[[:space:]]*\$' '$DEPS_TSV')"
  [ "$status" -eq 0 ]
}

@test "lint deps.tsv: group is one of core|watcher|test|ssh and required is yes|no" {
  while IFS=$'\t' read -r probe darwin linux group required desc; do
    [[ "$group" =~ ^(core|watcher|test|ssh)$ ]] || { echo "bad group: $group ($probe)"; return 1; }
    [[ "$required" =~ ^(yes|no)$ ]] || { echo "bad required: $required ($probe)"; return 1; }
  done < <(data_rows "$DEPS_TSV")
}

@test "lint deps.tsv: no duplicate probe values" {
  local dups
  dups="$(data_rows "$DEPS_TSV" | cut -f1 | sort | uniq -d)"
  [ -z "$dups" ] || { echo "duplicate probes: $dups"; return 1; }
}

@test "lint apps.tsv: every data row has exactly 3 tab-separated fields" {
  run bash -c "awk -F'\t' 'NF!=3 {print NR\": \"NF\" fields\"; bad=1} END{exit bad}' <(grep -vE '^[[:space:]]*#|^[[:space:]]*\$' '$APPS_TSV')"
  [ "$status" -eq 0 ]
}

@test "lint apps.tsv: every key has its three <key>_* functions defined in the lib" {
  local key label default fn
  while IFS=$'\t' read -r key label default; do
    for fn in "${key}_present" "${key}_install_mac" "${key}_install_linux"; do
      grep -qE "^${fn}\(\)" "$LIB" || { echo "missing function: $fn (key $key)"; return 1; }
    done
  done < <(data_rows "$APPS_TSV")
}
