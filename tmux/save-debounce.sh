#!/bin/bash
# Only run resurrect save if one hasn't run in the last N seconds.
# Prevents a burst of notifications when all kitty windows detach simultaneously.
STAMP="${TMPDIR:-/tmp}/tmux-resurrect-save.stamp"
WINDOW=5

now=$(date +%s)
last=$(cat "$STAMP" 2>/dev/null || echo 0)

(( now - last < WINDOW )) && exit 0

echo "$now" > "$STAMP"
exec "$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
