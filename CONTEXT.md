# dotfiles

Domain language for this personal dotfiles repo. The non-obvious vocabulary
lives in `dotfiles-watcher` — the auto-sync daemon — so that's what this
glossary covers. Seeded lazily during an architecture review; grow it as new
coined concepts appear.

## Language

**Drain**:
The grace window (`DRAIN_SECS`) after a sync completes, during which the
fswatch events the sync itself generated are allowed to settle before the
watcher reacts again. A drain ends in one of four dispositions — clean,
retry, rolling-sync halt, or conflict halt.
_Avoid_: cooldown, settle period, quiet window.

**Halt**:
The persistent stopped state the watcher enters when it hits something only a
human can resolve (a rebase conflict, post-sync unmerged files, or a rolling
sync). Backed by `HALT_FILE`; it survives restarts and is cleared with
`make watcher-resume`.
_Avoid_: stop, freeze.

**Rolling sync**:
The failure mode where three consecutive sync cycles each leave the working
tree dirty after their drain. The watcher halts instead of retrying forever.
_Avoid_: sync loop, thrashing.

**Pending-op**:
The single git operation (a pull, or a commit-rebase) the watcher parks when
offline and retries on a backoff schedule. At most one exists at a time, and a
parked commit-rebase outranks any pull because it carries unsynced edits.
_Avoid_: queue, job, task.

## Flagged ambiguities

**Halt vs. pause**: both write the same `HALT_FILE` sentinel, and
`make watcher-resume` clears either. The distinction is *who* triggered it: a
**halt** is watcher-triggered for safety (conflict / rolling sync), while a
**pause** is operator-triggered via `make watcher-pause`. So a pause is the
operator deliberately inducing a halt — not a separate state.

## Example dialogue

> **Dev:** The watcher seems stuck — it's not picking up my edits.
> **Expert:** Check whether it's halted. If a sync hit a rebase conflict it
> would have halted rather than push broken files, and it stays halted across
> restarts until you `make watcher-resume`.
> **Dev:** It's not halted, but it just keeps logging "still dirty."
> **Expert:** That's a drain not coming back clean. Each sync leaves a grace
> window for its own fswatch events to settle; if the tree is still dirty when
> the drain ends, it restarts the debounce. Three of those in a row and it'll
> escalate to a rolling-sync halt.
> **Dev:** And if I'm offline when it tries to push?
> **Expert:** It parks a pending-op and retries on backoff. Only one is parked
> at a time — and a parked commit-rebase won't be displaced by a pull, since
> the commit-rebase is holding your unsynced edits.
