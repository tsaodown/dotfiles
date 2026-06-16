# dotfiles

Domain language for this personal dotfiles repo. Most of the non-obvious
vocabulary lives in `dotfiles-watcher` — the auto-sync daemon — with the rest
covering the bootstrap/install path (the dependency registry). Seeded lazily
during an architecture review; grow it as new coined concepts appear.

## Working in this repo

The `dotfiles-watcher` daemon auto-commits the working tree on a debounce
(`DEBOUNCE_SECS`, default 3 min) whenever tracked files change — including edits
made during an active session. So while you work here:

- `git status` may show fewer pending changes than you just made, and commits
  you didn't author will appear (labelled with the machine name from
  `machine.local`, e.g. `"<machine-name> - N file(s) changed"`). Your changes
  aren't lost — they've been committed and will sync.
- Don't rely on the working tree staying dirty between steps. If you need a
  stable staging area — to stage a partial change, or review a full diff before
  it commits — run `make watcher-pause` first, then `make watcher-resume` when
  done. (A pause is an operator-induced [Halt](#language); same `HALT_FILE`.)

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

**Dependency registry**:
The single source of truth for everything this repo installs, expressed by
system type. Two data-only files hold the declarations: `deps.tsv` (package-
manager tools — `probe`, `darwin-pkg`, `linux-pkg`, `group`, `required`, `desc`)
and `apps.tsv` (GUI/procedural apps — `key`, `label`, `default`; install bodies
stay as `<key>_present` / `<key>_install_mac` / `<key>_install_linux` functions
in `dotfiles-install-lib`, found by convention from the `key`). `bin/dotfiles-deps`
is the read-only accessor over both and never installs — it exposes three verbs:
`list <group>` (tool rows for a group; the installer feeds each to `ensure_tool`),
`apps` (every app row; the installer drives each through `ensure_app_key`, the
key→function-names wrapper), and `check <group>` (the Makefile preflight — probe
each tool, and on a missing *required* row print a per-OS install hint and exit
non-zero; non-required misses are silent, so soft deps like coreutils/flock don't
fail the preflight). Apps are tools-and-groups-blind: they carry no `group`, so the
eza-is-core-vs-`DO_APPS`-GUI split lives in the installer (the literal key `eza`),
not in the data. Data lives in the registry; installing stays in the adapters.
_Avoid_: manifest, lockfile, dependency DSL.

**Dependency group**:
The `group` column in `deps.tsv` — the join key both registry consumers query
by. The dependency groups (`core`, `watcher`, `test`, `ssh`) are *not* the
installer's checklist groups; `core` is always installed, while `watcher` /
`test` / `ssh` are gated by the matching `DO_*` checklist toggle. The Makefile
preflight asks for the group a target needs (`make test` → `check test`).
_Avoid_: phase, category, checklist group.

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
