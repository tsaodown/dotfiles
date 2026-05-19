#!/usr/bin/env bash
# Fixtures for tests/dotfiles-watcher.bats. Loaded via `load watcher-helpers`.

REAL_DOTFILES="${BATS_TEST_DIRNAME}/.."

# Watcher needs fswatch (mac/linux) or inotifywait (linux) — skip otherwise.
watcher_required_tool_present() {
  command -v fswatch >/dev/null 2>&1 || command -v inotifywait >/dev/null 2>&1
}

setup_watcher_fixture() {
  # Resolve to the canonical (/private-prefixed) path. macOS fswatch reports
  # event paths with the /private prefix while mktemp -d returns the
  # /var-prefixed alias; without the resolve, the watcher's bash-level
  # `.git/` filter ([[ "$path" == "$DOTFILES/.git"* ]]) misses internal git
  # events, which leak through during sync and cause spurious debounce
  # cycles. With the resolved path, $DOTFILES matches what fswatch emits.
  TEST_HOME=$(cd "$(mktemp -d)" && pwd -P)
  TEST_DOTFILES="$TEST_HOME/dotfiles"
  TEST_ORIGIN="$TEST_HOME/origin.git"

  mkdir -p "$TEST_DOTFILES"
  cd "$TEST_DOTFILES"
  git init -q
  git checkout -q -B main 2>/dev/null
  git config user.email "test@test.invalid"
  git config user.name "Test"
  git config commit.gpgsign false
  git config core.pager cat
  : > seed
  git add seed
  git commit -q -m seed

  git init -q --bare "$TEST_ORIGIN"
  git remote add origin "$TEST_ORIGIN"
  git push -q -u origin main

  # Symlink the real watcher binaries into the fixture's $DOTFILES/bin so
  # $DOTFILES/bin/... resolves to the scripts under test.
  mkdir -p "$TEST_DOTFILES/bin"
  ln -s "$REAL_DOTFILES/bin/dotfiles-watcher"       "$TEST_DOTFILES/bin/dotfiles-watcher"
  ln -s "$REAL_DOTFILES/bin/dotfiles-watcher-paths" "$TEST_DOTFILES/bin/dotfiles-watcher-paths"
  ln -s "$REAL_DOTFILES/bin/dotfiles-watcher-logs"  "$TEST_DOTFILES/bin/dotfiles-watcher-logs"

  export HOME="$TEST_HOME"
  export DOTFILES="$TEST_DOTFILES"
  # Shrink timing so tests run in seconds, not minutes.
  export TICK_INTERVAL_SECS=1
  export DEBOUNCE_SECS=2
  export WAKE_GAP_SECS=2
  export PULL_INTERVAL_SECS=86400  # 24h slot → can't cross a slot mid-test
  # Bypass the nc probe in is_online so tests don't depend on real network.
  # Tests that need to simulate offline use force_offline / force_online below
  # (which write/remove a state-dir flag the watcher re-reads every tick).
  export WATCHER_FORCE_ONLINE=1
  # Shrink backoff so a deferred-op retry fires within seconds, not minutes.
  export PENDING_BACKOFF_1=1
  export PENDING_BACKOFF_2=1
  export PENDING_BACKOFF_3=1
  export PENDING_BACKOFF_MAX=1

  WATCHER_LOG="$("$TEST_DOTFILES/bin/dotfiles-watcher-paths" log)"
  WATCHER_STATE_DIR="$("$TEST_DOTFILES/bin/dotfiles-watcher-paths" state-dir)"
}

# Toggle the watcher into "offline" mode mid-test. The flag is read by
# is_online every tick, so the next tick will see it and start deferring.
force_offline() {
  mkdir -p "$WATCHER_STATE_DIR"
  : > "$WATCHER_STATE_DIR/force-offline"
}

force_online() {
  rm -f "$WATCHER_STATE_DIR/force-offline"
}

# Wait up to <timeout> seconds for <path> to exist. Used by tests where state
# files are the canonical signal (more reliable than scraping log lines, which
# can race under load — log_grep dumps an empty log on miss even when prior
# log_grep calls confirmed content).
# On failure, dumps the watcher log + state dir + working-tree status so we
# don't lose the test's evidence trail.
wait_for_file() {
  local path="$1"
  local timeout="${2:-15}"
  local i
  for i in $(seq 1 $((timeout * 2))); do
    [[ -e "$path" ]] && return 0
    sleep 0.5
  done
  echo "file did not appear within ${timeout}s: $path" >&2
  echo "--- watcher log ---" >&2
  cat "$WATCHER_LOG" >&2 2>/dev/null || true
  echo "--- state dir ---" >&2
  ls -la "$WATCHER_STATE_DIR" >&2 2>/dev/null || true
  echo "--- git status (in $TEST_DOTFILES) ---" >&2
  ( cd "$TEST_DOTFILES" 2>/dev/null && git status --porcelain 2>/dev/null ) >&2 || true
  return 1
}

# Wait up to <timeout> seconds for <path> to contain <expected_content>.
# More robust than wait_for_file followed by an exact-match check because the
# pending file can transiently hold different op labels across tick boundaries.
# Matches as a substring so callers can pass an op label and ignore the
# trailing fields ("<op> <next-retry> <attempts>") of the pending file.
wait_for_content() {
  local path="$1" expected="$2" timeout="${3:-15}"
  local i actual=""
  for i in $(seq 1 $((timeout * 2))); do
    actual=$(cat "$path" 2>/dev/null || echo "")
    [[ "$actual" == *"$expected"* ]] && return 0
    sleep 0.5
  done
  echo "file did not contain expected content within ${timeout}s" >&2
  echo "path:     $path" >&2
  echo "expected: $expected" >&2
  echo "actual:   $actual" >&2
  echo "--- watcher log ---" >&2
  cat "$WATCHER_LOG" >&2 2>/dev/null || true
  return 1
}

# Wait up to <timeout> seconds for <path> to be removed.
wait_for_no_file() {
  local path="$1"
  local timeout="${2:-15}"
  local i
  for i in $(seq 1 $((timeout * 2))); do
    [[ ! -e "$path" ]] && return 0
    sleep 0.5
  done
  echo "file did not disappear within ${timeout}s: $path" >&2
  return 1
}

start_watcher() {
  "$TEST_DOTFILES/bin/dotfiles-watcher" >/dev/null 2>&1 &
  WATCHER_PID=$!
  # The watcher logs "watcher started" only after the startup pull_ff returns
  # (fetch + merge + 2s drain), so first-line latency is ~3s.
  local i
  for i in $(seq 1 60); do
    [[ -f "$WATCHER_LOG" ]] && grep -q "watcher started" "$WATCHER_LOG" && return 0
    sleep 0.1
  done
  echo "watcher did not log 'watcher started' within 6s" >&2
  cat "$WATCHER_LOG" 2>/dev/null >&2 || true
  return 1
}

stop_watcher() {
  if [[ -n "${WATCHER_PID:-}" ]]; then
    kill -TERM "$WATCHER_PID" 2>/dev/null || true
    # Bounded wait, then SIGKILL if still alive (defensive against trap hangs).
    local i
    for i in $(seq 1 20); do
      kill -0 "$WATCHER_PID" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$WATCHER_PID" 2>/dev/null || true
    wait "$WATCHER_PID" 2>/dev/null || true
    unset WATCHER_PID
  fi
  # Belt-and-suspenders: kill any leaked fswatch/inotifywait still watching this
  # test's dotfiles fixture. The watcher's own EXIT trap may not have run if the
  # SIGKILL above arrived before the trap fired (e.g. bash was stuck in a
  # foreground `git fetch` inside startup pull_ff and ran past the 2s grace).
  # Without this, the orphaned fswatch is reparented to launchd and accumulates
  # across test runs. Guard on TEST_DOTFILES being set so a half-initialized
  # fixture can't trigger a bare `pkill -f fswatch` that hits unrelated processes.
  if [[ -n "${TEST_DOTFILES:-}" ]]; then
    pkill -f "fswatch.*${TEST_DOTFILES}" 2>/dev/null || true
    pkill -f "inotifywait.*${TEST_DOTFILES}" 2>/dev/null || true
  fi
}

# fswatch's FSEvents subscription has ~1-2s startup latency on macOS — events
# fired before that window are missed.
sleep_for_fswatch() {
  sleep 2
}

# Wait up to <timeout> seconds for <pattern> to appear in the watcher log.
log_grep() {
  local pattern="$1"
  local timeout="${2:-10}"
  local i
  for i in $(seq 1 $((timeout * 10))); do
    grep -q -- "$pattern" "$WATCHER_LOG" 2>/dev/null && return 0
    sleep 0.1
  done
  echo "log did not contain pattern within ${timeout}s: $pattern" >&2
  echo "--- watcher log ---" >&2
  # Redirect order matters: `>&2` first dup's fd 1 to ORIGINAL stderr; then
  # `2>/dev/null` suppresses cat's own errors. The reverse order would point
  # fd 1 at /dev/null (because >&2 takes the *current* fd 2), eating the dump.
  cat "$WATCHER_LOG" >&2 2>/dev/null || true
  return 1
}

teardown_watcher_fixture() {
  stop_watcher
  cd /
  if [[ -n "${TEST_HOME-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
  unset TEST_HOME TEST_DOTFILES TEST_ORIGIN WATCHER_LOG WATCHER_STATE_DIR \
        LOG_MAX_SIZE_BYTES WATCHER_FORCE_ONLINE WATCHER_FORCE_OFFLINE \
        PENDING_BACKOFF_1 PENDING_BACKOFF_2 PENDING_BACKOFF_3 PENDING_BACKOFF_MAX
}
