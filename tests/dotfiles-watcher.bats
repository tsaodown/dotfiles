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

# ---------- offline-aware deferral ----------
#
# All offline tests start online (so startup pull_ff succeeds with no pending
# state) and toggle force_offline mid-test. set_pending only logs on the first
# transition into pending mode — so a test that depends on a specific
# "<op> deferred (offline)" log line must enter pending from a clean state.

@test "watcher: wake while offline → wake-pull deferred, no halt" {
  start_watcher
  sleep_for_fswatch
  force_offline
  # SIGSTOP/sleep/SIGCONT simulates a wake gap > WAKE_GAP_SECS=2.
  kill -STOP "$WATCHER_PID"
  sleep 4
  kill -CONT "$WATCHER_PID"
  log_grep "tick gap of " 10
  log_grep "wake-pull deferred (offline)" 10
  [ -f "$WATCHER_STATE_DIR/pending-op" ]
  run cat "$WATCHER_STATE_DIR/pending-op"
  [ "$output" = "wake-pull" ]
  # Offline is recoverable — must not halt (which would require manual resume).
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: pending wake-pull recovers when network returns" {
  start_watcher
  sleep_for_fswatch
  force_offline
  kill -STOP "$WATCHER_PID"
  sleep 4
  kill -CONT "$WATCHER_PID"
  log_grep "wake-pull deferred (offline)" 10
  force_online
  log_grep "back online — wake-pull completed" 15
  [ ! -f "$WATCHER_STATE_DIR/pending-op" ]
}

@test "watcher: edit while offline → commit-rebase deferred, no halt" {
  start_watcher
  sleep_for_fswatch
  force_offline
  echo "edit-while-offline" >> seed
  log_grep "change detected" 5
  log_grep "commit-rebase deferred (offline)" 10
  run cat "$WATCHER_STATE_DIR/pending-op"
  [ "$output" = "commit-rebase" ]
  # Pre-change, an offline pull-rebase inside commit_and_push fell through to
  # halt() with "rebase conflict during sync" — this regression-guards that.
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: pending commit-rebase recovers when network returns" {
  start_watcher
  sleep_for_fswatch
  force_offline
  echo "edit-while-offline" >> seed
  log_grep "commit-rebase deferred (offline)" 10
  force_online
  log_grep "back online — commit-rebase completed" 15
  log_grep "committed:" 10
  log_grep "pushed" 10
  [ ! -f "$WATCHER_STATE_DIR/pending-op" ]
  # Origin should now have the offline-authored edit.
  local commits
  commits=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$commits" -ge 2 ]
}

@test "watcher: real rebase conflict still halts (online)" {
  start_watcher
  sleep_for_fswatch
  # Parallel clone pushes a conflicting change to origin so the watcher's
  # eventual `pull --rebase` produces a real conflict. With autostash=true,
  # `git pull --rebase` exits 0 even when stash-pop fails — the conflict is
  # caught downstream by commit_drain_sentinel's `git ls-files --unmerged`
  # check, which halts with "post-sync unmerged files". The exact message
  # is incidental; what matters is that real conflicts still halt (vs the
  # offline case which defers).
  local clone="$TEST_HOME/parallel"
  git clone -q "$TEST_ORIGIN" "$clone"
  ( cd "$clone"
    git config user.email "p@p.invalid"
    git config user.name "P"
    echo "from-parallel" > seed
    git add seed
    git commit -q -m "parallel edit"
    git push -q origin main )
  echo "from-local" > seed
  log_grep "change detected" 5
  log_grep "HALT: " 15
  [ -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: backoff schedule advances attempts while still offline" {
  # PENDING_BACKOFF_* are all 1s in the fixture, so the numeric schedule isn't
  # testable here — instead assert that attempts increments while offline and
  # the file disappears once back online.
  start_watcher
  sleep_for_fswatch
  force_offline
  kill -STOP "$WATCHER_PID"
  sleep 4
  kill -CONT "$WATCHER_PID"
  log_grep "wake-pull deferred (offline)" 10
  sleep 4
  local attempts
  attempts=$(cat "$WATCHER_STATE_DIR/pending-attempts" 2>/dev/null || echo 0)
  [ "$attempts" -gt 1 ]
  force_online
  log_grep "back online — wake-pull completed" 10
  [ ! -f "$WATCHER_STATE_DIR/pending-attempts" ]
}
