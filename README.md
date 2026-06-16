# dotfiles

GNU Stow–managed configs for zsh, fish, tmux, kitty, and VSCode, plus an optional daemon that auto-commits edits into timestamped commits and syncs them across machines. macOS and Ubuntu/Linux.

## Quick start

```sh
git clone --recurse-submodules https://github.com/tsaodown/dotfiles.git ~/dotfiles && cd ~/dotfiles && make install
```

`make install` is an interactive bootstrap: it installs missing deps, stows the packages, and runs an opt-in checklist (tmux/fish plugins, default shell → fish, desktop apps, GitHub SSH, watcher, test tooling — all on by default). The HTTPS URL works on a fresh machine with no SSH key. Forgot `--recurse-submodules`? Run `make submodules`. On a machine where configs are already live in `$HOME`, the bootstrap first offers to seed them into the repo.

If it changes your login shell to fish, log out and back in for it to take effect.

> **Watcher push auth:** the watcher *pushes* commits, which an HTTPS `origin` can't do unattended. The bootstrap's **GitHub SSH** phase registers a key and switches `origin` to SSH. To do it by hand:
> ```sh
> git -C ~/dotfiles remote set-url origin git@github.com:tsaodown/dotfiles.git
> ```

## Layout

```
dotfiles/
├── Makefile                # one-command interface — `make help`
├── bin/                    # installer, dependency registry accessor, and watcher scripts
├── deps.tsv / apps.tsv     # dependency registry — what gets installed, per OS
├── git-stack/              # submodule -> github.com/tsaodown/git-stack; linked into ~/.local/bin
├── launchd/ · systemd/     # watcher service templates (macOS · Linux)
├── tests/                  # bats tests (git-stack tests live in the submodule)
├── zsh/ · fish/ · tmux/ · kitty/   # folded Stow packages
└── claude/ · vscode/               # unfolded Stow packages
```

Stow packages: `zsh fish tmux kitty` (folded) and `vscode claude` (unfolded). See `CONTEXT.md` for the watcher internals and dependency-registry design.

## Commands

| Command | Description |
|---|---|
| `make install` | Interactive bootstrap (deps + stow + watcher) |
| `make stow` / `unstow` / `restow` | Create / remove / re-link the symlinks |
| `make check` | Dry-run; show what stow would change |
| `make submodules` | Initialize / update git submodules (e.g. `git-stack`) |
| `make bin-link` / `bin-unlink` | Symlink `git-stack` into `~/.local/bin` |
| `make test` | Run bats tests (requires `bats-core` + GNU `parallel`) |
| `make watcher-install` / `watcher-uninstall` | Install / remove the daemon |
| `make watcher-start` / `watcher-stop` | Manual lifecycle |
| `make watcher-status` | Is it loaded? Is it halted? |
| `make watcher-logs` | Colorized `tail -F` of the log |
| `make watcher-pause` / `watcher-resume` | Manual halt sentinel |
| `make watcher-sync` / `watcher-pull` | Force an immediate sync / ff-pull |

## Auto-sync watcher

When installed (launchd on macOS, systemd user service on Linux), the watcher keeps every machine in sync with `origin/main`:

- Watches `~/dotfiles/` and, after **3 min** of quiet (`DEBOUNCE_SECS`), runs `git pull --rebase && git commit && git push`. Commits are labelled with the machine name from `machine.local`, e.g. `2026-05-01 00:20:25 my-laptop - 4 file(s) changed`.
- Independently does a scheduled ff-pull every **6h** (`PULL_INTERVAL_SECS`, slot-aligned to local midnight), plus one on wake from sleep, so idle machines still pull in changes.
- Offline-aware: pulls/pushes are deferred with backoff and resume when the network returns.

Override the intervals at install time:

```sh
make watcher-install DEBOUNCE_SECS=120 PULL_INTERVAL_SECS=43200
```

**Conflict recovery:** if a rebase conflict can't auto-resolve, the watcher halts (stops pushing, notifies, writes a sentinel) until you fix it by hand and run `make watcher-resume`. The scheduled ff-pull keeps running while halted since it's read-only. See `CONTEXT.md` for the halt / drain / rolling-sync model.

## Per-machine overrides

Files are mostly identical across machines; per-machine differences live in gitignored `.local` overlays, sourced at the end of each config (never synced):

| Tool | Override file |
|---|---|
| zsh | `~/.zshrc.local` |
| fish | `~/.config/fish/config.local.fish` |
| tmux | `~/.tmux.conf.local` |
| kitty | `~/.config/kitty/kitty.local.conf` |
| watcher | `~/dotfiles/machine.local` (first line = machine name in commits) |

## Branches

- `main` — the active setup (this README, Stow packages, watcher); macOS + Ubuntu/Linux
- `legacy-linux` — archived Linux desktop configs (i3, polybar, rofi, alacritty, nvim, etc.) kept for reference
