#!/usr/bin/env bash
# Claude Code statusline — mirrors the garrett prezto prompt style
# Colors: pwd=blue, git=green/cyan, host=green, time=green, separators=grey

input=$(cat)

# --- Working directory (blue, with ~ substitution) ---
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
home="$HOME"
display_pwd="${cwd/#$home/\~}"

# --- Git branch + dirty indicator (no optional locks) ---
git_info=""
if git_branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_dirty=""
  if ! git --no-optional-locks -C "$cwd" diff --quiet 2>/dev/null || \
     ! git --no-optional-locks -C "$cwd" diff --cached --quiet 2>/dev/null; then
    git_dirty=" ✱"
  fi
  git_info=" $(printf '\033[36m')λ$(printf '\033[0m'):$(printf '\033[32m')${git_branch}${git_dirty}$(printf '\033[0m')"
fi

# --- Hostname (green) ---
host=$(hostname -s)

# --- Time (green, 12-hour like garrett) ---
current_time=$(date '+%-l:%M %p')

# --- Claude Code: model display name ---
model=$(echo "$input" | jq -r '.model.display_name // ""')

# --- Claude Code: context used % (matches /context) ---
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // 100')
used=$(awk -v r="$remaining" 'BEGIN { printf "%.0f", 100 - r }')
ctx_info=" $(printf '\033[33m')ctx:${used}%$(printf '\033[0m')"

# --- Vim mode (optional) ---
vim_mode=""
if vim_raw=$(echo "$input" | jq -r '.vim.mode // empty'); [ -n "$vim_raw" ]; then
  vim_mode=" $(printf '\033[35m')[${vim_raw}]$(printf '\033[0m')"
fi

# --- Assemble output ---
printf '\033[34m%s\033[0m%s\033[90m @\033[32m%s\033[0m \033[90m+\033[0m\033[32m%s\033[0m' \
  "$display_pwd" \
  "$git_info" \
  "$host" \
  "$current_time"

if [ -n "$model" ]; then
  printf ' \033[90m|\033[0m \033[36m%s\033[0m' "$model"
fi

printf '%s%s\n' "$ctx_info" "$vim_mode"
