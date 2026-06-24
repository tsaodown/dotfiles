"use strict";

/*
 * lib — pure core for the log-project-progress CLI.
 *
 * No filesystem, no `app`/`tp`, no clock. Everything here is a pure function of
 * its inputs so it's unit-testable headless (lib.test.js). The I/O shell
 * (vault scan, today's date, file read/write) lives in log-progress.js.
 *
 * The vault's daily-note + project-Logs format is owned by
 * templates/_scripts/log-core.js (placeLogEntry et al.); this module only adds
 * the headless-specific pieces: frontmatter shorthand parsing, project
 * resolution, daily-note rendering, and bullet insertion.
 */

// Pull the `shorthand:` value(s) out of a note's YAML frontmatter. Handles a
// scalar, a flow list (`[a, b]`), and a block list (`- a` lines). Returns [] if
// there's no frontmatter or the field is absent/empty. Deliberately tiny — the
// vault has no YAML dep installed, and we only need this one field.
function parseShorthands(content) {
  const lines = content.split("\n");
  if (lines[0] !== "---") return [];
  let fmEnd = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") { fmEnd = i; break; }
  }
  if (fmEnd < 0) return [];

  const stripComment = (s) => s.replace(/\s+#.*$/, "").trim();
  const unquote = (s) => s.replace(/^['"]|['"]$/g, "").trim();

  for (let i = 1; i < fmEnd; i++) {
    const m = lines[i].match(/^shorthand:\s*(.*)$/);
    if (!m) continue;
    const inline = stripComment(m[1]);

    if (inline === "") {
      // Block list on following indented `- ` lines.
      const out = [];
      for (let j = i + 1; j < fmEnd; j++) {
        const lm = lines[j].match(/^\s+-\s+(.*)$/);
        if (!lm) break;
        const v = unquote(stripComment(lm[1]));
        if (v) out.push(v);
      }
      return out;
    }

    if (inline.startsWith("[")) {
      // Flow list.
      return inline.replace(/^\[|\]$/g, "")
        .split(",")
        .map((s) => unquote(s.trim()))
        .filter(Boolean);
    }

    // Scalar.
    const v = unquote(inline);
    return v ? [v] : [];
  }
  return [];
}

// Resolve a `--project` query against scanned work items.
//   items: [{ basename, path, shorthands: string[] }]
//   query: a project basename or an exact shorthand string
// Match is case-insensitive on basename and exact on shorthand. Returns:
//   { item, shorthand }                     — unique resolution
//   { error: "ambiguous", candidates }       — >1 file matched
//   { error: "no-shorthand", item }          — matched a file with no shorthand
//   { error: "none", candidates }            — nothing matched (candidates = all)
function resolveProject(items, query) {
  const q = query.trim();
  const qLower = q.toLowerCase();

  // Exact shorthand match first — most specific, and tells us which shorthand
  // to stamp when a file carries several.
  const byShorthand = items
    .map((it) => ({ it, sh: it.shorthands.find((s) => s === q) }))
    .filter((x) => x.sh);
  if (byShorthand.length === 1) {
    return { item: byShorthand[0].it, shorthand: byShorthand[0].sh };
  }
  if (byShorthand.length > 1) {
    return { error: "ambiguous", candidates: byShorthand.map((x) => x.it) };
  }

  const byName = items.filter((it) => it.basename.toLowerCase() === qLower);
  if (byName.length === 1) {
    const it = byName[0];
    if (it.shorthands.length === 0) return { error: "no-shorthand", item: it };
    return { item: it, shorthand: it.shorthands[0] };
  }
  if (byName.length > 1) {
    return { error: "ambiguous", candidates: byName };
  }

  return { error: "none", candidates: items };
}

// Render a missing daily note from the Templater daily-note template by
// substituting the two tags it uses. Faithful to the in-Obsidian creation path
// (title = the YYYY-MM-DD basename, weekday = full day name) without needing
// Templater. Other content (e.g. the `![[Current Focus]]` transclusion) is
// carried through verbatim, so the note keeps the same shape downstream tooling
// expects.
function renderDailyFromTemplate(templateText, date, weekday) {
  return templateText
    .replace(/<%\s*tp\.file\.title\s*%>/g, date)
    .replace(/<%\s*tp\.date\.now\(["']dddd["']\)\s*%>/g, weekday);
}

// Block ids already present in the note (trailing `^id` on any line).
function existingBlockIds(content) {
  const ids = new Set();
  for (const m of content.matchAll(/\^([a-zA-Z0-9-]+)\s*$/gm)) ids.add(m[1]);
  return ids;
}

// A 6-char base36 id not already in `existing`. `gen` yields candidate ids
// (injectable for tests); defaults to the same generator the Templater LOG flow
// uses (`Math.random().toString(36).slice(2, 8)`).
function genBlockId(existing, gen) {
  const make = gen || (() => Math.random().toString(36).slice(2, 8));
  let id = make();
  let guard = 0;
  while (existing.has(id) && guard++ < 100) id = make();
  return id;
}

// Append a logged bullet under today's section in a daily note. Returns the new
// content. The new bullet lands as the last *real* bullet, keeping any trailing
// empty `- ` placeholder beneath it (so the user still has a fresh bullet to
// type into).
//
// Locating the bullet area: the daily H1 carries a weekday suffix
// (`# 2026-06-23 (Tuesday)`), so an exact heading-text match misses it. We find
// the H1 by date prefix, then the `---` divider that follows it; the area is
// everything after that divider. Falls back to the last `---` in the file, then
// to EOF — mirroring manage-block-log's divider-based fallback.
function appendBullet(content, date, shorthand, body, blockId) {
  const lines = content.split("\n");
  const newBullet = `- [${shorthand}] ${body} ^${blockId}`;

  const h1Idx = lines.findIndex((l) =>
    new RegExp(`^#{1,6}\\s+${date}\\b`).test(l));

  let areaStart;
  if (h1Idx >= 0) {
    let div = -1;
    for (let i = h1Idx + 1; i < lines.length; i++) {
      if (lines[i].trim() === "---") { div = i; break; }
      if (/^#{1,6}\s/.test(lines[i])) break; // another heading first → no divider
    }
    areaStart = (div >= 0 ? div : h1Idx) + 1;
  } else {
    let lastDiv = -1;
    for (let i = 0; i < lines.length; i++) if (lines[i].trim() === "---") lastDiv = i;
    areaStart = lastDiv + 1; // -1 → 0 when no divider at all
  }

  // Insert after the last non-blank line in the area, but before a trailing
  // empty placeholder bullet (`- ` / `-`).
  let insertAt = lines.length;
  while (insertAt > areaStart && lines[insertAt - 1].trim() === "") insertAt--;
  if (insertAt > areaStart && /^\s*-\s*$/.test(lines[insertAt - 1])) insertAt--;

  lines.splice(insertAt, 0, newBullet);
  return lines.join("\n");
}

module.exports = {
  parseShorthands,
  resolveProject,
  renderDailyFromTemplate,
  existingBlockIds,
  genBlockId,
  appendBullet,
};
