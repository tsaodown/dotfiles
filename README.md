# dotfiles

GNU Stow–managed configs for zsh, fish, tmux, kitty, Cursor, and VSCode, with an optional auto-sync daemon that batches edits into timestamped commits and pushes to the remote.

## Layout

```
dotfiles/
├── Makefile                # one-command interface — `make help`
├── bin/
│   ├── dotfiles-install    # interactive bootstrap
│   ├── dotfiles-watcher    # the auto-sync daemon
│   └── dotfiles-seed       # one-time live-config ingestion
├── launchd/
│   └── com.tsaodown.dotfiles-watcher.plist.tmpl   # macOS LaunchAgent template
├── systemd/
│   └── dotfiles-watcher.service.tmpl               # Linux systemd user service template
├── zsh/.zshrc
├── fish/.config/fish/{config.fish, conf.d/, functions/, completions/, fish_plugins}
├── tmux/.tmux.conf
├── kitty/.config/kitty/kitty.conf
├── cursor/Library/Application Support/Cursor/User/{settings.json, keybindings.json, snippets/}
└── vscode/Library/Application Support/Code/User/{settings.json, keybindings.json, snippets/}
```

Top-level Stow packages: `zsh fish tmux kitty cursor vscode`.

## Prerequisites

**macOS**

```sh
brew install stow fswatch git
```

**Ubuntu / Linux**

```sh
sudo apt-get install -y stow git inotify-tools
```

`fswatch` is also supported on Linux (the watcher checks for it first, then falls back to `inotifywait`). `inotify-tools` is the zero-friction default on Ubuntu. On WSL2, `notify-send` desktop notifications are skipped gracefully if no notification daemon is running.

## Setup

### First-machine setup (configs are live in `$HOME`, repo is empty)

```sh
cd ~/dotfiles
make install
```

The interactive bootstrap will:
1. Check `stow`, `fswatch`, `git` are installed
2. Detect that the repo packages are empty and offer to seed from `$HOME`
3. Run `stow` to create symlinks
4. Optionally install TPM + tmux plugins
5. Optionally install fisher + fish plugins
6. Optionally install the auto-sync watcher as a launchd agent

### New-machine setup (fresh clone)

**macOS**

```sh
brew install stow fswatch git
git clone git@github.com:tsaodown/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

**Ubuntu / WSL2**

```sh
sudo apt-get install -y stow git inotify-tools
git clone git@github.com:tsaodown/dotfiles.git ~/dotfiles
cd ~/dotfiles
make install
```

The bootstrap will skip the seed step (configs are already in the repo) and just symlink them into place.

## Commands

| Command | Description |
|---|---|
| `make install` | Interactive bootstrap (deps + stow + watcher) |
| `make stow` | Just create the symlinks |
| `make unstow` | Remove all symlinks |
| `make restow` | Clean stale links and re-link |
| `make check` | Dry-run; show what stow would change |
| `make watcher-install` | Install the launchd agent (override `DEBOUNCE_SECS` / `PULL_INTERVAL_SECS`) |
| `make watcher-uninstall` | Remove the launchd agent |
| `make watcher-start` / `watcher-stop` | Manual lifecycle |
| `make watcher-status` | Is it loaded? Is it halted? |
| `make watcher-logs` | `tail -F` the log |
| `make watcher-pause` / `watcher-resume` | Manual halt sentinel |

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
