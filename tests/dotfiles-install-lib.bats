#!/usr/bin/env bats
# Unit tests for bin/dotfiles-install-lib — ensure_tool's dispatch logic.
# `have` (probe), `ask` (prompt), and `pkg_install` (the package manager) are
# the unavoidable externals; each test stubs them and asserts what gets
# installed via a recording file.

load install-lib-helpers

setup() {
  load_install_lib
  RECORD="$(mktemp)"
  # Stub the package manager: record the package name instead of installing it.
  pkg_install() { echo "$1" >> "$RECORD"; }
}

teardown() {
  rm -f "$RECORD"
}

@test "ensure_tool: an already-present tool installs nothing" {
  have() { return 0; }
  ask()  { return 0; }
  OS=Darwin
  ensure_tool stow stow stow
  [ ! -s "$RECORD" ]
}

@test "ensure_tool: absent on macOS installs the darwin package when accepted" {
  have() { return 1; }
  ask()  { return 0; }
  OS=Darwin
  ensure_tool fish fish fish-shell
  [ "$(cat "$RECORD")" = "fish" ]
}

@test "ensure_tool: absent on Linux installs the linux package when accepted" {
  have() { return 1; }
  ask()  { return 0; }
  OS=Linux
  ensure_tool fish fish fish-shell
  [ "$(cat "$RECORD")" = "fish-shell" ]
}

@test "ensure_tool: a declined install installs nothing" {
  have() { return 1; }
  ask()  { return 1; }
  OS=Darwin
  ensure_tool fish fish fish
  [ ! -s "$RECORD" ]
}

@test "ensure_tool: a macOS-only tool ('-' linux package) is skipped on Linux" {
  have() { return 1; }
  ask()  { return 0; }   # even if it would say yes, nothing must install
  OS=Linux
  ensure_tool flock flock -
  [ ! -s "$RECORD" ]
}

@test "ensure_tool: probe accepts alternatives — any present means satisfied" {
  have() { [[ "$1" == "timeout" ]]; }   # gtimeout absent, timeout present
  ask()  { return 0; }
  OS=Darwin
  ensure_tool "gtimeout timeout" coreutils -
  [ ! -s "$RECORD" ]
}

# ask — once the installer sets ASSUME_YES (after the up-front checklist), every
# later prompt must auto-confirm without reading or printing anything.

@test "ask: ASSUME_YES=1 returns yes without prompting (even when default is N)" {
  ASSUME_YES=1
  run ask "install something?" N
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# parse_toggles — pure validator for one round of checklist toggle input.

@test "parse_toggles: comma/space-separated numbers in range are accepted in order" {
  run parse_toggles "4, 7 2" 7
  [ "$status" -eq 0 ]
  [ "$output" = "4 7 2" ]
}

@test "parse_toggles: empty input is valid and yields no toggles" {
  run parse_toggles "" 7
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_toggles: an out-of-range number is rejected with no output" {
  run parse_toggles "9" 7
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "parse_toggles: a non-numeric token is rejected with no output" {
  run parse_toggles "x" 7
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "parse_toggles: leading-zero tokens are read base-10, not octal" {
  run parse_toggles "08" 8
  [ "$status" -eq 0 ]
  [ "$output" = "8" ]
}

# ensure_app dispatch — present_fn, ask, and the OS-specific install fns are the
# externals; each test stubs them and the install stubs record which ran, so we
# assert the dispatch (present→skip, decline→noop, OS→correct fn) without
# touching brew/apt or the real install bodies.

@test "ensure_app: an already-present app installs nothing" {
  present() { return 0; }
  ask()     { return 0; }
  mac()     { echo mac   >> "$RECORD"; }
  lin()     { echo linux >> "$RECORD"; }
  OS=Darwin
  ensure_app Foo present mac lin
  [ ! -s "$RECORD" ]
}

@test "ensure_app: a declined install installs nothing" {
  present() { return 1; }
  ask()     { return 1; }
  mac()     { echo mac   >> "$RECORD"; }
  lin()     { echo linux >> "$RECORD"; }
  OS=Darwin
  ensure_app Foo present mac lin
  [ ! -s "$RECORD" ]
}

@test "ensure_app: absent on macOS runs the macos install fn" {
  present() { return 1; }
  ask()     { return 0; }
  mac()     { echo mac   >> "$RECORD"; }
  lin()     { echo linux >> "$RECORD"; }
  OS=Darwin
  ensure_app Foo present mac lin
  [ "$(cat "$RECORD")" = "mac" ]
}

@test "ensure_app: absent on Linux runs the linux install fn" {
  present() { return 1; }
  ask()     { return 0; }
  mac()     { echo mac   >> "$RECORD"; }
  lin()     { echo linux >> "$RECORD"; }
  OS=Linux
  ensure_app Foo present mac lin
  [ "$(cat "$RECORD")" = "linux" ]
}

# ensure_app_key — the thin wrapper that derives the three per-app function names
# from an apps.tsv key (<key>_present / <key>_install_mac / <key>_install_linux)
# and delegates to ensure_app, so the installer can drive apps.tsv rows by key.

@test "ensure_app_key: derives <key>_* function names and runs the macOS installer" {
  demo_present()      { return 1; }
  demo_install_mac()  { echo mac   >> "$RECORD"; }
  demo_install_linux(){ echo linux >> "$RECORD"; }
  ask() { return 0; }
  OS=Darwin
  ensure_app_key demo "Demo App"
  [ "$(cat "$RECORD")" = "mac" ]
}

@test "ensure_app_key: derives <key>_* function names and runs the Linux installer" {
  demo_present()      { return 1; }
  demo_install_mac()  { echo mac   >> "$RECORD"; }
  demo_install_linux(){ echo linux >> "$RECORD"; }
  ask() { return 0; }
  OS=Linux
  ensure_app_key demo "Demo App"
  [ "$(cat "$RECORD")" = "linux" ]
}

# https_to_ssh_url — pure transform from a GitHub HTTPS remote to its SSH form.

@test "https_to_ssh_url: plain https URL → ssh form" {
  [ "$(https_to_ssh_url https://github.com/tsaodown/dotfiles)" = "git@github.com:tsaodown/dotfiles.git" ]
}

@test "https_to_ssh_url: .git suffix is not doubled" {
  [ "$(https_to_ssh_url https://github.com/tsaodown/dotfiles.git)" = "git@github.com:tsaodown/dotfiles.git" ]
}

@test "https_to_ssh_url: trailing slash is stripped" {
  [ "$(https_to_ssh_url https://github.com/tsaodown/dotfiles/)" = "git@github.com:tsaodown/dotfiles.git" ]
}

@test "https_to_ssh_url: an already-ssh URL is rejected (returns 1, no output)" {
  run https_to_ssh_url git@github.com:tsaodown/dotfiles.git
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "https_to_ssh_url: a non-github https URL is rejected" {
  run https_to_ssh_url https://gitlab.com/tsaodown/dotfiles
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# fix_origin_to_ssh — rewrites origin only when it's an https github URL. Uses a
# real temp git repo (the watcher tests use filesystem repos the same way).

setup_repo() {   # echoes a fresh repo dir with origin set to $1
  local dir; dir="$(mktemp -d)"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$1"
  echo "$dir"
}

@test "fix_origin_to_ssh: https github origin is rewritten to SSH" {
  local dir; dir="$(setup_repo https://github.com/tsaodown/dotfiles.git)"
  fix_origin_to_ssh "$dir"
  [ "$(git -C "$dir" remote get-url origin)" = "git@github.com:tsaodown/dotfiles.git" ]
  rm -rf "$dir"
}

@test "fix_origin_to_ssh: an already-ssh origin is left unchanged" {
  local dir; dir="$(setup_repo git@github.com:tsaodown/dotfiles.git)"
  fix_origin_to_ssh "$dir"
  [ "$(git -C "$dir" remote get-url origin)" = "git@github.com:tsaodown/dotfiles.git" ]
  rm -rf "$dir"
}

@test "fix_origin_to_ssh: a non-github origin is left unchanged" {
  local dir; dir="$(setup_repo https://gitlab.com/tsaodown/dotfiles.git)"
  fix_origin_to_ssh "$dir"
  [ "$(git -C "$dir" remote get-url origin)" = "https://gitlab.com/tsaodown/dotfiles.git" ]
  rm -rf "$dir"
}

# ensure_github_ssh — best-effort orchestrator that runs under the installer's
# live `set -e`. On a fresh box `git config --global user.email` is unset and
# exits non-zero; generate_ssh_key's comment-default assignment must not let that
# abort the whole bootstrap. Replicate the installer faithfully: call it BARE
# inside a real `set -euo pipefail` shell (bats `run` would neutralise errexit,
# which is the very mechanism under test) with the externals stubbed so the git
# config line is the only command that legitimately returns non-zero.
@test "ensure_github_ssh: unset git user.email under set -e doesn't abort (fresh-install regression)" {
  local bindir; bindir="$(mktemp -d)"
  # ssh-keygen: create the key pair the later steps expect, no prompts.
  cat > "$bindir/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
f=
while [ $# -gt 0 ]; do [ "$1" = "-f" ] && f="$2"; shift; done
: > "$f"; : > "$f.pub"
EOF
  # ssh: GitHub-style auth failure, so github_ssh_ok stays false (forces the
  # generate-key path that contains the regression).
  printf '#!/usr/bin/env bash\necho "Permission denied (publickey)." >&2\nexit 255\n' > "$bindir/ssh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$bindir/gh"          # never authed
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bindir/ssh-add"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bindir/ssh-agent"
  chmod +x "$bindir"/*

  local repo; repo="$(setup_repo https://github.com/tsaodown/dotfiles.git)"

  run env PATH="$bindir:$PATH" HOME="$(mktemp -d)" GIT_CONFIG_GLOBAL=/dev/null NO_COLOR=1 \
    bash -c "set -euo pipefail; source '$REAL_DOTFILES/bin/dotfiles-install-lib'; ensure_github_ssh '$repo' machine-name; echo REACHED_END"

  [ "$status" -eq 0 ]
  [[ "$output" == *REACHED_END* ]]
  rm -rf "$bindir" "$repo"
}
