# dotfiles

Personal dotfiles repo. Managed with `stow` (see `Makefile`).

## Commits are automatic

`bin/dotfiles-watcher` auto-commits changes in this repo (the `… N file(s) changed` commits). So edits land in git on their own — the global "don't commit without asking" rule doesn't apply here, and there's no need to flag that you're leaving changes uncommitted. Just leave the working tree in the state you want committed. (Pushing and other remote/destructive git actions still follow the global rule.)

### Restarting the watcher

A running daemon won't pick up edits to `bin/dotfiles-watcher` (or its sourced libs) until it restarts. The portable restart is `make watcher-stop && make watcher-start`. On macOS `make watcher-start` alone is enough — it does a `launchctl kickstart -k` that restarts an already-loaded daemon — but on Linux `systemctl start` is a no-op on a running unit, so prefer the stop-then-start form. Other controls: `make watcher-status`, `make watcher-logs`, `make watcher-sync` (force an immediate commit), `make watcher-pull` (force an ff-pull).

## CI

`.github/workflows/install.yml` runs `make install` then `make test` on ubuntu + macOS.

**Path-gated.** Markdown, `docs/`, `claude/`, and `cursor/` don't trigger a run — no test covers them and they can't affect whether `make install` succeeds. Everything else does, including `git-stack` gitlink bumps: an unpushed submodule commit makes the recursive checkout fail with `upload-pack: not our ref`, and catching that is the point. A run is skipped only when *every* changed file matches, so a mixed commit still runs. `workflow_dispatch` is the manual override.

**The watcher tests need a file-event backend installed explicitly.** `make install` disables the watcher group under `DOTFILES_CI` (the daemon can't run headless), which also skips its dependencies — and every watcher test self-skips without `fswatch`/`inotifywait`. The workflow installs that group separately, reading package names from `deps.tsv`, and fails the build if it sees the skip marker: 26 green skips look identical to 26 passes.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `tsaodown/dotfiles`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root (lazily created). See `docs/agents/domain.md`.
