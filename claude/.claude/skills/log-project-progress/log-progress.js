#!/usr/bin/env node
"use strict";

/*
 * log-progress — headless equivalent of the vault's `manage-block-log` LOG
 * flow. Appends a `- [<shorthand>] <body> ^<id>` bullet to today's daily note
 * and transcludes it into the matched project's `## Logs` section, byte-for-byte
 * the same as the Templater hotkey (it reuses templates/_scripts/log-core.js).
 *
 * Usage:
 *   node log-progress.js --project "<basename|shorthand>" --body "<text>" \
 *        [--date YYYY-MM-DD] [--vault <path>] [--json]
 *
 * Exit codes: 0 ok; 1 usage/error (project unresolved, missing shorthand,
 * missing daily template, etc.). On error it prints what's wrong and, when
 * useful, the candidate project list — so the caller (Claude) can ask the user
 * to disambiguate rather than guessing.
 *
 * The pure logic lives in lib.js (tested by lib.test.js); this file is the I/O
 * shell — arg parsing, the clock, the vault scan, and file reads/writes.
 */

const fs = require("fs");
const os = require("os");
const path = require("path");

const lib = require("./lib.js");

const DEFAULT_VAULT = path.join(os.homedir(), "obsidian/engineering");
const DAILY_FOLDER = "daily-notes";
const DAILY_TEMPLATE = "templates/daily-note.md";
const LOG_CORE_REL = "templates/_scripts/log-core.js";
const WORK_DIR = "datavant/work"; // proxy for "loggable work item" when no shorthand yet
const SKIP_DIRS = new Set([".git", ".trash", ".obsidian", "node_modules", "templates", "tests", "Tags"]);
const LOGS_SECTION = "Logs";

function parseArgs(argv) {
  const out = { json: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--json") { out.json = true; continue; }
    const m = a.match(/^--([a-z]+)$/);
    if (m) { out[m[1]] = argv[++i]; continue; }
  }
  return out;
}

function fail(msg, extra) {
  console.error(`log-progress: ${msg}`);
  if (extra) console.error(extra);
  process.exit(1);
}

function todayLocal() {
  const d = new Date();
  const p2 = (n) => String(n).padStart(2, "0");
  const date = `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}`;
  const weekday = d.toLocaleDateString("en-US", { weekday: "long" });
  return { date, weekday };
}

function weekdayFor(date) {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-US", { weekday: "long" });
}

// Walk the vault for loggable work items: any note with a `shorthand`, plus
// notes under datavant/work (so we can give a helpful "set a shorthand" error
// for a work item that doesn't have one yet). Skips system dirs and templates.
function scanWorkItems(vault) {
  const items = [];
  const walk = (dir, rel) => {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); }
    catch { return; }
    for (const e of entries) {
      if (e.name.startsWith(".")) continue;
      const abs = path.join(dir, e.name);
      const relPath = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) {
        if (SKIP_DIRS.has(e.name)) continue;
        walk(abs, relPath);
      } else if (e.isFile() && e.name.endsWith(".md") && !e.name.startsWith("_template")) {
        let content;
        try { content = fs.readFileSync(abs, "utf8"); } catch { continue; }
        const shorthands = lib.parseShorthands(content);
        const underWork = relPath.startsWith(`${WORK_DIR}/`);
        if (shorthands.length > 0 || underWork) {
          items.push({ basename: e.name.replace(/\.md$/, ""), path: relPath, shorthands });
        }
      }
    }
  };
  walk(vault, "");
  return items;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const vault = args.vault || DEFAULT_VAULT;

  if (!args.project) fail('missing --project "<basename|shorthand>"');
  if (!args.body || !args.body.trim()) fail('missing --body "<text>"');

  let date, weekday;
  if (args.date) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(args.date)) fail(`--date must be YYYY-MM-DD, got "${args.date}"`);
    date = args.date;
    weekday = weekdayFor(date);
  } else {
    ({ date, weekday } = todayLocal());
  }

  const logCorePath = path.join(vault, LOG_CORE_REL);
  if (!fs.existsSync(logCorePath)) fail(`log-core.js not found at ${logCorePath}`);
  const { placeLogEntry } = require(logCorePath)();

  // ── resolve the project ──
  const items = scanWorkItems(vault);
  const r = lib.resolveProject(items, args.project);
  if (r.error === "none") {
    fail(`no work item matched "${args.project}".`,
      `Known shorthands:\n` + items.flatMap(i => i.shorthands.map(s => `  [${s}] → ${i.basename}`)).join("\n"));
  }
  if (r.error === "ambiguous") {
    fail(`"${args.project}" matched ${r.candidates.length} items — be more specific:`,
      r.candidates.map(c => `  ${c.basename} (${c.path})`).join("\n"));
  }
  if (r.error === "no-shorthand") {
    fail(`"${r.item.basename}" has no shorthand set. Add one to its frontmatter, e.g.\n  shorthand:\n    - project/<name>`);
  }
  const { item, shorthand } = r;
  const projAbs = path.join(vault, item.path);

  // ── resolve or create today's daily note ──
  const dailyAbs = path.join(vault, DAILY_FOLDER, `${date}.md`);
  let created = false;
  if (!fs.existsSync(dailyAbs)) {
    const tplAbs = path.join(vault, DAILY_TEMPLATE);
    if (!fs.existsSync(tplAbs)) fail(`daily note ${date} missing and no template at ${tplAbs}`);
    const rendered = lib.renderDailyFromTemplate(fs.readFileSync(tplAbs, "utf8"), date, weekday);
    fs.writeFileSync(dailyAbs, rendered);
    created = true;
  }

  // ── append the bullet ──
  const dailyContent = fs.readFileSync(dailyAbs, "utf8");
  const blockId = lib.genBlockId(lib.existingBlockIds(dailyContent));
  const body = args.body.trim();
  const newDaily = lib.appendBullet(dailyContent, date, shorthand, body, blockId);
  fs.writeFileSync(dailyAbs, newDaily);

  // ── transclude into the project's Logs (reuses the vault's own logic) ──
  const projLines = fs.readFileSync(projAbs, "utf8").split("\n");
  placeLogEntry(projLines, {
    section: LOGS_SECTION,
    date,
    entry: `![[${date}#^${blockId}]]`,
  });
  fs.writeFileSync(projAbs, projLines.join("\n"));

  const result = {
    ok: true,
    project: item.basename,
    shorthand,
    date,
    blockId,
    bullet: `- [${shorthand}] ${body} ^${blockId}`,
    dailyNote: path.join(DAILY_FOLDER, `${date}.md`),
    dailyCreated: created,
    projectPath: item.path,
  };

  if (args.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(`logged → ${item.basename}`);
    console.log(`  daily: ${result.dailyNote}${created ? " (created)" : ""}`);
    console.log(`  ${result.bullet}`);
    console.log(`  ![[${date}#^${blockId}]] → ${item.path} › ## ${LOGS_SECTION}`);
  }
}

if (require.main === module) main();

module.exports = { parseArgs, scanWorkItems, weekdayFor };
