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

## scanning many files for relevance (noul-per-file)
Judging whether each file in a directory is relevant to some topic — piping file bytes straight from disk into `decide` so content never enters your own context — is a recurring pattern. Gotchas that bite on the first attempt:

- **the CLI has a short client-side timeout (~2s).** Any file whose raw content pushes the call past that aborts with `decide: The operation was aborted due to timeout` — and a file as small as ~5KB can trigger it. Worse, a timed-out call doesn't necessarily stop server-side work, so the *next* request queues behind it and times out too, even if it's tiny — one slow file can cascade into near-total failure across the whole batch.
- **clip proactively, not just for "tens of KB+" files.** Clip anything over **~3000 bytes** to head 1500 chars + tail 1500 chars (joined with a `...` separator) before sending. Build the clipped string inline in the pipeline — never echo file content into your own context:
  ```bash
  size=$(wc -c < "$f")
  if [ "$size" -gt 3000 ]; then
    content=$(printf '%s\n...\n%s' "$(head -c 1500 "$f")" "$(tail -c 1500 "$f")")
  else
    content=$(cat "$f")
  fi
  score=$(jq -n --arg q "$Q" --arg c "$content" \
            '{state:$c, questions:{rel:{type:"noul", instructions:$q}}}' | decide \
          | jq -r '.answers.rel.noul // "ERR"')
  ```
- **retry once on `ERR` after a backoff** (~5s) before giving up on a file — this absorbs the cascade above. Track how many files needed a retry; a high retry count on a run with no genuinely huge files signals the clip threshold is too high for the current hardware load, not that the files are bad.
- **threshold selection: use gap analysis over the full ranked list, not a fixed cutoff and not sequential early-stop.** Walking the ranked list and stopping at the first miss assumes relevance is cleanly monotonic in score — in practice `noul` scores on a batch of real files came out mushy (a generic/unrelated file scored *higher* than a semantically-plausible one), so a single low-scoring file mid-list is not a reliable "everything past here is irrelevant" signal. Compute consecutive-score gaps across the whole sorted list and cut at the largest gap below the obvious top cluster; report the gap size and whether separation was clean or mushy.

## notes
- server must be running (launchd agent `com.tsaodown.decider`); `curl -s 127.0.0.1:8000/` or re-run `decide` to check.
- full model, use-case catalog, and Claude Code wiring live in the vault note *Local Decider (OpenJev)*.
