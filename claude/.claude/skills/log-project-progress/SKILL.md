---
name: log-project-progress
description: Record a notable unit of project work into the engineering Obsidian vault — appends a dated bullet to today's daily note and transcludes it into the matching project's Logs. Use while investigating, testing, implementing, reviewing, or deciding on something that maps to a tracked vault project/investigation/bug, when a meaningful increment lands (a finding, a decision, a completed chunk, a test result, a blocker). Also use when the user says "log this", "record progress", "note that in the vault".
---

# Logging project progress

Headless equivalent of the vault's `manage-block-log` Templater hotkey. One call writes a `- [<shorthand>] <body> ^<id>` bullet under today's daily-note heading and inserts `![[<date>#^<id>]]` into the project's `## Logs` — identical formatting (it reuses the vault's own `log-core.js`).

## When to log

Record **notable increments**, not every step. Log when one of these lands:

- a **finding** (root cause, how a system actually works, a surprising constraint)
- a **decision** (chose approach X over Y, and why)
- a **completed chunk** of implementation
- a **test/verification result** (passed, failed, reproduced)
- a **blocker / handoff / next-step** worth surfacing tomorrow

Skip: routine file reads, intermediate edits, thinking-out-loud, anything low-signal. When in doubt, batch a session's worth of real progress into one or a few bullets rather than narrating each action.

## How to invoke

```
node ~/.claude/skills/log-project-progress/log-progress.js \
  --project "<project name or shorthand>" \
  --body "<concise note>" \
  [--date YYYY-MM-DD] [--json]
```

- **`--project`** matches a tracked work item by its note basename (e.g. `"DARCS Split"`, case-insensitive) **or** an exact shorthand (e.g. `"project/digital routing work"`). The project must already have a `shorthand` in its frontmatter.
- **`--body`** is the bullet text. Match the daily-note voice: terse, lowercase, concrete fragments — e.g. `"traced bypass to leaf-030; DAR skipped when ROI id present"`, not a full sentence with a capital and period.
- **`--date`** defaults to today (local). Pass it only to backfill an earlier day.
- **`--json`** prints the structured result if you need to parse it.

## Picking the project — don't guess

Infer the project from the conversation and working directory. If it's genuinely ambiguous, **ask the user** which project rather than guessing.

The CLI fails (exit 1) with an actionable message — surface it, don't paper over it:

- **`no work item matched`** → it lists known shorthands. Pick the right one, or ask the user.
- **`matched N items`** (ambiguous) → ask the user which.
- **`has no shorthand set`** → tell the user; offer to add a `shorthand:` to that note's frontmatter (don't invent one silently).

## Notes

- Each call **appends** a new bullet — don't re-run for the same increment (it duplicates).
- The daily note is created from the vault template if today's doesn't exist yet.
- Writes vault files directly. Never log secrets, tokens, or credentials.
- v1 is log-only; to **move** an existing bullet to another day, use the in-Obsidian `manage-block-log` hotkey.
