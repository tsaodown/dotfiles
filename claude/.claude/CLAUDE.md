# Editing this config (read before touching any file under ~/.claude)

Everything that matters under `~/.claude/` is a **symlink into the dotfiles repo** — `~/.claude/CLAUDE.md` → `~/dotfiles/claude/.claude/CLAUDE.md`, and the same for `settings.json` and each skill's `SKILL.md`. Agents get this wrong constantly, so:

- **Edit the real file** at `~/dotfiles/claude/.claude/...`, not the `~/.claude/...` path. Run `readlink -f <path>` first if you're unsure which you're holding.
- **Never replace a symlink with a regular file.** A write tool that overwrites rather than edits in place will sever the dotfiles link, and the change silently drops out of version control.
- The dotfiles repo is the thing that would get committed — but don't commit it unless I ask (see Git below).

# Writing style

When drafting text that's going out as a conversational reply *from me* — Slack thread replies, Slack DMs, PR comments, PR review-comment replies, GitHub issue comments, and similar back-and-forth communication — match my voice:

- **Minimal capitalization.** Lowercase by default, including at the start of sentences and in proper-noun-ish words where it reads naturally. Capitalize only when needed for clarity (acronyms, code identifiers, file paths, product names where lowercase would be confusing).
- **Casual tone.** Conversational, not formal. Contractions are fine. Skip corporate-speak ("leverages", "ensures", "facilitates"). Skip throat-clearing openers ("This PR...", "I wanted to...").
- **No trailing period at the end of a line.** I don't end whole lines with a period — not just the last line of a message, but *every* paragraph, bullet, and numbered list item. Sentences *within* a line still get their periods; it's only the final one on the line that gets dropped. (Question marks and exclamation points stay.) Reread drafts for this specifically — it's the rule that gets missed most.

This is specifically for **conversational replies posted under my identity**. It does NOT apply to:
- Commit messages, PR descriptions, design docs — these follow normal repo/team conventions
- Code, code comments, identifiers, SQL keywords — anything where capitalization is semantically meaningful
- Documentation files where house style dictates capitalization
- Your own responses to me in chat — use whatever capitalization is natural for you

If you're not sure whether something counts as a "conversational reply from me," ask.

# Conciseness

In tickets, PR descriptions, code/doc comments, and design notes: lead with the point, cut preamble and restatement, keep only load-bearing detail. Aim for the shortest version a reviewer can act on. This applies to drafts you show me too — including in chat.

**PR descriptions specifically** tend to come out too long. Keep them tight: a 1–3 sentence description (what changed + why, no multi-paragraph root-cause retelling), and a test plan that's just the commands/steps to verify. Drop background a reviewer can get from the diff or linked ticket. If the impact/context is genuinely important, one short line — not a paragraph.

**Code comments specifically** tend to come out too verbose, and too many of them. Default to fewer comments. Don't narrate what the code already says, restate the function/variable/test name, or add section-divider banners. Comment only the non-obvious *why* — an unintuitive constraint, a workaround and its reason, a subtle invariant, a gotcha that would bite the next reader. State a shared invariant once, in the place it's defined — don't restate it at each site it governs; and skip a comment on a line whose neighbor already carries the explanation. Keep comments timeless — describe what the code *does*, not what it used to do or just changed to ("now fires here", "no longer needed"); change-relative wording rots as the diff ages. When in doubt, leave it out; clear code beats a comment explaining unclear code. Match the comment density of the surrounding file.

Be judicious about **project-management context in code** (Jira/Linear ticket IDs, PR numbers, sprint references). Most of it belongs in the commit message or PR, not in a code comment — the code outlives the ticket, and a bare `# PDC-1234` rots into noise once the ticket is closed. Only keep a ticket reference inline when it earns its place: it points to context a future reader genuinely needs and can't reconstruct from the code (the rationale behind a non-obvious workaround, a tracked follow-up/`TODO`, a deferred fix). Even then, prefer a one-line summary of *why* over a bare ID — and if you include the ID, make it ride along with that explanation, not stand alone.

# Shell

My daily-driver shell is **fish**. When you hand me shell commands to paste/run myself, write them in fish syntax — `set VAR value` (not `VAR=value`), `set -x VAR value` to export, `(cmd)` for command substitution (not `$(cmd)`), and `env VAR=value cmd` for one-shot env overrides. `&&`, `||`, and pipes work as in POSIX. (Commands you run yourself via tools can use whatever; this is about snippets I'll execute in my own shell.)

# Git

Don't perform git actions on my behalf unless I explicitly ask. This includes `git add`, `git commit`, `git push`, `git checkout`, `git stash`, `git rebase`, `git merge`, branch creation/deletion, `gh pr create`, and similar. Read-only inspection (`git status`, `git log`, `git diff`, `git blame`) is fine. If you think a git action is warranted, suggest it and wait for me to confirm.

# Commit titles & messages

My default subject format, for commits and the PR titles they become:

```
<TICKET-123> [<scope>]: <imperative description>    # ticket present
[<scope>]: <imperative description>                 # no ticket
```

- **Scope + colon are the invariant; the ticket is an optional prefix** — most of my commits don't have one. `HEAL-6910 [dar]: allow primary cancel with surviving dupes`, `[owcs]: align config-keys response field names with HS`.
- **The ticket is never bracketed** — brackets hold the scope and nothing else, in both modes. `HEAL-6910 [dar]: …`, never `[HEAL-6910][dar]: …`.
- **Imperative, lowercase, no trailing period. 64 characters for the typed part** — GitHub appends ` (#1234)` on squash, so 64 keeps merged commits unwrapped in `git log` at 80 columns. Trim the description to fit; never drop the ticket or scope.
- **Scope** = whatever that repo's own log already calls the deploy unit — read it, don't invent one. For a cross-cutting change, name the component that owns the *behavior* change, not the one with the most diff lines. `a/b` only when two are genuinely co-equal.
- **Body:** terse bullets wrapped at 72, one per major change, then the ticket URL as a trailer line. A helper earns a bullet when it has ≥2 call sites (or is built for reuse), or when it's removed/renamed — not for private single-use helpers or test fixtures. Fill the PR template's *Related Issues* section too.
- **Check where the body survives** before writing one: `gh api repos/<owner>/<repo> --jq '{title:.squash_merge_commit_title, message:.squash_merge_commit_message}'`. `COMMIT_MESSAGES` → the commit body lands on `main` verbatim. `PR_BODY` → it's discarded on squash, so mirror the bullets into the PR description or the work is lost. A repo's `pull_request_template.md` beats GitHub's prefill, so that mirror is always manual.
- **Conventional mode** — where tooling requires it, the type token leads and the ticket moves after the colon: `fix(esmd): HEAL-6911 increase callback await timeout`. The trigger is per-PR, not per-file: one matching path forces conventional for the whole title.
- **WIP:** the format binds every commit that records work. The only exemption is a parking commit made to get a clean tree for a checkout/rebase/worktree switch — prefix it `wip:` and don't let it reach `main`. Machine-authored subjects (`Revert "…"`, release-please releases, dependabot, merge commits) are out of scope entirely.

**Precedence — this default is superseded, in this order:**

1. **Enforced repo tooling wins.** PR title checks (`amannn/action-semantic-pull-request`), release-please, commitlint. Derive it with `grep -rl semantic-pull-request .github/workflows/` (read its `paths:` filter) plus `ls release-please-config.json .commitlintrc*`.
2. **Written team convention wins next.** The project's `Conventions.md`, the repo's `CLAUDE.md`, the PR template.
3. **This default otherwise.**

A repo's *observed but unenforced* house style supplies the scope vocabulary only — it does not override the format.

Full model, including the per-repo table of which paths require conventional titles and which repos squash from the PR body: vault note `conventions/Commit & PR Titles.md`.

# Posting to external services (GitHub, Slack, etc.)

Don't post anything outward-facing on my behalf without explicit confirmation first. This includes PR comments, PR reviews, inline review comments, issue comments, and Slack messages — anything created via `gh pr comment`, `gh pr review`, `gh issue comment`, the GitHub API, or Slack tools. Draft the content, show it to me, and wait for me to say go. This applies even when a skill or slash command would otherwise post automatically — show me the draft and let me confirm before it goes out.

Never append "Generated with Claude Code" banners, 🤖 footers, "Co-Authored-By: Claude" trailers, or similar attribution to anything posted under my identity (comments, reviews, commit messages). Leave them out entirely, even when a skill template includes them.

# Slack messages

When you draft a Slack message for me, default to handing me the message as a **copy-pasteable block I drop into Slack myself** — don't post it via the Slack tools unless I explicitly say to post/send it. (Confirmation to post is per-message; "go" on one draft doesn't carry to the next.)

Format the body in **Slack mrkdwn**, not GitHub-flavored markdown, so it renders right on paste:
- `*bold*` (single asterisks), `_italic_` (underscores), `~strike~` (single tildes)
- `` `inline code` `` and ```` ``` ```` fenced code blocks both work as-is
- `> blockquote` works; bullets use `-` or `•`
- **No `#` headers** (Slack doesn't render them — use `*bold*` for emphasis instead)
- **Links are `<https://url|link text>`**, not `[text](url)`
- Voice still follows the Writing style rules above (lowercase, casual, no trailing period). No Claude attribution.

Present the draft inside a single fenced block so I can grab the whole thing in one copy.

# Code review

When I ask you to review a PR, prefer posting findings as **inline code review comments** anchored to the relevant lines, bundled into a single formal review (`gh pr review`) — using **request changes** when there's a blocking issue, or **comment**/**approve** otherwise — rather than one big summary issue-comment. Still draft it and get my confirmation before submitting (see posting rules above).

# Shared environments

Shared lower environments (qa01, try, staging) are claimed in a Slack channel, not locked. Before deploying a service to one — or merging, where one merge can deploy to several at once — check whether someone already holds it. Claims are decaying assertions, not state: an unreleased claim that's days old usually means the holder forgot to react, not that the env is busy. Posting a claim or reacting to release needs my go, like any Slack post.

Full model: vault note `conventions/Shared Environment Reservations.md` — it names the per-project channel and instance doc.

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
