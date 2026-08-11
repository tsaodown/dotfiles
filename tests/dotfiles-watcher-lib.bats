#!/usr/bin/env bats
# Unit tests for bin/dotfiles-watcher-lib — the pure, sourceable helpers.
# These need neither fswatch nor the watcher daemon, so they run everywhere.

load watcher-lib-helpers

setup() {
  load_watcher_lib
}

# ---------- repo_in_conflict ----------

@test "repo_in_conflict: a clean repo is not in conflict" {
  new_test_repo
  run repo_in_conflict
  cleanup_test_repo
  [ "$status" -ne 0 ]
}

@test "repo_in_conflict: unmerged index entries count as conflict" {
  new_test_repo
  make_unmerged
  run repo_in_conflict
  cleanup_test_repo
  [ "$status" -eq 0 ]
}

@test "repo_in_conflict: an in-progress rebase counts as conflict" {
  new_test_repo
  make_rebasing
  run repo_in_conflict
  cleanup_test_repo
  [ "$status" -eq 0 ]
}

# ---------- drain_decision <conflicted> <dirty> <prior_resync_count> ----------

@test "drain_decision: conflict wins regardless of dirty/count" {
  run drain_decision 1 1 0
  [ "$status" -eq 0 ]
  [ "$output" = "CONFLICT" ]
}

@test "drain_decision: a clean tree yields CLEAN" {
  run drain_decision 0 0 0
  [ "$output" = "CLEAN" ]
}

@test "drain_decision: first dirty drain yields RETRY" {
  run drain_decision 0 1 0
  [ "$output" = "RETRY" ]
}

@test "drain_decision: second dirty drain still yields RETRY" {
  run drain_decision 0 1 1
  [ "$output" = "RETRY" ]
}

@test "drain_decision: third consecutive dirty drain yields ROLLING_HALT" {
  run drain_decision 0 1 2
  [ "$output" = "ROLLING_HALT" ]
}

# ---------- gitlink_backoff_secs / gitlink_at_cap ----------

@test "gitlink_backoff_secs: each attempt maps to its own tier" {
  run gitlink_backoff_secs 1 60 300 900 3600
  [ "$output" = "60" ]
  run gitlink_backoff_secs 2 60 300 900 3600
  [ "$output" = "300" ]
  run gitlink_backoff_secs 3 60 300 900 3600
  [ "$output" = "900" ]
}

@test "gitlink_backoff_secs: attempts past the schedule stay at the ceiling" {
  run gitlink_backoff_secs 4 60 300 900 3600
  [ "$output" = "3600" ]
  run gitlink_backoff_secs 99 60 300 900 3600
  [ "$output" = "3600" ]
}

# The cap predicate and the tier table have to agree on where the ceiling
# starts, or the escalation notification fires a tier early or late.
@test "gitlink_at_cap: true exactly where gitlink_backoff_secs saturates" {
  ! gitlink_at_cap 1
  ! gitlink_at_cap 3
  gitlink_at_cap 4
  gitlink_at_cap 99
}

# ---------- log_format <[level]> <message...> ----------

@test "log_format: defaults to info when no level is given" {
  run log_format "hello world"
  [ "$output" = "[info] hello world" ]
}

@test "log_format: a recognized leading level token is consumed" {
  run log_format warn "careful now"
  [ "$output" = "[warn] careful now" ]
}

@test "log_format: each recognized level is honored" {
  run log_format error boom;          [ "$output" = "[error] boom" ]
  run log_format ok done;             [ "$output" = "[ok] done" ]
  run log_format trace tick;          [ "$output" = "[trace] tick" ]
  run log_format stopping bye;        [ "$output" = "[stopping] bye" ]
}

@test "log_format: a message that merely starts with a level word is not split" {
  run log_format "error happened downstream"
  [ "$output" = "[info] error happened downstream" ]
}
