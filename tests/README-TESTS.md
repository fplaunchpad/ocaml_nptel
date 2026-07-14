# Test scripts

## check-links.mjs

Crawls the [fplaunchpad.org OCaml course
site](https://fplaunchpad.org/ocaml_nptel/index.html)
(all 12 modules) and checks the HTTP status of every outbound link in each
lecture page's article body — within the site and across other domains.
This script checks every link on every page directly via HTTP, exhaustively.

## What it does

- Discovers all 12 modules and their lecture pages from the site's own
  sidebar navigation (no hardcoded page list).
- Fetches every lecture page and extracts every `<a href>` in the article
  body.
- Skips bare `#fragment` links (same-page anchors — nothing to fetch, and
  anchor validity can't be checked from raw HTML anyway, since this site
  injects heading ids via client-side JS).
- Checks each distinct URL once (fragment stripped, so linking to the same
  page from multiple places doesn't re-fetch it), with one retry on a
  network-level fetch failure.
- Reports status per link, grouped by module/page.

**Note on HTTP 403 results:** a 403 that persists even with a full browser
User-Agent doesn't necessarily mean the link is broken for a real visitor —
some sites block automated clients while working fine in an actual browser.
The Markdown report (see below) separates 403s into their own section with
a "needs manual check" note for this reason.

## Requirements

- Node.js 18 or later (needs the built-in global `fetch`; no npm
  dependencies to install).

## Usage

```sh
# All 12 modules, plain text output
node check-links.mjs

# Just one module (accepts "M07", "07", or "7")
node check-links.mjs M07

# One JSON line per link checked (includes HTTP status, not just problems)
node check-links.mjs M07 --json

# Full Markdown report, redirected to a file
node check-links.mjs --md > link-check-report.md
```

The Markdown report (`--md`) includes:

- A status-code summary table.
- A "needs manual check" section (all HTTP 403s, with the caveat above).
- An "other problems" section (404s, 410s, fetch errors — unambiguous).
- A full per-module listing of every link checked, in collapsible
  `<details>` blocks.

A full run across all 12 modules takes roughly a minute or two (concurrency
is capped at 8 simultaneous requests to avoid tripping rate limits).

