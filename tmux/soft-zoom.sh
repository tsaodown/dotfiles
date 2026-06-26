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

# Collapse overlapping reapply_all runs. client-attached and window-resized
# both call reapply-all, and a single client attach re-fits *every* window at
# once — so restoring N soft-zoomed windows fires a burst of window-resized
# events, each spawning a reapply_all that iterates all windows and forks
# several tmux subcommands per window. Stacked on top of the 1s status-line
# #() jobs (pane-minimap.py / soft-zoom-hints.sh, which also shell into tmux),
# that burst can saturate the server forking faster than the runs drain — a
# redraw/fork storm that pegs it at ~100% and wedges every client (observed:
# a server stuck 30 min at 76%, taking the whole terminal down via the
# `tmux ls` in config.fish). A non-blocking lock makes concurrent reapply_all
# runs no-ops: the in-flight run already converges to the latest state, and
# any event it raced is re-delivered by a later hook (apply_shrink is
# idempotent on an already-slivered window). The holder PID lets a run whose
# process died (e.g. server kill -9 mid-apply) be reclaimed rather than
# blocking soft-zoom forever.
SZ_LOCK="${TMPDIR:-/tmp}/soft-zoom-$(id -u).lock"

# Interpreter for soft-zoom-relayout.py. Prefer the system python3 over a
# version-manager shim (pyenv/asdf/mise): a shim adds ~250ms of resolve-and-exec
# startup to *every* invocation, and relayout now runs on every soft-zoom apply
# (i.e. every pane nav) — the shim turns a ~70ms nav into a ~300ms one. relayout.py
# is plain stdlib (3.6+), so the stock interpreter is fine. Falls back to PATH
# python3 if there's no /usr/bin/python3 (e.g. non-macOS).
SZ_PY=python3
[ -x /usr/bin/python3 ] && SZ_PY=/usr/bin/python3

reapply_lock_or_skip() {
  if mkdir "$SZ_LOCK" 2>/dev/null; then
    echo $$ >"$SZ_LOCK/pid" 2>/dev/null || true
    trap 'rm -rf "$SZ_LOCK" 2>/dev/null' EXIT
    return 0
  fi
  # Lock held — reclaim it if the holder is gone, otherwise skip this run.
  local holder
  holder="$(cat "$SZ_LOCK/pid" 2>/dev/null || true)"
  if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
    rm -rf "$SZ_LOCK" 2>/dev/null || true
    if mkdir "$SZ_LOCK" 2>/dev/null; then
      echo $$ >"$SZ_LOCK/pid" 2>/dev/null || true
      trap 'rm -rf "$SZ_LOCK" 2>/dev/null' EXIT
      return 0
    fi
  fi
  exit 0
}

apply_shrink() {
  # Make the active pane dominate in a SINGLE geometry change: read the active
  # pane id + the window's current layout, rewrite it to a content-correct
  # "active dominates, every other pane slivered to its structural minimum"
  # layout (see soft-zoom-relayout.py), and apply that in one `select-layout`.
  #
  # One select-layout = one redraw = at most one SIGWINCH per pane, so there's
  # no intermediate-sliver flash and TUIs like claude redraw once, not three
  # times. This replaces the old three-pass pipeline (shrink-everyone +
  # grow-active resize pass, an area-gated layout-string rewrite, then a
  # corrective sliver bump): relayout.py converges directly on the same clean
  # end-state those three passes used to reach, and is border-status aware so
  # the window-top pane never lands at 0 content rows (the ┬-artifact glitch).
  # relayout.py only acts on the layout string, so unlike resize-pane it has no
  # trouble reaching panes buried in a same-orientation nested group.
  #
  # On an already-slivered window the rewrite reproduces the current layout
  # byte-for-byte, so select-layout is a no-op (no size change -> no SIGWINCH);
  # re-running on every hook is cheap.
  #
  # $1: optional target window (e.g. "main:3"); empty = the caller's current
  #     window, i.e. the hook context for after-select-pane and friends.
  local t="" info active layout new
  [ -n "${1:-}" ] && t="-t $1"
  # active pane id + layout in one fork; window_layout has no '|', so split safe.
  # shellcheck disable=SC2086  # $t must word-split into "-t <win>" or vanish
  info="$(tmux display -p $t '#{pane_id}|#{window_layout}' 2>/dev/null)" || return 0
  active="${info%%|*}"
  layout="${info#*|}"
  [ -n "$active" ] && [ -n "$layout" ] || return 0
  new="$("$SZ_PY" ~/dotfiles/tmux/soft-zoom-relayout.py "$layout" "$active" 2>/dev/null)" || new=""
  if [ -n "$new" ]; then
    # shellcheck disable=SC2086
    tmux select-layout $t "$new" 2>/dev/null || true
  else
    # Degraded fallback (python3 missing, or relayout refused to emit because no
    # content-correct layout fits): best-effort resize so the active pane still
    # dominates. May leave the top-sliver glitch the primary path exists to
    # prevent, but keeps soft-zoom functional. Batched into one fork.
    local cmd="" p
    # shellcheck disable=SC2086
    while read -r p; do
      cmd="$cmd resize-pane -t $p -x 1 -y 1 ; "
    done < <(tmux list-panes $t -F '#{pane_id} #{pane_active}' | awk '$2 == 0 {print $1}')
    cmd="$cmd resize-pane -t $active -x 9999 -y 9999"
    # shellcheck disable=SC2086  # intentional word-split into tmux command tokens
    tmux $cmd 2>/dev/null || true
  fi

  # Always succeed: apply_shrink is best-effort, and reapply_all's per-window
  # loop runs under `set -e` — a non-zero exit here would abort the rest.
  return 0
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
  #
  # Guarded so a burst of attach/resize-driven calls collapses to one run
  # instead of stacking into a server-pegging fork storm — see SZ_LOCK above.
  reapply_lock_or_skip
  while read -r target; do
    apply_shrink "$target" || true   # one window's failure must not skip the rest
  done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{@soft-zoomed}' \
             | awk '$2 == "1" {print $1}')
}

turn_on() {
  tmux setw @soft-zoomed 1
  apply_shrink
}

turn_off() {
  # Always evenly split every group, at every nesting level, so the window
  # comes back balanced regardless of how it was arranged before zooming. The
  # layout-string rewrite (soft-zoom-relayout.py even mode) reaches every level
  # while preserving structure; `select-layout -E` (and the per-pane
  # even_all_groups built on it) only evens a pane's *immediate* group, leaving
  # a nested layout's root/ancestor rows unbalanced — so it's the last-resort
  # fallback only if the rewrite is unavailable (e.g. python missing).
  local cur new
  cur="$(tmux display -p '#{window_layout}' 2>/dev/null || true)"
  new="$("$SZ_PY" ~/dotfiles/tmux/soft-zoom-relayout.py "$cur" even 2>/dev/null || true)"
  if [ -z "$new" ] || ! tmux select-layout "$new" 2>/dev/null; then
    even_all_groups
  fi
  tmux setw @soft-zoomed 0
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
