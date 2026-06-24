"use strict";

// Pure-core tests for the log-project-progress CLI. Everything here is
// dependency-free and headless; the I/O shell (vault scan, file read/write)
// lives in log-progress.js and isn't exercised here.
//
// Run with:  node --test lib.test.js

const { test } = require("node:test");
const assert = require("node:assert/strict");

const {
  parseShorthands,
  resolveProject,
  renderDailyFromTemplate,
  existingBlockIds,
  genBlockId,
  appendBullet,
} = require("./lib.js");

// ─── parseShorthands ─────────────────────────────────────────────────────────

test("parseShorthands: YAML block list", () => {
  const content = ["---", "tags:", "  - Datavant", "shorthand:", "  - project/digital routing work", "  - project/darcs", "status: active", "---", "body"].join("\n");
  assert.deepEqual(parseShorthands(content), ["project/digital routing work", "project/darcs"]);
});

test("parseShorthands: scalar value", () => {
  const content = "---\nshorthand: project/foo\n---\n";
  assert.deepEqual(parseShorthands(content), ["project/foo"]);
});

test("parseShorthands: flow list", () => {
  const content = "---\nshorthand: [project/foo, project/bar]\n---\n";
  assert.deepEqual(parseShorthands(content), ["project/foo", "project/bar"]);
});

test("parseShorthands: empty field → []", () => {
  const content = "---\nshorthand:\nstatus: active\n---\n";
  assert.deepEqual(parseShorthands(content), []);
});

test("parseShorthands: trailing comment stripped, quotes stripped", () => {
  const content = "---\nshorthand: \"project/foo\" # alias\n---\n";
  assert.deepEqual(parseShorthands(content), ["project/foo"]);
});

test("parseShorthands: no frontmatter → []", () => {
  assert.deepEqual(parseShorthands("just a body\n"), []);
});

// ─── resolveProject ──────────────────────────────────────────────────────────

const ITEMS = [
  { basename: "DARCS Split", path: "datavant/work/projects/DARCS Split.md", shorthands: ["project/digital routing work"] },
  { basename: "RCS Caching Project", path: "p/RCS Caching Project.md", shorthands: ["project/rcs caching"] },
  { basename: "No Shorthand Project", path: "p/No Shorthand Project.md", shorthands: [] },
];

test("resolveProject: matches by basename (case-insensitive), uses first shorthand", () => {
  const r = resolveProject(ITEMS, "darcs split");
  assert.equal(r.item.basename, "DARCS Split");
  assert.equal(r.shorthand, "project/digital routing work");
});

test("resolveProject: matches by exact shorthand, uses that shorthand", () => {
  const r = resolveProject(ITEMS, "project/rcs caching");
  assert.equal(r.item.basename, "RCS Caching Project");
  assert.equal(r.shorthand, "project/rcs caching");
});

test("resolveProject: no match → error none with candidate list", () => {
  const r = resolveProject(ITEMS, "nonexistent");
  assert.equal(r.error, "none");
  assert.ok(Array.isArray(r.candidates));
});

test("resolveProject: matched file without a shorthand → error no-shorthand", () => {
  const r = resolveProject(ITEMS, "No Shorthand Project");
  assert.equal(r.error, "no-shorthand");
  assert.equal(r.item.basename, "No Shorthand Project");
});

test("resolveProject: ambiguous basename match → error ambiguous", () => {
  const items = [
    { basename: "Dup", path: "a/Dup.md", shorthands: ["project/a"] },
    { basename: "Dup", path: "b/Dup.md", shorthands: ["project/b"] },
  ];
  const r = resolveProject(items, "Dup");
  assert.equal(r.error, "ambiguous");
  assert.equal(r.candidates.length, 2);
});

// ─── renderDailyFromTemplate ─────────────────────────────────────────────────

test("renderDailyFromTemplate: substitutes title + weekday, leaves the rest", () => {
  const tpl = '![[Current Focus]]\n\n---\n\n# <% tp.file.title %> (<% tp.date.now("dddd") %>)\n---\n- \n';
  const out = renderDailyFromTemplate(tpl, "2026-06-23", "Tuesday");
  assert.match(out, /# 2026-06-23 \(Tuesday\)/);
  assert.match(out, /^!\[\[Current Focus\]\]/);
  assert.doesNotMatch(out, /<%/);
});

// ─── block ids ───────────────────────────────────────────────────────────────

test("existingBlockIds: collects trailing ^ids", () => {
  const content = "- a ^abc123\n- b\n- c ^def456\n";
  assert.deepEqual([...existingBlockIds(content)].sort(), ["abc123", "def456"]);
});

test("genBlockId: avoids collisions via the injected generator", () => {
  const existing = new Set(["aaaaaa"]);
  const seq = ["aaaaaa", "bbbbbb"]; // first collides, second is free
  let i = 0;
  const id = genBlockId(existing, () => seq[i++]);
  assert.equal(id, "bbbbbb");
});

test("genBlockId: default rng yields a 6-char base36 id", () => {
  const id = genBlockId(new Set());
  assert.match(id, /^[a-z0-9]{6}$/);
});

// ─── appendBullet ────────────────────────────────────────────────────────────

const DAILY = [
  "![[Current Focus]]",
  "",
  "---",
  "",
  "# 2026-06-23 (Tuesday)",
  "---",
  "- [project/x] earlier note ^aaa111",
  "- ",
].join("\n");

test("appendBullet: inserts before the trailing empty placeholder bullet", () => {
  const out = appendBullet(DAILY, "2026-06-23", "project/digital routing work", "found the bug", "zzz999");
  const lines = out.split("\n");
  const idx = lines.indexOf("- [project/digital routing work] found the bug ^zzz999");
  assert.ok(idx > 0, "new bullet present");
  // placeholder "- " stays last
  assert.equal(lines[idx + 1], "- ");
  // earlier bullet still above
  assert.ok(lines.indexOf("- [project/x] earlier note ^aaa111") < idx);
});

test("appendBullet: freshly rendered note (only placeholder) gets the bullet above it", () => {
  const fresh = "![[Current Focus]]\n\n---\n\n# 2026-06-23 (Tuesday)\n---\n- \n";
  const out = appendBullet(fresh, "2026-06-23", "project/foo", "kickoff", "kkk000");
  const lines = out.split("\n");
  const idx = lines.indexOf("- [project/foo] kickoff ^kkk000");
  assert.ok(idx > 0);
  assert.equal(lines[idx + 1], "- ");
});

test("appendBullet: no placeholder → appends after the last bullet", () => {
  const note = "![[Current Focus]]\n\n---\n\n# 2026-06-23 (Tuesday)\n---\n- [project/x] a ^aaa111\n";
  const out = appendBullet(note, "2026-06-23", "project/y", "b", "bbb222");
  const lines = out.split("\n").filter(l => l !== "");
  assert.equal(lines[lines.length - 1], "- [project/y] b ^bbb222");
});

test("appendBullet: H1 located even though it carries a weekday suffix", () => {
  // Regression: findHeading(date) would miss "# 2026-06-23 (Tuesday)"; the
  // area must still be found via the post-H1 divider.
  const out = appendBullet(DAILY, "2026-06-23", "project/z", "note", "ccc333");
  assert.match(out, /- \[project\/z\] note \^ccc333/);
  // must not land above the H1
  const lines = out.split("\n");
  assert.ok(lines.indexOf("- [project/z] note ^ccc333") > lines.indexOf("# 2026-06-23 (Tuesday)"));
});
