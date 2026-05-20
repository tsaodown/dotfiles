#!/usr/bin/env bash
# Toggle/apply a "soft" zoom for the current window's active pane.
# Shrinks every non-active pane to its minimum size so the active pane
# dominates while neighbors stay visible — their pane-border-format labels
# act as top/bottom edge hints. Left/right neighbors are surfaced separately
# via the status line (see soft-zoom-hints.sh).
#
# Subcommands:
#   toggle  — flip soft-zoom for the current window (default)
#   on      — turn on (save layout, shrink neighbors)
#   off     — turn off (restore saved layout, falling back to even layout
#             if the saved one no longer matches — e.g. a pane was killed)
#   apply   — re-shrink neighbors; used by after-select-pane so navigating
#             with Alt-hjkl re-zooms the new active pane
#   refresh — when soft-zoomed, re-save current layout and re-shrink; used
#             by after-kill-pane / pane-exited so the restore point stays
#             valid after a pane disappears

set -euo pipefail

apply_shrink() {
  # Grow the active pane to the maximum the layout allows; tmux clamps each
  # axis to leave siblings at their minimums, which yields slivers around
  # the active pane in one shot. Iterating siblings instead doesn't work in
  # nested layouts because shrinking one neighbor gives its freed space to
  # another neighbor, not back to the active pane.
  tmux resize-pane -x 9999 -y 9999 2>/dev/null || true
}

even_all_groups() {
  # `select-layout -E` only evens the target pane's immediate group. In a
  # nested layout (e.g. top H-split and bottom H-split as siblings of a root
  # V-split), an -E on a pane in the top group leaves the bottom group at
  # whatever sizes it currently has. Iterating over every pane and calling
  # -E with each as the target ensures every group is evened — redundant
  # passes within the same group are no-ops.
  while read -r pane; do
    tmux select-layout -t "$pane" -E 2>/dev/null || true
  done < <(tmux list-panes -F '#{pane_id}')
}

is_on() {
  [ "$(tmux show -wqv @soft-zoomed 2>/dev/null)" = "1" ]
}

turn_on() {
  tmux setw @soft-zoomed-layout "$(tmux display -p '#{window_layout}')"
  tmux setw @soft-zoomed 1
  apply_shrink
}

turn_off() {
  local layout
  layout="$(tmux show -wqv @soft-zoomed-layout 2>/dev/null || true)"
  if [ -n "$layout" ]; then
    tmux select-layout "$layout" 2>/dev/null || tmux select-layout -E
  fi
  tmux setw @soft-zoomed 0
  tmux setw -uq @soft-zoomed-layout 2>/dev/null || true
}

case "${1:-toggle}" in
  toggle)
    if is_on; then turn_off; else turn_on; fi
    ;;
  on)      turn_on ;;
  off)     turn_off ;;
  apply)
    if is_on; then apply_shrink; fi
    ;;
  refresh)
    if is_on; then
      even_all_groups
      tmux setw @soft-zoomed-layout "$(tmux display -p '#{window_layout}')"
      apply_shrink
    fi
    ;;
  post-split)
    # After a split during soft-zoom, the new pane is half of the active pane
    # and other panes are still in their pre-split sliver sizes. Even every
    # group first so toggle-off restores to a sane state, then re-save and
    # re-shrink so the new (active) pane becomes dominant.
    if is_on; then
      even_all_groups
      tmux setw @soft-zoomed-layout "$(tmux display -p '#{window_layout}')"
      apply_shrink
    fi
    ;;
  *)
    echo "usage: $0 [toggle|on|off|apply|refresh|post-split]" >&2
    exit 2
    ;;
esac
