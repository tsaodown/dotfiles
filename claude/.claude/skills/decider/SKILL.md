---
name: decider
description: Use for cheap, fast typed decisions instead of reasoning in prose — triaging/routing an item into categories, scoring severity/complexity/impact/priority, judging yes/no (is this file relevant to the task? does this output mean the tests passed? is this change risky?), or interpreting tool/command/log/test output to pick the next action. Offloads a judgment to a local System One model via the `decide` CLI so you don't spend a full generation on it.
---

# decider

A local **System One** model (Mapika/decider, served on `127.0.0.1:8000`) answers *typed* questions with calibrated-ish confidence and **no text generation**. Reach for it when you'd otherwise burn tokens reasoning out a small, well-scoped judgment — routing, scoring, a yes/no gate, or reading test/deploy/log output to decide what to do next.

## when to use
- **triage / route** an item into one of a few buckets → `choice`
- **score** severity / complexity / impact / priority / a review axis → `score`
- **yes/no judgment** — file relevant to the current task? output a pass? change risky? → `noul`
- **interpret output** (test results, analysis tool output, deploy/exec logs) to pick the next action, instead of reading it all yourself

Not for open-ended reasoning, multi-hop analysis, or anything needing an explanation — that's your job. decider only picks from options you give it.

## how to call it
Quick yes/no:
```bash
decide --noul "is a refund needed?" "customer was charged twice for order A-104"
# -> prints a probability in [0,1]
```

Anything richer — pipe a full request, read back JSON:
```bash
echo '{
  "state": "<text to judge>",
  "questions": {
    "team":     { "type": "choice", "instructions": "which team?", "criteria": { "billing": "charges, refunds", "technical": "bugs, outages" } },
    "priority": { "type": "score",  "instructions": "how urgent?",  "criteria": ["low", "normal", "high", "urgent"] }
  }
}' | decide
```

## rules (these bite if you get them wrong)
- **batch** every question for one item into a single call — they evaluate in parallel, ~free vs one question.
- **choice** → returns `choice`, `probabilities{}`, and `confidence` = `(p_max − 1/k)/(1 − 1/k)` for k options (0 = a coin-flip guess; one threshold works across option counts).
- **noul** → returns only a `noul` probability, **no confidence field** — threshold on the value itself.
- **score** → `criteria` MUST be an **ordered array of 2–10 level strings** (not a sentence), else you get a 400. Returns a continuous `score` + a `legend`.
- **avoid vague catch-all options** ("other", "else") in a `choice` — they steal probability mass and wreck confidence.
- **act on confidence, not just the pick**: high → act; low/mid → fall back to your own judgment or ask.
- **fail open**: if `decide` exits non-zero (server down/slow), just make the call yourself — never block on it.

## notes
- server must be running (launchd agent `com.tsaodown.decider`); `curl -s 127.0.0.1:8000/` or re-run `decide` to check.
- full model, use-case catalog, and Claude Code wiring live in the vault note *Local Decider (OpenJev)*.
