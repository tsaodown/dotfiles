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

Write temporary handoff docs (forward task specs for another agent/session to pick up) to `/tmp/handoffs/` — create the dir if it doesn't exist. Use a descriptive kebab-case filename, e.g. `heal-5547-istio-holdappuntilproxystarts-handoff.md`. Don't drop them in the per-process OS temp dir (`$TMPDIR`) — it's harder to find and gets cleaned more aggressively. These are ephemeral scratch, distinct from the durable plans/architecture notes that go in the vault; never commit them to a repo.

# Obsidian references

If I mention a "note" or "doc", I'm usually referring to the obsidian engineering vault.

# Recording project progress

As we investigate, test, implement, review, or decide on work that maps to a tracked vault project (or investigation/bug), record the progress using the **`log-project-progress`** skill. Log **notable increments** — a finding, a decision, a completed chunk, a test/verification result, a blocker — not every step. Don't narrate routine actions; batch a session's real progress into a few terse bullets. When the project is ambiguous, ask rather than guess. See the skill for invocation and rules.

# Project conventions (Obsidian vault)

Project-specific conventions are loaded automatically via `.claude/CLAUDE.md` files that `@import` the relevant vault note. Current mappings:

| Project | Vault note |
|---|---|
| `~/code/healthsource` | `datavant/systems/healthsource/Conventions.md` |
| `~/code/idsb/worker_pod/src/retrieval-configurator` | `datavant/systems/rcs/Conventions.md` |
| `~/code/idsb/digital_workflows/ops-workflow-config-service` | `datavant/systems/owcs/Conventions.md` |

To add a new project: create `.claude/CLAUDE.md` in the project root with an `@/absolute/path/to/vault/Conventions.md` line, add `.claude/` to the project's `.gitignore`, and update this table.
