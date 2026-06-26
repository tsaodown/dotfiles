# dotfiles

Personal dotfiles repo. Managed with `stow` (see `Makefile`).

## Commits are automatic

`bin/dotfiles-watcher` auto-commits changes in this repo (the `… N file(s) changed` commits). So edits land in git on their own — the global "don't commit without asking" rule doesn't apply here, and there's no need to flag that you're leaving changes uncommitted. Just leave the working tree in the state you want committed. (Pushing and other remote/destructive git actions still follow the global rule.)

## Agent skills

### Issue tracker

Issues live as GitHub issues in `tsaodown/dotfiles`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root (lazily created). See `docs/agents/domain.md`.
