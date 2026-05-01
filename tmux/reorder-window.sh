#!/usr/bin/env bash
# Move the current tmux window to TARGET, shifting other windows by one to
# make room (preserving their relative order). Invoked from .tmux.conf.
set -euo pipefail

target="${1:?target index required}"
current=$(tmux display-message -p '#I')

base_index=$(tmux show-option -gv base-index 2>/dev/null || echo 0)
last_index=$(tmux list-windows -F '#I' | sort -n | tail -n1)

(( target < base_index )) && target=$base_index
(( target > last_index )) && target=$last_index
(( current == target )) && exit 0

# Park current at a guaranteed-free high index.
tmp=9999
while tmux list-windows -F '#I' | grep -qx "$tmp"; do
    tmp=$((tmp + 1))
done
tmux move-window -s ":$current" -t ":$tmp"

if (( current < target )); then
    # current moved up: shift indices in (current, target] down by 1, ascending.
    tmux list-windows -F '#I' | grep -v "^${tmp}$" | sort -n | while read -r i; do
        if (( i > current && i <= target )); then
            tmux move-window -s ":$i" -t ":$((i - 1))"
        fi
    done
else
    # current moved down: shift indices in [target, current) up by 1, descending.
    tmux list-windows -F '#I' | grep -v "^${tmp}$" | sort -rn | while read -r i; do
        if (( i >= target && i < current )); then
            tmux move-window -s ":$i" -t ":$((i + 1))"
        fi
    done
fi

tmux move-window -s ":$tmp" -t ":$target"
