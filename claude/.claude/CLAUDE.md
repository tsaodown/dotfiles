# Writing style

When drafting text that's going out as a conversational reply *from me* — Slack thread replies, Slack DMs, PR comments, PR review-comment replies, GitHub issue comments, and similar back-and-forth communication — match my voice:

- **Minimal capitalization.** Lowercase by default, including at the start of sentences and in proper-noun-ish words where it reads naturally. Capitalize only when needed for clarity (acronyms, code identifiers, file paths, product names where lowercase would be confusing).
- **Casual tone.** Conversational, not formal. Contractions are fine. Skip corporate-speak ("leverages", "ensures", "facilitates"). Skip throat-clearing openers ("This PR...", "I wanted to...").
- **No trailing period on the final sentence** of a message, paragraph, or thread reply. Mid-message sentences still get periods; just drop the very last one. (Question marks and exclamation points stay.)

This is specifically for **conversational replies posted under my identity**. It does NOT apply to:
- Commit messages, PR descriptions, design docs — these follow normal repo/team conventions
- Code, code comments, identifiers, SQL keywords — anything where capitalization is semantically meaningful
- Documentation files where house style dictates capitalization
- Your own responses to me in chat — use whatever capitalization is natural for you

If you're not sure whether something counts as a "conversational reply from me," ask.

# Conciseness

In tickets, PR descriptions, code/doc comments, and design notes: lead with the point, cut preamble and restatement, keep only load-bearing detail. Aim for the shortest version a reviewer can act on. This applies to drafts you show me too — including in chat.

**PR descriptions specifically** tend to come out too long. Keep them tight: a 1–3 sentence description (what changed + why, no multi-paragraph root-cause retelling), and a test plan that's just the commands/steps to verify. Drop background a reviewer can get from the diff or linked ticket. If the impact/context is genuinely important, one short line — not a paragraph.

# Shell

My daily-driver shell is **fish**. When you hand me shell commands to paste/run myself, write them in fish syntax — `set VAR value` (not `VAR=value`), `set -x VAR value` to export, `(cmd)` for command substitution (not `$(cmd)`), and `env VAR=value cmd` for one-shot env overrides. `&&`, `||`, and pipes work as in POSIX. (Commands you run yourself via tools can use whatever; this is about snippets I'll execute in my own shell.)

# Git

Don't perform git actions on my behalf unless I explicitly ask. This includes `git add`, `git commit`, `git push`, `git checkout`, `git stash`, `git rebase`, `git merge`, branch creation/deletion, `gh pr create`, and similar. Read-only inspection (`git status`, `git log`, `git diff`, `git blame`) is fine. If you think a git action is warranted, suggest it and wait for me to confirm.

# Posting to external services (GitHub, Slack, etc.)

Don't post anything outward-facing on my behalf without explicit confirmation first. This includes PR comments, PR reviews, inline review comments, issue comments, and Slack messages — anything created via `gh pr comment`, `gh pr review`, `gh issue comment`, the GitHub API, or Slack tools. Draft the content, show it to me, and wait for me to say go. This applies even when a skill or slash command would otherwise post automatically — show me the draft and let me confirm before it goes out.

Never append "Generated with Claude Code" banners, 🤖 footers, "Co-Authored-By: Claude" trailers, or similar attribution to anything posted under my identity (comments, reviews, commit messages). Leave them out entirely, even when a skill template includes them.

# Code review

When I ask you to review a PR, prefer posting findings as **inline code review comments** anchored to the relevant lines, bundled into a single formal review (`gh pr review`) — using **request changes** when there's a blocking issue, or **comment**/**approve** otherwise — rather than one big summary issue-comment. Still draft it and get my confirmation before submitting (see posting rules above).

# Codebase documentation

Scouting a codebase for a change produces two durable products — route each, don't conflate them. Full model: vault note `conventions/Codebase Documentation & Architecture Learning.md`.

- **Repo docs (shared, code-coupled).** After a technical investigation, surface evergreen *structural* facts into the repo's own docs, in the **same PR** as the change. Route by altitude: internal-to-one-component → that component's `CLAUDE.md` / `README`; spans ≥2 components or external-service/cross-repo edges → a `docs/<flow>.md` and/or the right-altitude `CLAUDE.md`. ADRs only for decisions actually *made* (decided-vs-found: never ADR structure you merely observed). The repo — not the vault — owns shared structural truth.
- **Vault (personal, transferable).** Plans, investigation framing, and the architecture pattern library go in the vault, never the repo. When an "oh, *that's* how they did it" moment fires, drop a one-line stub in `architecture/_inbox.md` (async — never block the task); it gets promoted later to a frozen, dated, self-contained instance note (embed curated code snippets + a commit-pinned permalink) or deleted at drain.
- **New to a repo?** Seed the doc skeleton with a one-off cross-cutting flow investigation (the one exception to opportunistic-only documentation).

# Handoff docs

Write temporary handoff docs (forward task specs for another agent/session to pick up) to `$HOME/.handoff-docs` — create the dir if it doesn't exist. Use a descriptive kebab-case filename prefixed with an ISO date, e.g. `2026-06-26-heal-5547-istio-holdappuntilproxystarts-handoff.md`; if for some reason the date can't go in the filename, put a `created:` ISO timestamp in YAML frontmatter instead. Either way, every handoff must carry its creation date so staleness is visible. Don't drop them in the per-process OS temp dir (`$TMPDIR`) — it's harder to find and gets cleaned more aggressively. These are ephemeral scratch, distinct from the durable plans/architecture notes that go in the vault; never commit them to a repo.

When you write a new handoff doc, glance at `$HOME/.handoff-docs` and clean up anything more than a month old (by its filename date or `created:` frontmatter) — delete stale handoffs, or flag them to me if you're unsure. Handoffs are meant to be short-lived; don't let them pile up.

# Obsidian references

If I mention a "note" or "doc", I'm usually referring to the obsidian engineering vault.

# Working on a tracked project

When work maps to a tracked vault project (or investigation/bug), watch the working-session surface for these signals and route each to the right skill. Shared model across all three: **capture in the moment, act at the milestone.** When the project is ambiguous, ask rather than guess. Each skill carries its own detailed when/how — these are just the routing triggers.

- **A notable increment lands** (a finding, decision, completed chunk, test/verification result, blocker) → **`log-project-progress`**. Notable increments only — not every step; batch a session's real progress into a few terse bullets, don't narrate routine actions.
- **A comms-worthy event lands** (timeline change, status flip, scope change, external-facing blocker, ship/rollout, or dependency-workstream progress — or anything matching a stakeholder's declared interest-scope) → **`stakeholder-comms`** (nudge + draft + record). **Bias to under-fire** — a muted nudge is worse than a missed one; skip internal findings, refactors, and routine solo test passes.
- **A stakeholder or dependency surfaces** ("coordinating with Team X", "my EM wants weekly updates", "needs platform sign-off") → **`stakeholder-comms`** (capture into the project's `## Stakeholders`).
- **An operational surface is built** (monitor, alert, dashboard, control plane, feature flag, config knob, failure mode + recovery, escalation path) → **`operational-readiness`** (capture into `## Operational notes`).
- **The project nears prod** (status flips toward shipping, Rollout filling, entering the Release stage) → **`operational-readiness`** (assemble + publish the runbook to the team destination).

The standards behind these live in the vault: `conventions/Stakeholder Communication.md` and `conventions/Operational Readiness.md`.

# Custom skills

Author custom skills (and other Claude Code config) **in the dotfiles repo**, then symlink them into place — never create them directly under `~/.claude`. The real files live at `~/dotfiles/claude/.claude/...` and are surfaced via symlinks so they're version-controlled and portable. For a skill, that means: write `~/dotfiles/claude/.claude/skills/<name>/SKILL.md` (plus any scripts) as the real files, then symlink `~/.claude/skills/<name>/SKILL.md` → `../../../dotfiles/claude/.claude/skills/<name>/SKILL.md` (file-level symlinks inside a real skill dir, matching `log-project-progress`). Same pattern as the existing `CLAUDE.md` / `settings.json` symlinks. After creating a skill this way, the dotfiles repo is the thing to commit.

# Project conventions (Obsidian vault)

Project-specific conventions are loaded automatically via `.claude/CLAUDE.md` files that `@import` the relevant vault note. Current mappings:

| Project | Vault note |
|---|---|
| `~/code/healthsource` | `datavant/systems/healthsource/Conventions.md` |
| `~/code/idsb/worker_pod/src/retrieval-configurator` | `datavant/systems/rcs/Conventions.md` |
| `~/code/idsb/digital_workflows/ops-workflow-config-service` | `datavant/systems/owcs/Conventions.md` |

To add a new project: create `.claude/CLAUDE.md` in the project root with an `@/absolute/path/to/vault/Conventions.md` line, add `.claude/` to the project's `.gitignore`, and update this table.
