#!/usr/bin/env bash
# Fixtures for tests/dotfiles-install-lib.bats — unit tests of the sourceable
# install helpers in bin/dotfiles-install-lib. The genuinely external touchpoints
# (command -v probing, the interactive prompt, the package manager) are stubbed
# so ensure_tool's dispatch logic can be tested without brew/apt/sudo or a tty.

REAL_DOTFILES="${BATS_TEST_DIRNAME}/.."

load_install_lib() {
  # shellcheck source=bin/dotfiles-install-lib
  source "$REAL_DOTFILES/bin/dotfiles-install-lib"
}
