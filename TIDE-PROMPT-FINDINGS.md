# Tide powerline prompt missing after `make install` — findings & fix

## Symptom

After running `make install` on a fresh box, the fish [tide](https://github.com/IlanCosman/tide)
prompt renders blank/plain — no powerline, no git/pwd segments — even though all the
tide plugin files are present and stowed.

## TL;DR root cause

The installer's "seed plugin config" phase is guarded by the **wrong variable**. It
checks `_tide_left_items` (a derived *cache* variable tide rewrites on every prompt
render) instead of `tide_left_prompt_items` (the actual *config* variable). On a fresh
box the very first interactive prompt render writes `_tide_left_items` as a
**set-but-empty** universal variable; fish's `set -q` returns true for set-but-empty,
so the guard trips and the seed is silently skipped. None of the ~159 `tide_*` config
vars ever get set, so tide has nothing to render.

## How tide is wired here (the relevant design)

Plugins in this repo are **vendored** — every plugin's files are committed under
`fish/.config/fish/{functions,completions,conf.d}` and become active through the stow
symlinks. The installer deliberately does **not** run `fisher install` (see the long
comment at `bin/dotfiles-install:255`).

Because nothing is `fisher install`ed, tide's one-time `_tide_init_install` event
(`fish/.config/fish/conf.d/_tide_init.fish:1`) never fires, so tide's config is never
written. tide stores its config in `fish_variables` (universal vars), which is
gitignored runtime state — so a fresh box starts with **zero** `tide_*` vars and a
blank prompt.

To compensate, `fish/.config/fish/seed-universal.fish` is a curated snapshot of all the
`tide_*` (and fish-exa / abbr-tips) universal vars. The installer sources it once on an
unconfigured box (`bin/dotfiles-install:292`).

## The bug, precisely

The seed phase (`bin/dotfiles-install:292-297`):

```fish
set -q _tide_left_items; and exit 0          # <-- wrong guard variable
test -e $__fish_config_dir/seed-universal.fish; or exit 0
source $__fish_config_dir/seed-universal.fish
tide reload 2>/dev/null
```

`_tide_left_items` is **not** a config variable. It is a *derived cache* that
`_tide_remove_unusable_items` recomputes from `tide_left_prompt_items` on **every
prompt render** (`fish/.config/fish/functions/_tide_remove_unusable_items.fish:19`):

```fish
set -U _tide_left_items (for item in $tide_left_prompt_items
    contains $item $removed_items || echo $item
end)
```

Sequence of events on a fresh box:

1. An interactive fish shell starts and renders the prompt. `fish_prompt` calls
   `_tide_remove_unusable_items`.
2. At that point `tide_left_prompt_items` is **unset** (seed hasn't run), so the `for`
   loop emits nothing and the line executes as `set -U _tide_left_items` with no values
   — creating a **set-but-empty** universal variable.
3. The installer's seed phase runs. `set -q _tide_left_items` returns **true** (fish's
   `set -q` is true for a set-but-empty var), so `and exit 0` fires and the seed is
   **skipped**.
4. Result: 0 `tide_*` config vars → blank prompt.

The ordering in step 1↔3 is easy to hit: `config.fish` `exec`s into tmux on the first
interactive shell, and any interactive fish (the one you ran `make install` from, a
kitty window, etc.) renders a prompt and poisons `_tide_left_items` before/around the
seed phase.

## Evidence

On the affected machine:

```
$ fish -c 'set -U --names | grep -i tide'
_tide_left_items          # exists...
_tide_prompt_14859        # (volatile per-pid caches)
_tide_prompt_15872
_tide_prompt_21396
_tide_prompt_40005
_tide_right_items

$ fish -c 'count $_tide_left_items'          # ...but empty
0
$ fish -c 'set -q _tide_left_items[1]; and echo yes; or echo no'
no
$ fish -c 'set -q tide_left_prompt_items; and echo SET; or echo UNSET'
UNSET                                         # the real config var: never set
$ fish -c 'set -U --names | grep -c "^tide_"'
0                                             # zero tide config vars
```

`set -q` trips on a set-but-empty universal var:

```
$ fish -c 'set -U x; set -q x; and echo "set -q TRUE on empty var"'
set -q TRUE on empty var
```

Sourcing the seed in an isolated `$HOME` does populate everything:

```
$ source seed-universal.fish
tide_left_prompt_items=[vi_mode pwd git newline]
tide_* config var count = 159
```

End-to-end repro (poison the cache var empty, then run each guard):

```
OLD guard  set -q _tide_left_items        -> seed SKIPPED,  tide_config_count=0   (BUG)
NEW guard  set -q tide_left_prompt_items[1] -> seed APPLIED, tide_config_count=159 (FIXED)
```

## Fix

Guard on the real config variable, and index `[1]` so a set-but-empty value still counts
as "needs seeding".

In `bin/dotfiles-install`, the seed phase:

```fish
# before
set -q _tide_left_items; and exit 0

# after
set -q tide_left_prompt_items[1]; and exit 0
```

`tide_left_prompt_items` is the persistent config var the seed sets
(`seed-universal.fish:86`); the `[1]` index guards against the identical set-but-empty
trap. This keeps the "don't clobber a box you've since customized" intent — a configured
box has a non-empty `tide_left_prompt_items` and is left untouched.

Also update the now-stale comments that name the guard variable:
- `bin/dotfiles-install:284-285` ("Guarded on `_tide_left_items`")
- `fish/.config/fish/seed-universal.fish:8` ("guarded on `_tide_left_items`")

## Recover the already-broken machine

The fix only changes future installs. To fix the current box now, source the seed once
(it also overwrites the poisoned empty `_tide_left_items`/`_tide_right_items` with proper
values), then reload:

```fish
source ~/.config/fish/seed-universal.fish
tide reload   # or just open a new shell
```
