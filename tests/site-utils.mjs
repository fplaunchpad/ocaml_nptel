// Shared helpers for scripts that inspect fplaunchpad.org's course pages
// directly over HTTP (check-links.mjs, to be added) — kept in one
// place so the sidebar-parsing regex only needs fixing once if the site's
// markup ever changes.

export const SITE_ROOT = "https://fplaunchpad.org/ocaml_nptel";

// Any real lecture page works here — the sidebar nav listing all 12
// modules and their lectures is site-wide, not specific to this page.
const SIDEBAR_ANCHOR_PAGE = "M01-L01-course-intro.html";

export function normalizeModuleLabel(input) {
  const digits = input.replace(/\D/g, "");
  if (!digits) throw new Error(`Not a module number: ${input}`);
  return `M${digits.padStart(2, "0")}`;
}

// Discovers every module's lecture pages from the site's own sidebar nav,
// rather than hardcoding a page list per module (lecture counts vary,
// from 4 up to 10, across the 12 modules).
export async function fetchModuleLectureLists() {
  const res = await fetch(`${SITE_ROOT}/${SIDEBAR_ANCHOR_PAGE}`);
  if (!res.ok) throw new Error(`Failed to fetch ${SIDEBAR_ANCHOR_PAGE}: ${res.status}`);
  const html = await res.text();

  const modules = new Map();
  for (const [, block] of html.matchAll(/<details class="sidebar-week"[^>]*>([\s\S]*?)<\/details>/g)) {
    const week = block.match(/<span class="week-no">(M\d\d)<\/span>/)?.[1];
    if (!week) continue;
    const pages = [...block.matchAll(/<a href="([^"]+\.html)"/g)].map(([, href]) => href);
    modules.set(week, pages);
  }
  return modules;
}

export function decodeEntities(text) {
  // &amp; must decode last, or a literal "&amp;lt;" (a real ampersand
  // followed by the text "lt;") would wrongly collapse to "<".
  return text
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&");
}

export function stripTags(html) {
  return decodeEntities(html.replace(/<[^>]+>/g, "")).trim();
}

// Every <a href> inside a lecture page's article body, with entities
// decoded in both the visible text and the href itself. Scans the whole
// article, not just <p> tags — a "Further reading" <h2>/<ul> section at
// the end of a lecture is a real, common place for links to live, and
// restricting to paragraphs silently excludes it (confirmed: two broken
// links at the end of M07-L04 live in exactly such a list and were
// invisible to both check-coverage.mjs's baseline and the fuzzer's own
// chapterLinks selector — see suggestions.md).
export function extractArticleLinks(html) {
  const article = html.match(/<article class="chapter"[\s\S]*?<\/article>/)?.[0];
  if (!article) return [];
  const links = [];
  for (const [, hrefRaw, inner] of article.matchAll(/<a\s[^>]*href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/g)) {
    links.push({ text: stripTags(inner), href: decodeEntities(hrefRaw) });
  }
  return links;
}
