#!/usr/bin/env bats
# Unit tests for bin/dotfiles-watcher-logs.awk — the log colorizer program.
# Run the real awk directly (no tail -F, no tty gate) so coloring is actually
# exercised. ESC is \033; each test asserts the right SGR color code appears.

AWK_PROG="${BATS_TEST_DIRNAME}/../bin/dotfiles-watcher-logs.awk"

ESC=$'\033'
RED="${ESC}[31m"; GRN="${ESC}[32m"; YEL="${ESC}[33m"
CYN="${ESC}[36m"; MAG="${ESC}[35m"; GRY="${ESC}[90m"

colorize() { awk -f "$AWK_PROG"; }

# ---------- tagged lines (new format) colorize by their [level] tag ----------

@test "logs: a tagged error line is red" {
  run bash -c "printf '%s\n' '2026-05-29 03:00:00 [error] boom' | awk -f '$AWK_PROG'"
  [[ "$output" == *"$RED"* ]]
}

@test "logs: a tagged ok line is green" {
  run bash -c "printf '%s\n' '2026-05-29 03:00:00 [ok] pushed' | awk -f '$AWK_PROG'"
  [[ "$output" == *"$GRN"* ]]
}

@test "logs: a tagged trace line is grey" {
  run bash -c "printf '%s\n' '2026-05-29 03:00:00 [trace] time to sync: 5s' | awk -f '$AWK_PROG'"
  [[ "$output" == *"$GRY"* ]]
}

# ---------- untagged timestamped lines are dimmed, never colored ----------
# Coloring is tag-driven only: a line without a [level] tag (pre-tag history, or
# output from an old watcher process not yet restarted) gets no color.

@test "logs: an untagged timestamped line gets no color code" {
  run bash -c "printf '%s\n' '2026-05-29 03:00:00 committed: a laptop - 1 file(s) changed' | awk -f '$AWK_PROG'"
  [[ "$output" != *"$RED"* && "$output" != *"$GRN"* && "$output" != *"$YEL"* && "$output" != *"$CYN"* ]]
}

# ---------- raw (no timestamp) lines are dimmed, never colored ----------

@test "logs: a raw line with no timestamp gets no color code" {
  run bash -c "printf '%s\n' 'fatal: not a git repository' | awk -f '$AWK_PROG'"
  [[ "$output" != *"$RED"* && "$output" != *"$GRN"* ]]
}
