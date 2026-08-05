#!/usr/bin/env bats
# Regression guard for the soft-zoom border-drag capture (see the
# MouseDrag1Border comment in .tmux.conf).
#
# A mouse-aware TUI takes the drag via `send-keys -M`, which installs no
# drag-update callback, so tmux re-resolves the mouse target on every motion
# event. One row of overshoot onto the border below the active pane silently
# becomes `resize-pane -M`. Under soft-zoom that border sits one row below the
# active pane's last content row with the slivers already at minimum, so the
# grab only travels one way and never recovers.
#
# A mouse drag can't be synthesised headlessly, so these cover the two halves
# that can be: the shipped guard's truth table, and that the conf line really
# parses into the gated binding. Both drive the string lifted out of
# .tmux.conf rather than a copy, so an edit there can't silently pass.

TMUX_CONF="${BATS_TEST_DIRNAME}/../tmux/.tmux.conf"

setup() {
  SOCK="dotfiles-softzoom-$$-${BATS_TEST_NUMBER}-${RANDOM}"
  # -f /dev/null so the real config (tpm, continuum restore) stays out of this.
  tmux -L "$SOCK" -f /dev/null new-session -d -s t
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

t() { tmux -L "$SOCK" "$@"; }

# The MouseDrag1Border bind line exactly as shipped.
conf_bind_line() {
  grep -E '^[[:space:]]*bind(-key)?[[:space:]].*MouseDrag1Border' "$TMUX_CONF"
}

# Just its command part, with the cheatsheet annotation trimmed.
conf_bind_cmd() {
  local line
  line="$(conf_bind_line)"
  line="${line%%#cs-skip*}"
  printf '%s' "${line#*MouseDrag1Border}"
}

@test "MouseDrag1Border: .tmux.conf ships a gated binding, not the bare default" {
  local line bind
  line="$(conf_bind_line)"
  [ -n "$line" ]

  printf '%s\n' "$line" > "$BATS_TEST_TMPDIR/bind.conf"
  run t source-file "$BATS_TEST_TMPDIR/bind.conf"
  [ "$status" -eq 0 ]

  # Read the bind back out of the whole table: `list-keys -T <table> <key>`
  # isn't portable — tmux 3.7 escapes the command body there, and in some
  # builds the key filter matches nothing at all. The full listing is stable.
  run t list-keys -T root
  [ "$status" -eq 0 ]
  bind="$(printf '%s\n' "$output" | grep MouseDrag1Border || true)"
  echo "readback: ${bind:-<no MouseDrag1Border bind>}"
  [ -n "$bind" ]

  # Escapes off, so an escaped body reads the same as a quoted one.
  bind="${bind//\\/}"
  [[ "$bind" == *"@soft-zoomed"* ]]
  [[ "$bind" == *"resize-pane -M"* ]]
}

@test "MouseDrag1Border: the shipped guard resizes only while soft-zoom is off" {
  local cmd probe state got
  cmd="$(conf_bind_cmd)"
  [[ "$cmd" == *"@soft-zoomed"* ]]

  # Same guard, observable body — so this exercises the shipped condition
  # rather than a duplicate of it.
  probe="${cmd/resize-pane -M/set -w @probe ran}"
  [ "$probe" != "$cmd" ]
  printf '%s\n' "$probe" > "$BATS_TEST_TMPDIR/probe.conf"

  # unset and "0" both mean soft-zoom off; turn_off writes the literal "0".
  for state in unset 0 1; do
    if [ "$state" = unset ]; then
      t setw -u @soft-zoomed
    else
      t setw @soft-zoomed "$state"
    fi
    t setw @probe blocked
    t source-file "$BATS_TEST_TMPDIR/probe.conf"

    got="$(t show -wv @probe)"
    if [ "$state" = 1 ]; then
      [ "$got" = blocked ]
    else
      [ "$got" = ran ]
    fi
  done
}
