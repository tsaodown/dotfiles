#!/usr/bin/env bash
# Fixtures for tests/dotfiles-watcher-lib.bats — unit tests of the pure,
# sourceable helpers in bin/dotfiles-watcher-lib. No daemon, no fswatch.

REAL_DOTFILES="${BATS_TEST_DIRNAME}/.."

load_watcher_lib() {
  # shellcheck source=bin/dotfiles-watcher-lib
  source "$REAL_DOTFILES/bin/dotfiles-watcher-lib"
}

# A throwaway git repo in $PWD for the conflict-state tests.
new_test_repo() {
  TEST_REPO=$(cd "$(mktemp -d)" && pwd -P)
  cd "$TEST_REPO"
  git init -q
  git checkout -q -B main 2>/dev/null
  git config user.email "test@test.invalid"
  git config user.name "Test"
  git config commit.gpgsign false
  echo base > file
  git add file
  git commit -q -m base
}

cleanup_test_repo() {
  cd /
  [[ -n "${TEST_REPO:-}" && -d "$TEST_REPO" ]] && rm -rf "$TEST_REPO"
  unset TEST_REPO
}

# Drive the repo into an unmerged-index state via a real merge conflict.
make_unmerged() {
  git checkout -q -b other
  echo other > file
  git commit -q -am other
  git checkout -q main
  echo mine > file
  git commit -q -am mine
  git merge other >/dev/null 2>&1 || true   # conflicts, leaves unmerged entries
}

# Drive the repo into an in-progress (conflicted) rebase.
make_rebasing() {
  git checkout -q -b other
  echo other > file
  git commit -q -am other
  git checkout -q main
  echo mine > file
  git commit -q -am mine
  git rebase other >/dev/null 2>&1 || true  # conflicts, leaves a rebase dir
}
