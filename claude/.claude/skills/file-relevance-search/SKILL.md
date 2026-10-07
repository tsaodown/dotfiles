---
name: file-relevance-search
description: Rank files in a directory by relevance to a topic/question without loading their content into the agent's own context — piping bytes straight from disk into the local `decide` judge, with a content-hash cache so repeat scans of unchanged files are free. Use when asked to find which files in a directory relate to some concern, or to judge file relevance at scale. Depends on the `decider` skill.
---

# file-relevance-search

Scores every file in a directory against a topic using `decider`'s `noul` (yes/no probability) judgment, so you can rank a whole directory without ever reading a file's contents yourself. Built on the `decider` skill — read that first if you haven't.

## when to use
- "which files in this directory are about X" / "find files relevant to Y"
- any task that explicitly forbids reading file contents to judge relevance (the point of the exercise is to trust a cheap judge's score, not your own reading)

## how to run it
```bash
~/.claude/skills/file-relevance-search/scan_relevance.sh \
  --dir /path/to/directory \
  --question "Does this file define, read, write, or map SUBSITE data — as opposed to unrelated concerns?" \
  --pattern '*.java'
```

Prints `score\tfilename` lines, ranked descending, to stdout. Cache hit/miss/retry counts go to stderr.

Flags: `--pattern GLOB` (default `*`), `--cache PATH` (default `<dir>/.decider-cache.json`), `--clip-bytes N` (default `3000`).

## why a cache
`decide` calls cost real latency (~1-3s each) and the clip-before-send step below means a cached score is cheap to trust: the cache key is `hash(question) : hash(file content) : filename`. Edit the file → different content hash → automatic cache miss → re-scored. No "confirmed relevance" update mechanism needed, no stale weights — the hash *is* the invalidation.

## gotchas (from the first real run — read before re-deriving these)
- **`decide`'s client-side timeout is short (~2s)**, and a file as small as ~5KB can exceed it. A timed-out call can leave server-side work running, so the next request queues behind it and times out too — one oversized file can cascade into near-total batch failure. The script clips anything over `--clip-bytes` (default 3000 bytes) to head 1500 chars + tail 1500 chars before sending, and retries once after a 5s backoff on `ERR`.
- **content never leaves disk into your context.** Don't `cat`/`Read` a file to sanity-check a score — if you need to verify, note the score and ask the invoker, don't substitute your own reading.
- **threshold selection: gap analysis over the full sorted list, not sequential early-stop.** Real scores come out mushy — a semantically-unrelated file can score *higher* than an obviously relevant one — so walking the ranked list and stopping at the first low score assumes a monotonic signal that doesn't hold. Compute consecutive-score gaps across the whole list and cut at the largest gap below the top cluster. Report the gap size and whether separation was clean or mushy; don't assume a fixed cutoff like 0.5.
- fail open per the `decider` skill: if the server's down, say so and fall back to your own judgment rather than guessing scores.
