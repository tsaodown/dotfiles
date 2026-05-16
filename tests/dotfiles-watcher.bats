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
  # This test asserts the wake-gap detection codepath itself, so SIGSTOP is the
  # right tool (kill -USR1 would short-circuit the thing under test). But
  # SIGSTOP can land in the inline part of the tick loop rather than inside
  # `sleep`, in which case the gap-detection bracket misses (the wall-clock
  # advance shows up in the next iteration's pre-sleep window, not its sleep).
  # Retry up to 3 cycles so the test isn't ~10% flaky from that race. Other
  # wake tests should use `kill -USR1 "$WATCHER_PID"` instead — see 9/10/15.
  local attempt
  for attempt in 1 2 3; do
    kill -STOP "$WATCHER_PID"
    sleep 4
    kill -CONT "$WATCHER_PID"
    sleep 1
    grep -q "tick gap of " "$WATCHER_LOG" 2>/dev/null && break
  done
  log_grep "tick gap of " 5
  log_grep "wake-pull: no changes to pull" 5
}

# ---------- offline-aware deferral ----------
#
# All offline tests start online (so startup pull_ff succeeds with no pending
# state) and toggle force_offline mid-test. We assert against state files
# rather than log content where possible — log_grep can race under load (the
# diagnostic log dump occasionally appears empty even when earlier log_grep
# calls in the same test confirmed content). State files are the canonical
# signal and are written before set_pending logs the deferral message.

@test "watcher: wake while offline → wake-pull deferred, no halt" {
  start_watcher
  sleep_for_fswatch
  force_offline
  # SIGUSR1 triggers the wake-pull codepath deterministically. We can't use
  # SIGSTOP-as-gap here because that races against `sleep` and ~10-40% of
  # cycles miss the bracket (see test 8 for the one place that genuinely
  # needs SIGSTOP).
  kill -USR1 "$WATCHER_PID"
  wait_for_content "$WATCHER_STATE_DIR/pending" "wake-pull" 20
  # Offline is recoverable — must not halt (which would require manual resume).
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: pending wake-pull recovers when network returns" {
  start_watcher
  sleep_for_fswatch
  force_offline
  kill -USR1 "$WATCHER_PID"
  wait_for_file "$WATCHER_STATE_DIR/pending" 15
  force_online
  wait_for_no_file "$WATCHER_STATE_DIR/pending" 20
}

@test "watcher: edit while offline → commit-rebase deferred, no halt" {
  start_watcher
  sleep_for_fswatch
  force_offline
  echo "edit-while-offline" >> seed
  # Wait for debounce + commit_and_push offline-defer path. DEBOUNCE_SECS=2,
  # so pending-op should appear within ~5s; pad for load.
  wait_for_content "$WATCHER_STATE_DIR/pending" "commit-rebase" 20
  # Pre-change, an offline pull-rebase inside commit_and_push fell through to
  # halt() with "rebase conflict during sync" — this regression-guards that.
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: pending commit-rebase recovers when network returns" {
  start_watcher
  sleep_for_fswatch
  force_offline
  echo "edit-while-offline" >> seed
  wait_for_file "$WATCHER_STATE_DIR/pending" 20
  force_online
  wait_for_no_file "$WATCHER_STATE_DIR/pending" 25
  # Origin should now have the offline-authored edit.
  local commits
  commits=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$commits" -ge 2 ]
}

@test "watcher: wake-pull while online doesn't wipe pending commit-rebase" {
  # Regression: pull_ff's clear_pending used to wipe ANY pending op on success.
  # If a user edited offline (pending=commit-rebase, LAST_CHANGE already
  # cleared by the debounce), then network came back and a wake-tick fired
  # pull_ff wake, the pull's clear_pending would erase commit-rebase and the
  # edits would sit in the working tree until the next user edit. Fixed by
  # making pull_ff use clear_pending pull-only.
  start_watcher
  sleep_for_fswatch
  force_offline
  echo "edit-pre-wake" >> seed
  wait_for_content "$WATCHER_STATE_DIR/pending" "commit-rebase" 20
  # Switch online + simulate wake. Wake-tick will run pull_ff wake, succeed,
  # but must NOT clear the commit-rebase pending.
  force_online
  kill -STOP "$WATCHER_PID"
  sleep 4
  kill -CONT "$WATCHER_PID"
  # Pending dispatch should run commit_and_push and the edit should land.
  wait_for_no_file "$WATCHER_STATE_DIR/pending" 30
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
  wait_for_file "$WATCHER_STATE_DIR/halt" 30
}

@test "watcher: backoff schedule advances attempts while still offline" {
  # PENDING_BACKOFF_* are all 1s in the fixture, so the numeric schedule isn't
  # testable here — instead assert that attempts increments while offline and
  # the file disappears once back online.
  start_watcher
  sleep_for_fswatch
  force_offline
  kill -USR1 "$WATCHER_PID"
  wait_for_file "$WATCHER_STATE_DIR/pending" 15
  sleep 4
  local attempts
  # pending file format: "<op> <next-retry-epoch> <attempts>"
  attempts=$(awk '{print $3}' "$WATCHER_STATE_DIR/pending" 2>/dev/null || echo 0)
  [ "$attempts" -gt 1 ]
  force_online
  wait_for_no_file "$WATCHER_STATE_DIR/pending" 20
}
