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
