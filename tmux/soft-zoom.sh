#!/usr/bin/env bash
# Toggle/apply a "soft" zoom for the current window's active pane.
# Shrinks every non-active pane to its minimum size so the active pane
# dominates while neighbors stay visible — their pane-border-format labels
# act as top/bottom edge hints. Left/right neighbors are surfaced separately
# via the status line (see soft-zoom-hints.sh).
#
# Subcommands:
#   toggle     — flip soft-zoom for the current window (default)
#   on         — turn on (save layout, shrink neighbors)
#   off        — turn off (restore saved layout, falling back to a fully
#                evened layout if the saved one no longer matches — e.g.
#                after a split or kill while soft-zoomed)
#   apply      — re-shrink neighbors; used by after-select-pane so navigating
#                with Alt-hjkl re-zooms the new active pane
#   refresh    — re-shrink neighbors; used by after-kill-pane / pane-exited
#                so the active pane stays dominant after a sibling dies
#   post-split — re-shrink neighbors; used by after-split-window so the new
#                (active) pane dominates immediately after a split

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
  # whatever sizes it currently has. Issuing -E for every pane ensures every
  # group is evened — redundant passes within the same group are no-ops.
  #
  # Batched into a single tmux invocation with ';' separators (one fork
  # instead of N) — fewer interleaved layout events for hooks downstream.
  local cmd=""
  while read -r pane; do
    [ -n "$cmd" ] && cmd+=" ; "
    cmd+="select-layout -t $pane -E"
  done < <(tmux list-panes -F '#{pane_id}')
  [ -n "$cmd" ] || return 0
  # shellcheck disable=SC2086  # intentional word-split into tmux command tokens
  tmux $cmd 2>/dev/null || true
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
  # Try to restore the layout snapshotted at turn_on. After any split/kill
  # while soft-zoomed, pane IDs in the snapshot are stale and select-layout
  # will fail — fall back to evening every group so nested layouts come out
  # balanced (plain `select-layout -E` would only even the immediate group).
  local layout
  layout="$(tmux show -wqv @soft-zoomed-layout 2>/dev/null || true)"
  if [ -z "$layout" ] || ! tmux select-layout "$layout" 2>/dev/null; then
    even_all_groups
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
  refresh|post-split)
    # On kill / exit / split during soft-zoom: just re-shrink so the (new)
    # active pane dominates. We deliberately do NOT call even_all_groups or
    # re-save the layout here — each select-layout in even_all_groups can
    # trigger SIGWINCH across panes, and TUIs like claude redraw on SIGWINCH,
    # leaving duplicate / overwritten content in the scrollback. apply_shrink
    # is a single idempotent resize-pane call; turn_off's fallback handles
    # rebalancing if the user toggles off later.
    if is_on; then apply_shrink; fi
    ;;
  *)
    echo "usage: $0 [toggle|on|off|apply|refresh|post-split]" >&2
    exit 2
    ;;
esac
