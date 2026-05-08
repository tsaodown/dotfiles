# dotfiles

GNU Stow–managed configs for zsh, fish, tmux, kitty, Cursor, and VSCode, with an optional auto-sync daemon that batches edits into timestamped commits and pushes to the remote.

## Layout

```
dotfiles/
├── Makefile                # one-command interface — `make help`
├── bin/
│   ├── dotfiles-install         # interactive bootstrap (deps + stow + watcher)
│   ├── dotfiles-seed            # one-time live-config ingestion
│   ├── dotfiles-watcher         # the auto-sync daemon
│   ├── dotfiles-watcher-logs    # colorized `tail -F` of the watcher log
│   ├── dotfiles-watcher-paths   # source of truth for state-dir / log paths
│   └── git-stack                # stacked-PR helper (symlinked into ~/.local/bin)
├── launchd/
│   └── com.tsaodown.dotfiles-watcher.plist.tmpl   # macOS LaunchAgent template
├── systemd/
│   └── dotfiles-watcher.service.tmpl              # Linux systemd user service template
├── tests/                  # bats tests for the watcher and git-stack
├── zsh/.zshrc
├── fish/.config/fish/{config.fish, conf.d/, functions/, completions/, fish_plugins}
├── tmux/{.tmux.conf, pane-minimap.py, reorder-window.sh}
├── kitty/.config/kitty/kitty.conf
├── claude/.claude/{CLAUDE.md, settings.json, commands/, statusline-command.sh}
├── cursor/Library/Application Support/Cursor/User/{settings.json, keybindings.json, snippets/}
└── vscode/Library/Application Support/Code/User/{settings.json, keybindings.json, snippets/}
```

Top-level Stow packages: `zsh fish tmux kitty` (folded) and `cursor vscode claude` (unfolded). The tmux helper scripts are referenced from `.tmux.conf` via `~/dotfiles/tmux/...` and are excluded from stow via `tmux/.stow-local-ignore`.

## Prerequisites

`make install` will offer to install anything missing. You don't have to install prereqs by hand — but if you want to:

**macOS**

```sh
brew install stow fswatch git
```

**Ubuntu / Linux**

```sh
sudo apt-get install -y stow git inotify-tools
```

`fswatch` is also supported on Linux (the watcher checks for it first, then falls back to `inotifywait`). `inotify-tools` is the zero-friction default on Ubuntu. On WSL2, `notify-send` desktop notifications are skipped gracefully if no notification daemon is running.

`bats-core` is an optional dev dep — only needed if you want to run `make test`. The bootstrap will offer to install it (defaults to "no"); you can also `brew install bats-core` (macOS) or `sudo apt-get install -y bats` (Ubuntu) directly.

## Setup

### New-machine setup (fresh clone)

```sh
git clone git@github.com:tsaodown/dotfiles.git ~/dotfiles && cd ~/dotfiles && make install
```

That's it. On macOS, `make install` will offer to install Homebrew if it's missing, then install `stow`/`fswatch`. On Ubuntu/WSL2 it uses `apt-get` for `stow`/`inotify-tools`. After deps, it stows the packages and optionally sets up the watcher.

### First-machine setup (configs are live in `$HOME`, repo is empty)

```sh
cd ~/dotfiles
make install
```

The interactive bootstrap will:
1. Bootstrap Homebrew on macOS if missing, then install `stow`, `git`, and `fswatch`/`inotifywait` if missing
2. Detect that the repo packages are empty and offer to seed from `$HOME`
3. Run `stow` to create symlinks for `zsh fish tmux kitty cursor vscode claude`
4. Symlink user-facing tools (e.g. `git-stack`) into `~/.local/bin`
5. Optionally install TPM + tmux plugins
6. Optionally install fisher + fish plugins
7. Optionally install the auto-sync watcher (launchd on macOS, systemd user service on Linux)

On a fresh clone, the seed step is skipped because the configs are already in the repo.

## Commands

| Command | Description |
|---|---|
| `make install` | Interactive bootstrap (deps + stow + watcher) |
| `make stow` | Just create the symlinks |
| `make unstow` | Remove all symlinks |
| `make restow` | Clean stale links and re-link |
| `make check` | Dry-run; show what stow would change |
| `make bin-link` / `bin-unlink` | Symlink user-facing tools (e.g. `git-stack`) into `~/.local/bin` |
| `make test` | Run bats tests under `tests/` (requires `bats-core`) |
| `make watcher-install` | Install the daemon (override `DEBOUNCE_SECS` / `PULL_INTERVAL_SECS`) |
| `make watcher-uninstall` | Remove the daemon |
| `make watcher-start` / `watcher-stop` | Manual lifecycle |
| `make watcher-status` | Is it loaded? Is it halted? |
| `make watcher-logs` | Colorized `tail -F` the log |
| `make watcher-pause` / `watcher-resume` | Manual halt sentinel |
| `make watcher-sync` | Force an immediate sync (bypasses debounce) |

## Auto-sync watcher

When installed, the watcher runs as a daemon (launchd agent on macOS, systemd user service on Linux) and:

- Watches `~/dotfiles/` via `fswatch` (or `inotifywait` on Linux) for any change to a tracked file
- After **3 minutes** of quiet (configurable via `DEBOUNCE_SECS`), runs `git pull --rebase && git commit && git push`
- Commit message format: `2026-05-01 00:20:25 datavant laptop - 4 file(s) changed`
- Independently does a daily `git fetch && git merge --ff-only` (configurable via `PULL_INTERVAL_SECS`, default 86400) so other machines' changes flow in even when this one is idle

To change the intervals:

```sh
make watcher-install DEBOUNCE_SECS=120 PULL_INTERVAL_SECS=43200
```

## Multi-machine sync

Every machine pushes to and pulls from `origin/main`. Files are mostly identical across machines; per-machine differences live in gitignored `.local` overlays:

| Tool | Override file | How it's loaded |
|---|---|---|
| zsh | `~/.zshrc.local` | sourced at end of `.zshrc` if present |
| fish | `~/.config/fish/config.local.fish` | sourced at end of `config.fish` if present |
| tmux | `~/.tmux.conf.local` | `source-file -q` at end of `.tmux.conf` |
| kitty | `~/.config/kitty/kitty.local.conf` | `include` at end of `kitty.conf` (silently skipped if missing) |
| watcher | `~/dotfiles/machine.local` | first line is read as the machine name in commit messages (e.g. `datavant laptop`) |

These files are in `.gitignore` and never sync.

## Conflict recovery

If two machines edit the same line of the same file inside a single debounce window, the loser's `git pull --rebase` will fail. The watcher then:

1. `git rebase --abort`s to restore a clean state
2. Writes a halt sentinel (`~/Library/Application Support/dotfiles-watcher/halt` on macOS; `~/.local/share/dotfiles/watcher/halt` on Linux)
3. Sends a desktop notification if available (macOS: always; Linux/WSL2: only if `notify-send` is present)
4. Stops auto-pushing

To recover:

```sh
cd ~/dotfiles
git status                       # see the conflicted files
# resolve each one by hand
git add <file>
git rebase --continue            # if there was a rebase in progress
# or just commit if not in a rebase
make watcher-resume              # clears the halt sentinel
```

The daily ff-pull continues running while halted (it's read-only), but no commits or pushes happen until you resume.

## Branches

- `main` — the active modern setup (this README, Stow packages, watcher) — supports macOS and Ubuntu/Linux
- `legacy-linux` — the archived Linux desktop configs (i3, polybar themes, rofi, alacritty, antigen, nvim, etc.) preserved for historical reference
