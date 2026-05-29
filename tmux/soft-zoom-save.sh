#!/usr/bin/env bash
# Saves @soft-zoomed state for all windows alongside the resurrect save file.
# Called via @resurrect-hook-post-save-all.
set -euo pipefail

STATE_FILE="${HOME}/.local/share/tmux/resurrect/soft-zoom-state.txt"
tmux list-windows -a -F '#{session_name} #{window_index} #{@soft-zoomed}' 2>/dev/null \
  | awk '$3 == "1" {print $1, $2}' \
  > "$STATE_FILE"
