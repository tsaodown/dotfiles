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
