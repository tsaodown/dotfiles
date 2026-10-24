#!/usr/bin/env bash
# Restore global (user-level) agent skills recorded in ~/.agents/.skill-lock.json.
#
# The `skills` CLI's `experimental_install` only restores project-level skills
# from a project skills-lock.json; it ignores the global lock. This script fills
# that gap by re-running `npx skills add -g` for every skill in the global lock,
# deriving the source repo and skill name from the lock itself so the two stay
# in sync. Run it on a fresh machine after `make stow` has linked the lock file.
#
# Plugin-packaged skills (superpowers, mattpocock-skills, frontend-design, …) are
# NOT handled here — they travel via enabledPlugins in settings.json.
set -euo pipefail

LOCK="${HOME}/.agents/.skill-lock.json"
[ -f "$LOCK" ] || { echo "no lock file at $LOCK" >&2; exit 1; }

python3 - "$LOCK" <<'PY' | while IFS=$'\t' read -r name source; do
import json, sys
d = json.load(open(sys.argv[1]))
for name, meta in d.get("skills", {}).items():
    src = meta.get("source") or meta.get("sourceUrl")
    if src:
        print(f"{name}\t{src}")
PY
  echo ">>> npx skills add $source -g -y -a claude-code -s $name"
  npx skills add "$source" -g -y -a claude-code -s "$name"
done
