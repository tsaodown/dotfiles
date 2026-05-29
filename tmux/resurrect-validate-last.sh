#!/usr/bin/env bash
# If the 'last' symlink points to a 0-byte file (happens when kill-server
# races with a continuum interval save), re-point it to the most recent
# non-empty save so continuum's auto-restore has something to load.
RESURRECT_DIR="${HOME}/.local/share/tmux/resurrect"
LAST="${RESURRECT_DIR}/last"

[ -L "$LAST" ] && [ ! -s "$LAST" ] || exit 0

GOOD=$(find "$RESURRECT_DIR" -maxdepth 1 -name 'tmux_resurrect_*.txt' ! -empty | sort -r | head -1)
[ -n "$GOOD" ] && ln -sf "$(basename "$GOOD")" "$LAST"
