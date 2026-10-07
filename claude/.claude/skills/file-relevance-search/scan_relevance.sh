#!/bin/bash
# Rank files in a directory by relevance to a topic using the local `decide` CLI.
# Content flows disk -> jq -> decide; never printed, never loaded into caller context.
#
# Usage:
#   scan_relevance.sh --dir DIR --question "..." [--pattern '*.java'] [--cache PATH] [--clip-bytes 3000]
#
# Output (stdout): "<score|ERR>\t<path>" lines, ranked descending, plus a
# gap-analysis summary and cache hit/miss counts on stderr.

set -euo pipefail

dir=""
question=""
pattern="*"
cache=""
clip_bytes=3000
clip_chars=1500

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="$2"; shift 2 ;;
    --question) question="$2"; shift 2 ;;
    --pattern) pattern="$2"; shift 2 ;;
    --cache) cache="$2"; shift 2 ;;
    --clip-bytes) clip_bytes="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$dir" ] && [ -n "$question" ] || { echo "usage: scan_relevance.sh --dir DIR --question Q [--pattern GLOB] [--cache PATH]" >&2; exit 2; }
[ -z "$cache" ] && cache="$dir/.decider-cache.json"
[ -f "$cache" ] || echo '{}' > "$cache"

qhash=$(printf '%s' "$question" | shasum -a 256 | cut -d' ' -f1)

call_decide() {
  jq -n --arg q "$question" --arg c "$1" \
    '{state:$c, questions:{rel:{type:"noul", instructions:$q}}}' | decide 2>/dev/null
}

hits=0
misses=0
retries=0
results=""

shopt -s nullglob
for f in "$dir"/$pattern; do
  [ -f "$f" ] || continue
  chash=$(shasum -a 256 "$f" | cut -d' ' -f1)
  key="${qhash}:${chash}:$(basename "$f")"

  cached=$(jq -r --arg k "$key" '.[$k].score // empty' "$cache")
  if [ -n "$cached" ]; then
    hits=$((hits+1))
    score="$cached"
  else
    misses=$((misses+1))
    size=$(wc -c < "$f")
    if [ "$size" -gt "$clip_bytes" ]; then
      content=$(printf '%s\n...\n%s' "$(head -c "$clip_chars" "$f")" "$(tail -c "$clip_chars" "$f")")
    else
      content=$(cat "$f")
    fi

    res=$(call_decide "$content")
    score=$(echo "$res" | jq -r '.answers.rel.noul // "ERR"' 2>/dev/null || echo "ERR")
    if [ "$score" = "ERR" ] || [ "$score" = "null" ] || [ -z "$score" ]; then
      retries=$((retries+1))
      sleep 5
      res=$(call_decide "$content")
      score=$(echo "$res" | jq -r '.answers.rel.noul // "ERR"' 2>/dev/null || echo "ERR")
    fi

    if [ "$score" != "ERR" ] && [ "$score" != "null" ] && [ -n "$score" ]; then
      tmp=$(mktemp)
      jq --arg k "$key" --argjson s "$score" --arg ts "$(date -u +%FT%TZ)" \
        '.[$k] = {score: $s, ts: $ts}' "$cache" > "$tmp" && mv "$tmp" "$cache"
    else
      score="ERR"
    fi
    sleep 0.3
  fi

  results="${results}${score}\t$(basename "$f")\n"
done

printf '%b' "$results" | sort -rn

echo "---" >&2
echo "cache hits: $hits  misses: $misses  retries: $retries" >&2
echo "cache file: $cache" >&2
