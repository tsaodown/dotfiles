#!/usr/bin/env bash
# Re-applies soft-zoom state after tmux-resurrect restores a session.
# Called via @resurrect-hook-post-restore-all.
#
# Sets the @soft-zoomed flag for each window that had it saved, then shrinks.
# The shrink here covers the case where a client is already attached at restore
# time (window already at final size). When restore runs at server boot with no
# client yet, the shrink happens at a default size and the subsequent attach
# re-fit would un-sliver it — so the client-attached hook (see .tmux.conf)
# re-runs reapply-all after the attach. Double coverage handles both orderings.
set -euo pipefail

STATE_FILE="${HOME}/.local/share/tmux/resurrect/soft-zoom-state.txt"
[ -f "$STATE_FILE" ] || exit 0

while read -r session window_index; do
  [ -z "${session:-}" ] && continue
  tmux setw -t "${session}:${window_index}" @soft-zoomed 1 2>/dev/null || true
done < "$STATE_FILE"

exec "${HOME}/dotfiles/tmux/soft-zoom.sh" reapply-all
