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
  # Make the active pane dominate: shrink every *other* pane to a 1x1 sliver,
  # then grow the active pane to fill what's left. Both passes, in this order,
  # are load-bearing in nested layouts. tmux's resize-pane only acts within a
  # pane's deepest same-orientation group, so a lone "grow active to max" can't
  # reach panes outside that group when the active pane is buried in a
  # vertical-in-vertical (or horizontal-in-horizontal) nest — those siblings
  # are exactly the panes that appear to "stop resizing" on navigation.
  # Shrinking everyone else first frees their space at every level; the final
  # grow then claims all of it. (A bare grow handles root-level active panes;
  # the shrink pass handles buried ones — neither alone covers both.)
  #
  # Batched into one tmux invocation (';'-separated) so it's a single fork and
  # the layout settles in one shot — fewer interleaved SIGWINCH/redraw events
  # for TUIs like claude. On an already-slivered window every resize is a no-op
  # (no size change -> no SIGWINCH), so re-running is cheap.
  #
  # Residual limit, beyond what resize-pane can express (a fix would need to
  # rewrite the layout string): if a same-orientation nested group is the
  # window's *first* child and the active pane sits inside it, the freed space
  # can land on an unrelated sibling the grow can't reach. Not produced by
  # typical split workflows; noted for the next person.
  #
  # $1: optional target window (e.g. "main:3"); empty = the caller's current
  #     window, i.e. the hook context for after-select-pane and friends.
  local t="" active cmd="" p
  [ -n "${1:-}" ] && t="-t $1"
  # shellcheck disable=SC2086  # $t must word-split into "-t <win>" or vanish
  active="$(tmux display -p $t '#{pane_id}')"
  # shellcheck disable=SC2086
  while read -r p; do
    cmd="$cmd resize-pane -t $p -x 1 -y 1 ; "
  done < <(tmux list-panes $t -F '#{pane_id} #{pane_active}' | awk '$2 == 0 {print $1}')
  cmd="$cmd resize-pane -t $active -x 9999 -y 9999"
  # shellcheck disable=SC2086  # intentional word-split into tmux command tokens
  tmux $cmd 2>/dev/null || true
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

reapply_all() {
  # Re-shrink every window flagged @soft-zoomed=1 to its active pane. Used by
  # the client-attached hook: attaching re-fits each window to the client's
  # size, and growing a window redistributes the new space into the slivers
  # (un-zooming them) even though the @soft-zoomed flag survives. This runs
  # after the attach re-fit, so the shrink is computed at the final size.
  # Re-shrinking an already-slivered window is a near no-op, so re-running on
  # every attach is cheap and triggers no spurious SIGWINCH redraws. Goes
  # through apply_shrink (not a bare resize-to-max) so nested layouts re-sliver
  # correctly here too — see apply_shrink for why the bare grow isn't enough.
  while read -r target; do
    apply_shrink "$target"
  done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{@soft-zoomed}' \
             | awk '$2 == "1" {print $1}')
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
    # is a single batched resize-pane pass (idempotent on an already-slivered
    # window); turn_off's fallback handles rebalancing if the user toggles off
    # later.
    if is_on; then apply_shrink; fi
    ;;
  reapply-all)
    reapply_all ;;
  *)
    echo "usage: $0 [toggle|on|off|apply|refresh|post-split|reapply-all]" >&2
    exit 2
    ;;
esac
