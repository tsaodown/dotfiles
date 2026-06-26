---
name: operational-readiness
description: Make sure someone else can debug/operate a feature in prod when the implementer is away. Two modes — (1) CAPTURE-AS-YOU-GO: when an operational surface is built in a session (monitor, alert, dashboard, control plane, feature flag, config knob, failure mode + recovery, escalation path), capture it toward the project note's `## Operational notes`; (2) RELEASE-GATE ASSEMBLY: when a project nears prod, run the Operational Readiness checklist against captures, flag gaps, and assemble + publish the runbook to the team destination. Use while implementing operational surfaces or when a tracked project nears release. The standard lives in `conventions/Operational Readiness.md`.
---

# Operational readiness

The in-session mechanism for the [[Operational Readiness]] standard (`conventions/Operational Readiness.md` in the engineering vault — read it for the full checklist + rationale). Same model as `log-project-progress` and `stakeholder-comms` — **capture in the moment, act at the milestone.**

The artifact (the runbook) is **shared, code-coupled** knowledge — it goes where on-call looks, never the personal vault. Destination is per-project, resolved through:

**project note → `Operational home:` → team operational note (e.g. [[Digital Workflows Operations]]) → [[Operational Readiness]] (structure/style).**

Captures accrue in the project note's `## Operational notes` section (via obsidian MCP); the assembled doc publishes to the resolved destination (repo file via `Write`, or Confluence via the Atlassian MCP).

## Mode 1 — Capture-as-you-go (primary)

**Trigger:** an operationally-significant surface is built or changed in a session:
- a monitor, alert, or dashboard
- a control plane / operator knob
- a feature flag or config knob (and its safe values)
- a known failure mode + how you'd detect it + recovery steps
- a dependency (and what happens when it's unavailable)
- an escalation path / ownership boundary

**Do:** offer to capture it toward the project's `## Operational notes` while the detail is fresh — append via `obsidian_patch_note` under that heading, structured by the checklist below. This is the load-bearing mode: by release the runbook should be ~80% written from these increments, so the gate is a review-and-publish pass, not a from-scratch sprint. Don't wait for release to start capturing.

## Mode 2 — Release-gate assembly (secondary)

**Trigger:** the project nears prod — status flips toward shipping, `## Rollout` starts filling, or the [[Release]] SDLC stage is entered.

**Do:**
1. **Resolve the destination** — read the project note's `Operational home:` pointer → team operational note → confirm where the runbook lands (repo `docs/` vs team Confluence space).
2. **Run the checklist** against `## Operational notes`, flag gaps:
   - How to run / operate it (entry points, normal flow, config/flags + safe values)
   - Control planes (the knobs, what each does)
   - Monitors & alerts (what's watched, what each alert *means*, dashboard links)
   - **Failure modes + recovery** (what breaks, how you'd know, what to do — the load-bearing section for a 2am debugger)
   - Dependencies (upstream/downstream, behavior when each is down)
   - Escalation / ownership
   - Acceptance test: can a reader answer *"it's broken — is it this feature, how would I tell, what do I do?"* from the doc alone?
3. **Assemble + publish** to the resolved destination:
   - **Repo** → write `docs/runbook-<feature>.md` (or update the component `CLAUDE.md`) in the **same PR as the change** (per [[Codebase Documentation & Architecture Learning]]).
   - **Confluence** → create/update the team-space page via the Atlassian MCP.
   - The user does the final publish/PR per the usual posting + git rules (global CLAUDE.md) — draft, then wait for confirmation.
4. **Link back** — add the published location to the team operational note's "Projects landing here" and to the project's `## Operational notes`.

## Picking the project — don't guess

Infer from the conversation and working directory; if ambiguous, **ask**. If the project note lacks an `Operational home:` pointer, this is a capture moment — infer the likely team operational note and offer to add it.

## Notes

- Never capture or publish secrets, tokens, or credentials — reference where they live, don't inline them.
- Capture is opportunistic and cheap; assembly is the milestone act. Don't defer all capture to the gate — that's the scramble this skill exists to prevent.
- The artifact never lives in the vault — only the captures (`## Operational notes`) and the standard do.
