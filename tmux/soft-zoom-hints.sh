#!/usr/bin/env bash
# Print left/right neighbor labels for the active pane, formatted for the
# tmux status line. Top/bottom neighbors are already labeled by
# pane-border-format (the slivers' top borders show their titles), so this
# script surfaces only the horizontal direction.
#
# Output examples:
#   "  ← server  → tests"
#   "  ← server"               (no right neighbor)
#   ""                         (no horizontal neighbors)

set -euo pipefail

read -r active_id a_l a_r a_t a_b < <(
  tmux display -p '#{pane_id} #{pane_left} #{pane_right} #{pane_top} #{pane_bottom}'
)

TAB=$'\t'
# Label mirrors pane-border-format: prefer pane_title when it's been set
# (differs from host) or when current command looks like a version string
# (e.g. claude "2.1.144"); otherwise fall back to pane_current_command.
fmt="#{pane_id}${TAB}#{pane_left}${TAB}#{pane_right}${TAB}#{pane_top}${TAB}#{pane_bottom}${TAB}#{?#{||:#{m:*.*.*,#{pane_current_command}},#{!=:#{pane_title},#h}},#{pane_title},#{pane_current_command}}"

left_label=""
right_label=""
left_best=-1
right_best=99999999

while IFS="$TAB" read -r id l r t b label; do
  [ "$id" = "$active_id" ] && continue
  # Require vertical overlap with the active pane — otherwise it's a top/
  # bottom neighbor, which the pane border already labels.
  if [ "$t" -gt "$a_b" ] || [ "$b" -lt "$a_t" ]; then
    continue
  fi
  # Closest pane to the strict left wins (largest right edge < a_l)
  if [ "$r" -lt "$a_l" ] && [ "$r" -gt "$left_best" ]; then
    left_best="$r"
    left_label="$label"
  fi
  # Closest pane to the strict right wins (smallest left edge > a_r)
  if [ "$l" -gt "$a_r" ] && [ "$l" -lt "$right_best" ]; then
    right_best="$l"
    right_label="$label"
  fi
done < <(tmux list-panes -F "$fmt")

out=""
[ -n "$left_label" ] && out="  ← $left_label"
[ -n "$right_label" ] && out="$out  → $right_label"
# Wrap in catppuccin mauve so the hints jump out in peripheral vision.
# Mauve is the classic complement to the surrounding green MAXIMIZED block
# and stays clearly distinct from the prefix-flash pink (#f38ba8). Restore
# the green bg at the end so the trailing space in status-right stays green.
if [ -n "$out" ]; then
  printf '#[bg=#cba6f7,fg=#1e1e2e,bold]%s #[bg=#a6e3a1,fg=#1e1e2e,nobold]' "$out"
fi
