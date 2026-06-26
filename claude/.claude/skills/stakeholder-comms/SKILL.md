---
name: stakeholder-comms
description: Keep project stakeholders informed of changes they track. Two behaviors — (1) CAPTURE a stakeholder/dependency into the project note's `## Stakeholders` section when one surfaces in a working session; (2) NUDGE + DRAFT + RECORD when a comms-worthy event lands (timeline/scope/status change, external blocker, ship, or dependency-workstream progress), drafting an update to the audience's native surface (Slack/Jira/Confluence) and recording it in `## Stakeholder updates`. Use while working a tracked vault project when a stakeholder surfaces or a comms-worthy event happens. The standard lives in the vault note `conventions/Stakeholder Communication.md`.
---

# Stakeholder communication

The in-session mechanism for the [[Stakeholder Communication]] standard (`conventions/Stakeholder Communication.md` in the engineering vault — read it for the full rationale). Sibling to `log-project-progress`: logging records *internal* progress; this communicates *external* news. Same model — **capture in the moment, act at the milestone.**

State lives in the project note (`datavant/work/projects/<Project>.md`), reached via the obsidian MCP (`obsidian_patch_note` / `obsidian_get_note`):
- `## Stakeholders` — routing + interest-scope (who / where / what they care about).
- `## Stakeholder updates` — the record of updates sent (date, audience, gist).

## Behavior 1 — Capture a stakeholder

**Trigger:** a stakeholder or dependency surfaces in conversation — "I'm coordinating with Team X on the staging test," "my EM wants weekly updates," "this needs platform's sign-off," a person/team/channel mentioned as caring about or gating the project.

**Do:** offer to add them to the project's `## Stakeholders` section. One row:
```
- [[Person or Team]] / #channel or @dm / other surface — interest-scope
```
Interest-scope is *what they want to hear* — "milestones only", "test progress + any date impact", "only when the API contract changes". This is what later widens the comms filter for that audience, so capture it specifically, don't leave it generic. Don't invent people or channels — ask if unsure. Append via `obsidian_patch_note` under the `## Stakeholders` heading.

## Behavior 2 — Nudge, draft, record

**Trigger — fire only when an event is comms-worthy.** The 6 universal triggers:
1. Timeline change (slip, pull-in, milestone hit/missed, new ETA)
2. Status flip (active → paused / blocked / shipped / abandoned)
3. Scope change (something promised now in/out)
4. External-facing blocker (stuck on *them*, or it affects their date)
5. Ship / rollout (in prod, or about to be)
6. Dependency-workstream progress (a stakeholder is an active participant/blocking dependency on a workstream — joint e2e, shared integration, handoff — so progress/results there matter even when routine, especially if shared dates move)

…**or** the event matches a stakeholder's declared interest-scope in `## Stakeholders`.

**Bias to under-fire.** A missed nudge costs one late update; an over-firing nudge gets the whole system muted. Fire on the clear-cut; on the ambiguous middle, fold a soft "(worth telling anyone?)" into the log confirmation instead of a separate alarm. Do **not** nudge on internal findings, refactors, or routine test passes on solo work.

**When it fires:**
1. **Read** `## Stakeholders` to find which audience(s) this event matters to (by trigger or interest-scope) and where they live.
2. **Draft** the update in the user's voice — lowercase, casual, lead with the point (per global CLAUDE.md). Cover only: *what changed · impact on date/scope/them · the ask, if any.* No preamble, no root-cause retelling.
3. **Route** to the audience's native surface:
   - Slack channel/DM → `slack_send_message_draft` (lands in the real composer)
   - Jira ticket → comment via the Atlassian MCP
   - Confluence space → page/comment via the Atlassian MCP
   - anything else (email, standup) → in-chat text
4. **The user always does the final send.** Never post outward-facing without explicit confirmation (global CLAUDE.md). Draft and route; wait for "go".
5. **Record** after sending — append to `## Stakeholder updates` (newest first) via `obsidian_patch_note`:
   ```
   - YYYY-MM-DD — [[audience]] / surface — one-line gist
   ```

## Picking the project — don't guess

Infer from the conversation and working directory. If ambiguous, **ask** which project. If the project note has no `## Stakeholders` section yet, this is also a capture moment — offer to seed it.

## Notes

- Never log or post secrets, tokens, or credentials.
- Capture is unfiltered (cheap to add a stakeholder); the nudge is filtered (under-fire). Don't conflate.
- A sent update is itself a notable increment — logging it via `log-project-progress` is fine *in addition* to the `## Stakeholder updates` record, but the structured record is the source of truth.
