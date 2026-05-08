#!/usr/bin/env bats
# Integration tests for bin/dotfiles-watcher. Skipped when neither fswatch nor
# inotifywait is installed (the watcher requires one).

load watcher-helpers

setup() {
  watcher_required_tool_present || skip "neither fswatch nor inotifywait installed"
  setup_watcher_fixture
}

teardown() {
  teardown_watcher_fixture
}

# ---------- dotfiles-watcher-paths ----------

@test "paths: state-dir prints a non-empty path" {
  run "$REAL_DOTFILES/bin/dotfiles-watcher-paths" state-dir
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "paths: log prints a non-empty path" {
  run "$REAL_DOTFILES/bin/dotfiles-watcher-paths" log
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "paths: macos paths land under Library, linux under .local/share" {
  run "$REAL_DOTFILES/bin/dotfiles-watcher-paths" log
  [ "$status" -eq 0 ]
  if [[ "$(uname -s)" == "Darwin" ]]; then
    [[ "$output" == *"Library/Logs/dotfiles-watcher.log" ]]
  else
    [[ "$output" == *"watcher.log" ]]
  fi
}

@test "paths: unknown key prints usage and exits 2" {
  run "$REAL_DOTFILES/bin/dotfiles-watcher-paths" bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

# ---------- watcher lifecycle ----------

@test "watcher: starts, stops cleanly on SIGTERM" {
  start_watcher
  log_grep "watcher started"
  stop_watcher
  log_grep "watcher stopping"
}

# ---------- debounce → commit → push ----------

@test "watcher: edit a tracked file → debounce expires → commit + push" {
  start_watcher
  sleep_for_fswatch
  echo "edit-1" >> seed
  log_grep "change detected" 5
  log_grep "committed:" 15
  log_grep "pushed" 15
  # Origin should now have a commit beyond the seed.
  local commits
  commits=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$commits" -ge 2 ]
}

# ---------- item E: wake-pull no-changes log ----------

@test "watcher: rotates log on startup when over LOG_MAX_SIZE_BYTES" {
  mkdir -p "$(dirname "$WATCHER_LOG")"
  # Pre-populate the log past the threshold (~200 bytes of filler).
  printf 'old log content\n%.0s' {1..20} > "$WATCHER_LOG"
  local pre_size
  pre_size=$(stat -f %z "$WATCHER_LOG" 2>/dev/null || stat -c %s "$WATCHER_LOG" 2>/dev/null)
  [ "$pre_size" -gt 100 ]

  export LOG_MAX_SIZE_BYTES=100
  start_watcher

  # Backup file exists with the old content; new log is fresh.
  [ -f "${WATCHER_LOG}.1" ]
  grep -q "old log content" "${WATCHER_LOG}.1"
  ! grep -q "old log content" "$WATCHER_LOG"
}

@test "watcher: wake-tick with no remote changes logs 'wake-pull: no changes to pull'" {
  start_watcher
  sleep_for_fswatch
  # The tick loop runs in the foreground main shell, so SIGSTOP on the watcher
  # PID directly suspends the wall-clock gap measurement.
  kill -STOP "$WATCHER_PID"
  sleep 4
  kill -CONT "$WATCHER_PID"
  log_grep "tick gap of " 5
  log_grep "wake-pull: no changes to pull" 5
}
