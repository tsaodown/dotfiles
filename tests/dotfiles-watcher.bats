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
  # `wc -c` rather than stat: the BSD/GNU size flags differ, and chaining
  # `stat -f %z || stat -c %s` silently yields garbage on GNU, where `-f` means
  # "filesystem status" and succeeds instead of failing over (the same trap
  # rotate_log_if_needed calls out).
  local pre_size
  pre_size=$(wc -c < "$WATCHER_LOG")
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

@test "watcher: online pull failure with no conflict defers, does not halt" {
  # Regression: a network drop *during* `git pull --rebase` makes the command
  # fail, but the pull can hang for minutes while SSH dies — and if connectivity
  # has recovered by the time commit_and_push re-probes is_online, the failure
  # was misclassified as a rebase conflict and the watcher halted spuriously.
  # The fix keys halt on actual conflict evidence (unmerged index / rebase-dir),
  # so a non-conflict failure while "online" must defer, not halt. Simulated
  # here by pointing origin at a missing repo while WATCHER_FORCE_ONLINE stays
  # set: pull fails fast with no conflict, yet is_online reports online.
  start_watcher
  sleep_for_fswatch
  git remote set-url origin "$TEST_HOME/nonexistent.git"
  echo "edit-online-no-remote" >> seed
  # commit_and_push: pull --rebase fails, no unmerged files → defer, not halt.
  wait_for_content "$WATCHER_STATE_DIR/pending" "commit-rebase" 20
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: real conflict on rebase of a local commit still halts" {
  # The other half of the fix: a `pull --rebase` failure *with* conflict
  # evidence must still halt with "rebase conflict during sync" — the fix must
  # not over-correct and defer real conflicts (which would loop forever). Set up
  # a diverged history (local unpushed commit + conflicting origin commit)
  # before starting the watcher, so the first commit_and_push replays the local
  # commit onto origin and the rebase itself conflicts (non-zero exit), entering
  # the failure branch under test rather than the autostash-pop path of the test
  # above.
  local clone="$TEST_HOME/parallel"
  git clone -q "$TEST_ORIGIN" "$clone"
  ( cd "$clone"
    git config user.email "p@p.invalid"; git config user.name "P"
    echo "from-parallel" > seed
    git add seed; git commit -q -m "parallel edit"; git push -q origin main )
  # Local unpushed commit touching the same line → rebase replay conflicts.
  echo "from-local" > seed
  git add seed
  git commit -q -m "local conflicting commit"

  start_watcher
  sleep_for_fswatch
  # A fresh edit fires the debounce → commit_and_push → pull --rebase replays
  # the local commit → conflict → non-zero exit + unmerged → halt.
  echo trigger > trigger-file
  wait_for_file "$WATCHER_STATE_DIR/halt" 30
  grep -q "rebase conflict during sync" "$WATCHER_STATE_DIR/halt"
}

@test "watcher: a hung network op is killed by the timeout backstop and defers, not halts" {
  command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1 \
    || skip "no timeout(1)/gtimeout available"
  # Drive a real hang: point origin at an ssh remote whose ssh command just
  # sleeps, far longer than the 1s backstop. `git pull --rebase` then blocks in
  # the fetch phase until NETWORK_OP_TIMEOUT fires and kills it (exit 124).
  # commit_and_push must treat that as a stalled op → defer (pending
  # commit-rebase), never halt — even though the backstop, not a conflict,
  # ended the pull.
  cat > "$TEST_HOME/slow-ssh" <<'EOF'
#!/bin/sh
sleep 30
EOF
  chmod +x "$TEST_HOME/slow-ssh"
  export GIT_SSH_COMMAND="$TEST_HOME/slow-ssh"
  export NETWORK_OP_TIMEOUT=1
  git remote set-url origin "git@example.invalid:repo.git"

  start_watcher
  sleep_for_fswatch
  echo "edit-that-cannot-push" >> seed
  # Backstop kills the pull → "timed out" defer. Pad generously: debounce (2s) +
  # the 1s backstop + retry churn.
  wait_for_content "$WATCHER_STATE_DIR/pending" "commit-rebase" 25
  [ ! -f "$WATCHER_STATE_DIR/halt" ]
  log_grep "timed out" 5
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

# ---------- manual immediate sync (SIGUSR2 / make watcher-sync) ----------
#
# `make watcher-sync` signals the running daemon with SIGUSR2 instead of
# backdating the debounce trigger, so the commit happens now rather than on the
# next tick. These tests set DEBOUNCE_SECS high so a normal debounce can't
# explain a commit landing in seconds — the only fast path is the forced sync.

@test "watcher: SIGUSR2 forces an immediate sync, bypassing the debounce window" {
  export DEBOUNCE_SECS=600
  start_watcher
  sleep_for_fswatch
  echo "edit-usr2" >> seed
  kill -USR2 "$WATCHER_PID"
  log_grep "manual sync requested — syncing now" 10
  log_grep "committed:" 10
  log_grep "pushed" 10
  local commits
  commits=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$commits" -ge 2 ]
}

@test "watcher: SIGUSR2 syncs even while manually paused, and leaves the pause in place" {
  export DEBOUNCE_SECS=600
  start_watcher
  sleep_for_fswatch
  # Mirror `make watcher-pause`: a manual halt sentinel.
  mkdir -p "$WATCHER_STATE_DIR"
  echo "manual pause" > "$WATCHER_STATE_DIR/halt"
  echo "edit-while-paused" >> seed
  kill -USR2 "$WATCHER_PID"
  log_grep "committed:" 10
  log_grep "pushed" 10
  # One-shot: the forced sync must not auto-resume the watcher.
  [ -f "$WATCHER_STATE_DIR/halt" ]
}

@test "watcher: SIGUSR2 is refused when the working tree has conflict markers" {
  export DEBOUNCE_SECS=600
  # Manufacture an unmerged index (real conflict markers on disk) before the
  # watcher runs any sync — repo_in_conflict must gate the forced sync off.
  git checkout -q -b other
  echo "other-side" > seed; git add seed; git commit -q -m other
  git checkout -q main
  echo "main-side" > seed; git add seed; git commit -q -m main
  git merge other >/dev/null 2>&1 || true
  git ls-files --unmerged | grep -q seed   # sanity: index is unmerged

  start_watcher
  sleep_for_fswatch
  kill -USR2 "$WATCHER_PID"
  log_grep "refused: working tree has conflict markers" 10
  # Nothing pushed: origin still holds only the seed commit.
  local commits
  commits=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$commits" -eq 1 ]
}

@test "watcher: SIGUSR2 with a clean tree is a no-op (no commit, no error)" {
  export DEBOUNCE_SECS=600
  start_watcher
  sleep_for_fswatch
  # The fixture leaves the symlinked bin/ untracked, so commit a baseline first
  # to get a genuinely clean tree — otherwise git add -A has content to stage.
  # (Touches only .git/, which fswatch excludes, so the daemon stays idle.)
  git add -A && git commit -q -m baseline && git push -q origin main
  local before
  before=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  kill -USR2 "$WATCHER_PID"
  log_grep "manual sync requested — syncing now" 10
  sleep 2
  # Nothing to stage → no new commit lands on origin.
  local after
  after=$(git --git-dir="$TEST_ORIGIN" rev-list --count main)
  [ "$after" -eq "$before" ]
}

# ---------- submodules ----------
#
# Submodules are separate repos with their own sync cadence. Edits inside a
# submodule worktree must not trigger the parent watcher's debounce, otherwise
# the parent would silently pointer-bump the submodule gitlink on the next
# commit_and_push.

@test "watcher: edits inside a submodule worktree do not trigger debounce" {
  add_test_submodule

  start_watcher
  sleep_for_fswatch

  # Edit inside the submodule worktree. The read loop drops events silently,
  # so we can't assert on a positive "ignored" log line — instead assert the
  # downstream effects don't fire (no debounce, no commit). Sleep long enough
  # to cover several tick cycles + a full debounce window so the tick-poll
  # path (which previously looped on uncommitted in-submodule edits) gets
  # multiple chances to misfire.
  echo "edit-in-sub" >> "$TEST_DOTFILES/sub/a"
  sleep 6   # ≥ 2× DEBOUNCE_SECS=2 + several TICK_INTERVAL_SECS=1

  [ ! -e "$WATCHER_STATE_DIR/last-change" ]
  ! grep -q "change detected: sub/" "$WATCHER_LOG"
  ! grep -q "tick-detected dirty tree" "$WATCHER_LOG"
  ! grep -q "debounce window expired" "$WATCHER_LOG"
  ! grep -q "committed:" "$WATCHER_LOG"

  # Sanity check: a parent-repo edit still fires normally afterwards.
  echo "edit-outside" >> "$TEST_DOTFILES/seed"
  log_grep "change detected: seed" 5
  log_grep "committed:" 15
}

# A gitlink only means anything to anyone else once the commit it names reached
# the submodule's own remote. Publishing one that didn't leaves the parent fine
# on this machine and breaks every fresh `clone --recursive` and CI checkout
# with "upload-pack: not our ref", so the watcher holds that path back.

# Commit inside the fixture's submodule without pushing it, and echo the sha.
hold_a_sub_commit() {
  ( cd "$TEST_DOTFILES/sub"
    echo new >> a
    git commit -q -am "unpushed sub commit" )
  git -C "$TEST_DOTFILES/sub" rev-parse HEAD
}

@test "watcher: an unpushed submodule commit holds its gitlink while everything else syncs" {
  add_test_submodule
  local before sha
  before=$(git -C "$TEST_ORIGIN" rev-parse main:sub)

  start_watcher
  sleep_for_fswatch
  sha=$(hold_a_sub_commit)

  # An unrelated parent edit drives a normal sync alongside the held bump.
  echo "edit-outside" >> "$TEST_DOTFILES/seed"
  log_grep "holding sub gitlink" 20
  log_grep "\[ok\] pushed$" 20

  # The parent's own change published; the gitlink stayed put; and the
  # submodule's remote was never touched on the user's behalf.
  [ "$(git -C "$TEST_ORIGIN" show main:seed)" = "$(cat "$TEST_DOTFILES/seed")" ]
  [ "$(git -C "$TEST_ORIGIN" rev-parse main:sub)" = "$before" ]
  ! git -C "$SUB_ORIGIN" cat-file -e "${sha}^{commit}" 2>/dev/null
}

# The held bump keeps the tree permanently dirty, which is exactly what
# drain_decision escalates to ROLLING_HALT after three cycles. Held paths are
# filtered out of every dirty probe so intentional deferral can't halt syncing.
@test "watcher: a held gitlink never trips the rolling-sync halt" {
  add_test_submodule
  start_watcher
  sleep_for_fswatch
  hold_a_sub_commit >/dev/null
  log_grep "holding sub gitlink" 20
  # Let the sync that established the hold finish draining before baselining,
  # or edit-1 lands mid-sync and shows up as legitimate dirt.
  log_grep_count "sync drain complete" 1 25

  # Four full sync+drain cycles — one more than the 3-strike limit. Each edit
  # waits for its own drain, so a later edit can't land mid-sync and read as
  # legitimate dirt, which would muddy the assertion below.
  local i drains
  drains=$(grep -c "sync drain complete" "$WATCHER_LOG" 2>/dev/null || true)
  drains=${drains:-0}
  for i in 1 2 3 4; do
    echo "edit-$i" >> "$TEST_DOTFILES/seed"
    log_grep_count "sync drain complete" "$((drains + i))" 25
  done

  # The bump is still held and still visible to plain git...
  ( cd "$TEST_DOTFILES" && git status --porcelain | grep -q '^ M sub' )
  # ...yet every drain read the tree as clean, so nothing escalated.
  [ ! -e "$WATCHER_STATE_DIR/halt" ]
  [ ! -e "$WATCHER_STATE_DIR/consecutive-resyncs" ]
  ! grep -q "rolling sync" "$WATCHER_LOG"
  ! grep -q "still dirty" "$WATCHER_LOG"
}

@test "watcher: a held gitlink publishes once the submodule commit reaches its remote" {
  add_test_submodule
  local sha i
  start_watcher
  sleep_for_fswatch
  sha=$(hold_a_sub_commit)

  echo "edit-outside" >> "$TEST_DOTFILES/seed"
  log_grep "holding sub gitlink" 20

  # Push the submodule out-of-band, the way the user would.
  git -C "$TEST_DOTFILES/sub" push -q origin main
  log_grep "sub gitlink released" 20

  # Poll the parent remote rather than the log — "[ok] pushed" already appeared
  # for the earlier sync, so it can't distinguish this publish from that one.
  for i in $(seq 1 40); do
    [ "$(git -C "$TEST_ORIGIN" rev-parse main:sub 2>/dev/null)" = "$sha" ] && break
    sleep 0.5
  done
  [ "$(git -C "$TEST_ORIGIN" rev-parse main:sub)" = "$sha" ]
}
