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
│   └── dotfiles-watcher-paths   # source of truth for state-dir / log paths
├── git-stack/              # git submodule -> github.com/tsaodown/git-stack
│                           # symlinked into ~/.local/bin via `make bin-link`
├── launchd/
│   └── com.tsaodown.dotfiles-watcher.plist.tmpl   # macOS LaunchAgent template
├── systemd/
│   └── dotfiles-watcher.service.tmpl              # Linux systemd user service template
├── tests/                  # bats tests for the watcher (git-stack tests live in the submodule)
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
brew install stow fswatch git fish tmux coreutils flock
```

**Ubuntu / Linux**

```sh
sudo apt-get install -y stow git inotify-tools fish tmux
```

On Linux, `coreutils` (`timeout`) and `util-linux` (`flock`) are part of the base system, so they aren't listed above.

`fswatch` is also supported on Linux (the watcher checks for it first, then falls back to `inotifywait`). `inotify-tools` is the zero-friction default on Ubuntu. On WSL2, `notify-send` desktop notifications are skipped gracefully if no notification daemon is running.

`nc` (netcat) is used by the watcher's offline-aware deferral — when the machine wakes without network, pulls and syncs are deferred with exponential backoff and resume once the network is back, instead of silently failing or halting. macOS ships BSD nc by default; most Linux distros ship `nc` via `netcat-openbsd` or similar. If `nc` is missing, the watcher logs a warning at startup and behaves as before (best-effort).

`coreutils` (for `gtimeout`) and `flock` back two watcher reliability features and are macOS-only prereqs — Linux ships both in its base system. `gtimeout` enforces a wall-clock timeout on each git fetch/pull/push so a wedged network op can't hang the watcher; the watcher also sets SSH keepalives (`ServerAliveInterval`/`ServerAliveCountMax`/`ConnectTimeout`) on its own git calls so a dead connection is dropped in seconds rather than waiting out the ~15-minute OS TCP timeout. `flock` enforces a single running instance. Both degrade gracefully: without `gtimeout` the ops run unwrapped (keepalives still apply), and without `flock` the instance lock is skipped.

`bats-core` and GNU `parallel` are optional dev deps — only needed if you want to run `make test`. Tests run with `bats --jobs N` for parallelism, which requires GNU `parallel`. The bootstrap will offer to install both (defaults to "no"); you can also `brew install bats-core parallel` (macOS) or `sudo apt-get install -y bats parallel` (Ubuntu) directly. To suppress GNU parallel's first-run citation banner, the bootstrap creates `~/.parallel/will-cite`; do this manually if you skip the bootstrap install path.

## Setup

### New-machine setup (fresh clone)

```sh
git clone --recurse-submodules https://github.com/tsaodown/dotfiles.git ~/dotfiles && cd ~/dotfiles && make install
```

This uses the HTTPS URL so it works on a fresh machine with no SSH key set up (the repo is public, so the clone needs no auth). If you forgot `--recurse-submodules`, run `make submodules` after cloning.

> **Heads up — auto-sync push auth:** an HTTPS clone leaves `origin` on HTTPS, and the auto-sync watcher *pushes* commits, which HTTPS can't do without a credential helper / personal access token. If you plan to enable the watcher on this machine, set up an SSH key ([github.com/settings/keys](https://github.com/settings/keys)) and switch the remote:
> ```sh
> git -C ~/dotfiles remote set-url origin git@github.com:tsaodown/dotfiles.git
> ```
> Cloning over SSH from the start (`git@github.com:tsaodown/dotfiles.git`) also works if the key's already in place.

That's it. On macOS, `make install` will offer to install Homebrew if it's missing, then install `stow`/`fswatch`/`fish`/`tmux` plus the watcher extras (`coreutils`, `flock`). On Ubuntu/WSL2 it uses `apt-get` for `stow`/`inotify-tools`/`fish`/`tmux`. After deps, it stows the packages and optionally sets up the watcher.

### First-machine setup (configs are live in `$HOME`, repo is empty)

```sh
cd ~/dotfiles
make install
```

The interactive bootstrap will:
1. Bootstrap Homebrew on macOS if missing, then install `stow`, `git`, `fish`, `tmux`, and `fswatch`/`inotifywait` if missing (plus, on macOS, `coreutils`/`flock` for the watcher)
2. Detect that the repo packages are empty and offer to seed from `$HOME`
3. Run `stow` to create symlinks for `zsh fish tmux kitty cursor vscode claude`
4. Symlink `git-stack` (from the submodule) into `~/.local/bin`
5. Optionally install TPM + tmux plugins
6. Optionally install fisher + fish plugins
7. Optionally install desktop apps — kitty, 1Password (app + `op` CLI), Obsidian — each prompted separately (see *Desktop apps* below)
8. Optionally install the auto-sync watcher (launchd on macOS, systemd user service on Linux)

On a fresh clone, the seed step is skipped because the configs are already in the repo.

### Desktop apps

The bootstrap can also install a few GUI apps, prompted one at a time (each defaults to yes when the app is missing, and is skipped if already installed):

| App | macOS | Ubuntu / Linux |
|---|---|---|
| kitty | `brew install --cask kitty` | `apt-get install kitty` (in the Ubuntu repos) |
| 1Password (app + `op` CLI) | `brew install --cask 1password 1password-cli` | official [1Password apt repo](https://support.1password.com/install-linux/), then `apt install 1password 1password-cli` |
| Obsidian | `brew install --cask obsidian` | official `.deb` from [`obsidianmd/obsidian-releases`](https://github.com/obsidianmd/obsidian-releases/releases) (latest), via `apt install ./obsidian_*_amd64.deb` |

These are best-effort and opt-in: declining or a failed install never aborts the rest of the bootstrap. On Linux the Obsidian `.deb` and the 1Password desktop app are **amd64/x86_64 only** (the `op` CLI does support arm64) — on arm64 the Obsidian step is skipped with a note, install AppImage/flatpak by hand.

## Commands

| Command | Description |
|---|---|
| `make install` | Interactive bootstrap (deps + stow + watcher) |
| `make stow` | Just create the symlinks |
| `make unstow` | Remove all symlinks |
| `make restow` | Clean stale links and re-link |
| `make check` | Dry-run; show what stow would change |
| `make submodules` | Initialize / update git submodules (e.g. `git-stack`) |
| `make bin-link` / `bin-unlink` | Symlink `git-stack` (from the submodule) into `~/.local/bin` |
| `make test` | Run bats tests under `tests/` (recurses into git-stack submodule when present); requires `bats-core` + GNU `parallel` |
| `make watcher-install` | Install the daemon (override `DEBOUNCE_SECS` / `PULL_INTERVAL_SECS`) |
| `make watcher-uninstall` | Remove the daemon |
| `make watcher-start` / `watcher-stop` | Manual lifecycle |
| `make watcher-status` | Is it loaded? Is it halted? |
| `make watcher-logs` | Colorized `tail -F` the log |
| `make watcher-pause` / `watcher-resume` | Manual halt sentinel |
| `make watcher-sync` | Force an immediate sync (bypasses debounce) |
| `make watcher-pull` | Force an immediate ff-pull (bypasses the scheduled-pull slot) |

## Auto-sync watcher

When installed, the watcher runs as a daemon (launchd agent on macOS, systemd user service on Linux) and:

- Watches `~/dotfiles/` via `fswatch` (or `inotifywait` on Linux) for any change to a tracked file
- After **3 minutes** of quiet (configurable via `DEBOUNCE_SECS`), runs `git pull --rebase && git commit && git push`
- Commit message format: `2026-05-01 00:20:25 my-laptop - 4 file(s) changed` (the machine name comes from `machine.local` — see *Multi-machine sync* below)
- Independently does a scheduled `git fetch && git merge --ff-only` every 6 hours, slot-aligned to local midnight (default boundaries: 0/6/12/18 local; configurable via `PULL_INTERVAL_SECS`, default 21600s — slot duration in seconds), so other machines' changes flow in even when this one is idle
- On wake from sleep (detected via tick gap > `WAKE_GAP_SECS`), an extra ff-pull fires immediately so you don't have to wait for the next slot
- If the network is unreachable, pulls/syncs are deferred with exponential backoff (30s → 60s → 120s, capped at 5min) and retried on each tick. Every retry is logged; recovery is automatic when the network returns

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
| watcher | `~/dotfiles/machine.local` | first line is read as the machine name in commit messages (e.g. `my-laptop`) |

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

The scheduled ff-pull continues running while halted (it's read-only), but no commits or pushes happen until you resume.

## Branches

- `main` — the active modern setup (this README, Stow packages, watcher) — supports macOS and Ubuntu/Linux
- `legacy-linux` — the archived Linux desktop configs (i3, polybar themes, rofi, alacritty, antigen, nvim, etc.) preserved for historical reference
