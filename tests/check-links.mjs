#!/usr/bin/env node
// Crawls one or all 12 modules' lecture pages and checks the HTTP status
// of every outbound link in the article body, within and across domains.
// Unlike bombadil's own noHttpErrorCodes property, this checks EVERY link
// directly rather than only the ones a fuzz run happens to click.
//
// Deliberately does NOT check #fragment anchor targets, even though a
// broken one is a real bug: this site injects heading/section ids via
// client-side JS (confirmed directly — the ids don't exist anywhere in
// the raw HTML), so a static fetch can never verify them correctly. That
// produced a large, confident-looking, wrong "137 dead anchors" result
// earlier (see suggestions.md). Anchor validity is checked live instead,
// in test-links-module.ts's `noDeadAnchors` property, against the real
// post-JS DOM. Pure same-page anchor links (bare `#fragment`, no distinct
// URL — nothing to fetch, and the same anchor-validity caveat applies)
// are excluded from the crawl entirely for the same reason.
//
// Usage: node check-links.mjs [module] [--json | --md]
//   node check-links.mjs        (all 12 modules)
//   node check-links.mjs M07
//   node check-links.mjs 7
//   node check-links.mjs 7 --json           (one JSON line per link, incl.
//                                             HTTP status, not just problems)
//   node check-links.mjs 7 --md > report.md (readable Markdown report)

import { SITE_ROOT, normalizeModuleLabel, fetchModuleLectureLists, extractArticleLinks } from "./site-utils.mjs";

const CONCURRENCY = 8;

async function withConcurrencyLimit(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const i = next++;
      results[i] = await fn(items[i]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

// One entry per distinct URL (fragment stripped), so linking to the same
// page's #different-fragments from elsewhere doesn't re-fetch it.
const pageCache = new Map();

// A fetch() throwing (as opposed to resolving with a 4xx/5xx status) means
// no response was received at all — could be a genuinely dead host, or
// could be transient. Confirmed both kinds happen on this exact link set:
// one "fetch failed" turned out to be a TLS/cipher quirk specific to
// Node's fetch client (curl reached the same host fine every time), and
// a separate one succeeded on a plain retry moments later. So a fetch
// failure gets one retry, after a short delay, before being reported.
async function fetchOnce(urlNoFragment) {
  try {
    const res = await fetch(urlNoFragment, { redirect: "follow" });
    return { status: res.status, error: null };
  } catch (err) {
    return { status: null, error: String(err) };
  }
}

async function fetchPage(urlNoFragment) {
  if (pageCache.has(urlNoFragment)) return pageCache.get(urlNoFragment);
  const result = await (async () => {
    const first = await fetchOnce(urlNoFragment);
    if (!first.error) return first;
    await new Promise((resolve) => setTimeout(resolve, 1000));
    return fetchOnce(urlNoFragment);
  })();
  pageCache.set(urlNoFragment, result);
  return result;
}

async function checkLink(link) {
  let absolute;
  try {
    absolute = new URL(link.href, link.pageUrl);
  } catch {
    return { ...link, problems: [`unparseable href: ${JSON.stringify(link.href)}`] };
  }

  const urlNoFragment = absolute.origin + absolute.pathname + absolute.search;
  const { status, error } = await fetchPage(urlNoFragment);

  const problems = [];
  if (error) problems.push(`fetch error: ${error}`);
  else if (status < 200 || status >= 400) problems.push(`HTTP ${status}`);

  return { ...link, url: absolute.toString(), status, problems };
}

const rawArgs = process.argv.slice(2);
const jsonMode = rawArgs.includes("--json");
const markdownMode = rawArgs.includes("--md");
const [moduleArg] = rawArgs.filter((a) => a !== "--json" && a !== "--md");

const moduleLectureLists = await fetchModuleLectureLists();

const modulesToCheck = moduleArg
  ? (() => {
      const label = normalizeModuleLabel(moduleArg);
      if (!moduleLectureLists.has(label)) {
        const known = [...moduleLectureLists.keys()].sort().join(", ");
        console.error(`Unknown module ${label}. Known modules: ${known}`);
        process.exit(1);
      }
      return [label];
    })()
  : [...moduleLectureLists.keys()].sort();

const allResults = [];

for (const moduleLabel of modulesToCheck) {
  const pages = moduleLectureLists.get(moduleLabel);
  for (const page of pages) {
    const pageUrl = `${SITE_ROOT}/${page}`;
    const res = await fetch(pageUrl);
    const html = await res.text();
    // Bare "#fragment" hrefs (no distinct URL) point at the same page —
    // nothing to fetch, and validating the fragment itself isn't this
    // tool's job (see the file header comment).
    const links = extractArticleLinks(html)
      .filter((l) => !l.href.startsWith("#"))
      .map((l) => ({ ...l, module: moduleLabel, page, pageUrl }));

    const results = await withConcurrencyLimit(links, CONCURRENCY, checkLink);
    allResults.push(...results);
  }
  console.error(`Checked ${moduleLabel} (${pages.length} pages)`);
}

// Escapes characters that would otherwise break a Markdown table cell
// (pipes end the cell early; newlines — from multi-line link text —
// would split the row across lines).
function mdCell(text) {
  return String(text).replace(/\|/g, "\\|").replace(/\r?\n/g, " ");
}

function statusLabel(r) {
  if (r.status != null) return String(r.status);
  return r.problems[0]?.startsWith("fetch error") ? "ERROR" : "?";
}

function printMarkdownReport() {
  const problemLinks = allResults.filter((r) => r.problems.length);
  // 403s get their own section: a 403 that persists with a full browser
  // User-Agent (verified separately via curl, see suggestions.md) rules
  // out simple header-sniffing as the mechanism, but does NOT by itself
  // mean the link is dead for a real visitor — some of this batch turned
  // out to be bot-detection noise (Bloomberg) and some turned out to be
  // genuinely broken (oxcaml.org). Every 403 needs a manual check either
  // way, so they're kept separate from statuses (404, 410, fetch errors)
  // that are unambiguous.
  const forbiddenLinks = problemLinks.filter((r) => r.status === 403);
  const otherProblemLinks = problemLinks.filter((r) => r.status !== 403);
  const byStatus = new Map();
  for (const r of allResults) {
    const key = statusLabel(r);
    byStatus.set(key, (byStatus.get(key) ?? 0) + 1);
  }

  console.log(`# Link check report`);
  console.log(`\n- Modules checked: ${modulesToCheck.join(", ")}`);
  console.log(`- Total links checked: ${allResults.length}`);
  console.log(`- Problems found: ${problemLinks.length} (${forbiddenLinks.length} need manual check, ${otherProblemLinks.length} other)`);

  console.log(`\n## Status code summary`);
  console.log(`\n| Status | Count |`);
  console.log(`| --- | --- |`);
  for (const [status, count] of [...byStatus.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    console.log(`| ${status} | ${count} |`);
  }

  console.log(`\n## Problems: needs manual check (${forbiddenLinks.length})`);
  console.log(
    `\nAll HTTP 403. A 403 that persists even with a full browser User-Agent` +
      ` (see suggestions.md) rules out simple header-sniffing, but does not` +
      ` by itself mean the link is broken for a real visitor — this exact` +
      ` batch has included both bot-detection noise (Bloomberg, confirmed` +
      ` fine) and a genuinely dead link (oxcaml.org, confirmed broken).` +
      ` Open each of these in a real browser before treating it as a bug` +
      ` or dismissing it as noise.`,
  );
  if (forbiddenLinks.length === 0) {
    console.log(`\nNone found.`);
  } else {
    console.log(`\n| Module | Page | Link text | URL |`);
    console.log(`| --- | --- | --- | --- |`);
    for (const p of forbiddenLinks) {
      const url = p.url ?? p.href;
      console.log(`| ${p.module} | ${mdCell(p.page)} | ${mdCell(p.text)} | [${mdCell(url)}](${url}) |`);
    }
  }

  console.log(`\n## Other problems (${otherProblemLinks.length})`);
  if (otherProblemLinks.length === 0) {
    console.log(`\nNone found.`);
  } else {
    console.log(`\n| Module | Page | Link text | URL | Problem |`);
    console.log(`| --- | --- | --- | --- | --- |`);
    for (const p of otherProblemLinks) {
      const url = p.url ?? p.href;
      console.log(
        `| ${p.module} | ${mdCell(p.page)} | ${mdCell(p.text)} | [${mdCell(url)}](${url}) | ${mdCell(p.problems.join("; "))} |`,
      );
    }
  }

  console.log(`\n## All links, by module`);
  for (const moduleLabel of modulesToCheck) {
    const moduleLinks = allResults.filter((r) => r.module === moduleLabel);
    console.log(`\n<details>`);
    console.log(`<summary>${moduleLabel} (${moduleLinks.length} links)</summary>`);
    console.log(`\n| Page | Link text | URL | Status |`);
    console.log(`| --- | --- | --- | --- |`);
    for (const r of moduleLinks) {
      const url = r.url ?? r.href;
      console.log(`| ${mdCell(r.page)} | ${mdCell(r.text)} | [${mdCell(url)}](${url}) | ${statusLabel(r)} |`);
    }
    console.log(`\n</details>`);
  }
}

if (jsonMode) {
  // One line per link checked — every link, not just the problem ones,
  // so HTTP status is reported for the full set.
  for (const r of allResults) {
    console.log(
      JSON.stringify({
        module: r.module,
        page: r.page,
        text: r.text,
        href: r.href,
        url: r.url ?? null,
        status: r.status ?? null,
        problems: r.problems,
      }),
    );
  }
} else if (markdownMode) {
  printMarkdownReport();
} else {
  const problemLinks = allResults.filter((r) => r.problems.length);
  console.log(`\nChecked ${allResults.length} links across ${modulesToCheck.length} module(s).`);
  console.log(`Found ${problemLinks.length} problem(s):`);
  for (const p of problemLinks) {
    console.log(`\n[${p.module} ${p.page}] "${p.text}"`);
    console.log(`  -> ${p.url ?? p.href}`);
    for (const problem of p.problems) console.log(`  ${problem}`);
  }
}
