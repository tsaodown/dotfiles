#!/usr/bin/env bats
# Regression guard for the Alt-Shift-hjkl move-pane binds (see the comment block
# above them in tmux/keys-{macos,linux}.conf).
#
# Two things about these binds are load-bearing and invisible:
#   - no -d on swap-pane. With -d, focus stays on the vacated slot and the pane
#     you were reading walks away without you. The reorder-window chord next door
#     needs swap-window -d for the equivalent effect, so -d reads like an
#     omission a future edit would "fix".
#   - the pane_at_* gate. Without it {up-of} wraps to the far edge, and while
#     natively zoomed the directional targets mis-resolve (the active pane fills
#     the window, so {up-of} returns the pane *below*) — the gate is what keeps a
#     zoomed window inert instead of moving panes the wrong way.
#
# A root-table bind can't be triggered headlessly (send-keys writes to the pane,
# not through the key table), so the behaviour tests run the shipped bind's own
# command string. Everything drives text lifted out of the keys files, so an edit
# there can't silently pass.

KEYS_MACOS="${BATS_TEST_DIRNAME}/../tmux/keys-macos.conf"
KEYS_LINUX="${BATS_TEST_DIRNAME}/../tmux/keys-linux.conf"

setup() {
  SOCK="dotfiles-movepane-$$-${BATS_TEST_NUMBER}-${RANDOM}"
  # -f /dev/null so the real config (tpm, continuum restore) stays out of this.
  tmux -L "$SOCK" -f /dev/null new-session -d -s t -x 80 -y 40
  tmux -L "$SOCK" setw -g pane-base-index 1
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

t() { tmux -L "$SOCK" "$@"; }

# The four shipped bind lines, continuations joined so each is one line.
move_binds() {
  awk '
    /^#cs Pane move$/ { blk = 1; next }
    /^#cs-skip-end$/  { if (blk) exit }
    !blk || /^#/      { next }
    NF {
      line = $0
      while (line ~ /\\$/) {
        sub(/\\$/, "", line)
        if ((getline nxt) <= 0) break
        sub(/^[[:space:]]+/, " ", nxt)
        line = line nxt
      }
      print line
    }
  ' "$1"
}

# Just the command part of one direction's bind, with the key token stripped.
move_cmd() {
  move_binds "${2:-$KEYS_MACOS}" \
    | grep -F "{$1-of}" \
    | sed -E 's/^bind -n [^ ]+[[:space:]]*//'
}

# Pane ids in layout order, e.g. "%0 %1 %2 %3".
pane_order() { t list-panes -F '#{pane_id}' | tr '\n' ' '; }

# Build a flat vertical stack of $1 panes and focus the pane at index $2.
stack() {
  local n="$1" focus="$2" i
  for ((i = 1; i < n; i++)); do t split-window -v -t t; done
  t select-pane -t "$focus"
}

@test "move-pane: both keys files ship four binds tmux actually parses" {
  local file
  for file in "$KEYS_MACOS" "$KEYS_LINUX"; do
    move_binds "$file" > "$BATS_TEST_TMPDIR/binds.conf"
    [ "$(grep -c . "$BATS_TEST_TMPDIR/binds.conf")" -eq 4 ]

    run t source-file "$BATS_TEST_TMPDIR/binds.conf"
    [ "$status" -eq 0 ]

    # tmux's own MouseDown3Pane menu contains swap-pane -U/-D, so match on the
    # directional form to count only ours.
    run t list-keys -T root
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -c -- "swap-pane -s '{")" -eq 4 ]

    # Both files bind the same commands to different keys, so clear this file's
    # keys before the next pass or the count doubles.
    while read -r key; do t unbind -n "$key"; done \
      < <(move_binds "$file" | awk '{print $3}')
  done
}

@test "move-pane: no -d on the swap, so focus follows the moved pane" {
  local dir cmd
  for dir in left down up right; do
    cmd="$(move_cmd "$dir")"
    [ -n "$cmd" ]
    [[ "$cmd" == *"swap-pane -s '{$dir-of}'"* ]]
    # Any flag on swap-pane at all: the shipped form takes only -s.
    ! [[ "$(printf '%s' "$cmd" | sed -E 's/.*swap-pane//; s/;.*//')" == *" -d"* ]]
  done
}

@test "move-pane: each direction is gated on its own window edge" {
  local pairs="left:pane_at_left down:pane_at_bottom up:pane_at_top right:pane_at_right"
  local pair dir fmt cmd
  for pair in $pairs; do
    dir="${pair%%:*}"; fmt="${pair##*:}"
    cmd="$(move_cmd "$dir")"
    [[ "$cmd" == *"$fmt"* ]]
  done
}

@test "move-pane: mid-stack move carries focus to the new slot" {
  stack 4 3
  local moved before
  moved="$(t display -p '#{pane_id}')"
  before="$(pane_order)"

  eval "t $(move_cmd up)"

  [ "$(pane_order)" != "$before" ]
  # Same pane still focused, now one slot earlier.
  [ "$(t display -p '#{pane_id}')" = "$moved" ]
  [ "$(t display -p '#{pane_index}')" -eq 2 ]
}

@test "move-pane: gated at the top edge — repeats no-op instead of wrapping" {
  stack 4 1
  local before n
  before="$(pane_order)"
  for n in 1 2 3; do eval "t $(move_cmd up)"; done
  [ "$(pane_order)" = "$before" ]
  [ "$(t display -p '#{pane_index}')" -eq 1 ]
}

@test "move-pane: left/right inert in a flat stack (every pane spans the width)" {
  stack 4 3
  local before
  before="$(pane_order)"
  eval "t $(move_cmd left)"
  eval "t $(move_cmd right)"
  [ "$(pane_order)" = "$before" ]
}

@test "move-pane: macOS and Linux binds differ only in the key token" {
  local dir
  for dir in left down up right; do
    [ "$(move_cmd "$dir" "$KEYS_MACOS")" = "$(move_cmd "$dir" "$KEYS_LINUX")" ]
  done
}
