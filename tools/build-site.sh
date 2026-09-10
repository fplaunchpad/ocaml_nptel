#!/usr/bin/env bash
# Build every lectures/**/*.md into _site/<rel>/<base>.html.
# Usage: tools/build-site.sh [src.md ...]
#   With no args, walks lectures/ recursively.
#
# Env vars:
#   ASSET_ROOT   prefix used in front of /assets/ paths. Empty (default)
#                serves assets at the site root. For GitHub Pages on a
#                project repo, set to "/<repo>".
#   COPY_ASSETS  if "1", also copy assets/ into _site/assets/ so the
#                output is self-contained and deployable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$REPO_ROOT/_build/default/tools/nptel-build/bin/main.exe"
ASSET_ROOT="${ASSET_ROOT:-}"
COPY_ASSETS="${COPY_ASSETS:-0}"

# Stamp every rendered lecture with the source commit so quiz
# analytics can correlate responses with a specific version of the
# content. GitHub Actions sets GITHUB_SHA; locally we read from git.
if [ -z "${NPTEL_COMMIT_SHA:-}" ]; then
  if [ -n "${GITHUB_SHA:-}" ]; then
    NPTEL_COMMIT_SHA="$GITHUB_SHA"
  else
    NPTEL_COMMIT_SHA="$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null || echo unknown)"
  fi
fi
export NPTEL_COMMIT_SHA

# The radio-button UI requires exactly one correct answer per MCQ.
python3 "$SCRIPT_DIR/audit-mcq-length.py"

(cd "$REPO_ROOT" && opam exec -- dune build tools/nptel-build/bin/main.exe >/dev/null)

if [ $# -eq 0 ]; then
  # Lecture files follow the M<nn>-L<nn>-slug.md convention. Other .md
  # files under lectures/ (e.g. drafts, READMEs) are skipped.
  mapfile -d '' files < <(find "$REPO_ROOT/lectures" -name 'M*-L*-*.md' -print0 2>/dev/null)
else
  files=("$@")
fi

for src in "${files[@]}"; do
  [ -f "$src" ] || continue
  rel="${src#$REPO_ROOT/}"
  dst="$REPO_ROOT/_site/${rel%.md}.html"
  dst="${dst/lectures\//}"
  mkdir -p "$(dirname "$dst")"
  "$BIN" "$src" "$dst" "$ASSET_ROOT"
  printf 'built %s\n' "${dst#$REPO_ROOT/}"
done

# Always keep the smoke test fresh.
if [ -f "$REPO_ROOT/tools/nptel-build/test/smoke.md" ]; then
  mkdir -p "$REPO_ROOT/_site/test"
  "$BIN" "$REPO_ROOT/tools/nptel-build/test/smoke.md" \
    "$REPO_ROOT/_site/test/smoke.html" "$ASSET_ROOT"
fi

# For deploy: vendor the static assets under _site/ so the output is
# self-contained. For local preview, the http.server already serves
# /assets/ from the repo root, so we skip this.
if [ "$COPY_ASSETS" = "1" ]; then
  rm -rf "$REPO_ROOT/_site/assets"
  cp -r "$REPO_ROOT/assets" "$REPO_ROOT/_site/assets"
fi

# Emit _site/search-index.json for the landing page's search box:
# per lecture the title, concepts, keywords, activity question, and
# every h2-h4 heading with its anchor. The anchor slugs replicate
# emit.ml's client-side slugify() (lowercase-dashed, collision
# suffixes in document order) so search hits deep-link to sections.
emit_search_index() {
  python3 - "$REPO_ROOT" <<'PYEOF'
import json, os, re, sys

root = sys.argv[1]
lec_dir = os.path.join(root, 'lectures')

def slugify(s):
    s = s.lower()
    s = re.sub(r'[^a-z0-9\s-]', '', s)
    s = re.sub(r'\s+', '-', s)
    s = re.sub(r'-+', '-', s)
    s = s.strip('-')
    return s[:80]

def clean_heading(t):
    # approximate the rendered textContent: drop inline-code
    # backticks and emphasis markers, keep the words
    t = t.replace('`', '')
    t = re.sub(r'\*+', '', t)
    return t.strip()

index = []
for name in sorted(os.listdir(lec_dir)):
    m = re.match(r'(M\d\d)-(L\d\d)-.*\.md$', name)
    if not m:
        continue
    path = os.path.join(lec_dir, name)
    text = open(path, encoding='utf-8').read()
    fm = {}
    body = text
    if text.startswith('---'):
        end = text.find('\n---', 3)
        if end != -1:
            head = text[3:end]
            body = text[end + 4:]
            for key in ('title', 'activity_question'):
                fm_m = re.search(r'^%s:\s*"?(.*?)"?\s*$' % key, head, re.M)
                if fm_m:
                    fm[key] = fm_m.group(1)
            for key in ('concepts', 'keywords'):
                fm_m = re.search(r'^%s:\s*\[(.*)\]' % key, head, re.M)
                if fm_m:
                    fm[key] = [w.strip() for w in fm_m.group(1).split(',')]
    headings, seen, in_fence = [], {}, False
    for line in body.split('\n'):
        if line.strip().startswith('```'):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        h = re.match(r'(#{2,4})\s+(.*)', line)
        if not h:
            continue
        t = clean_heading(h.group(2))
        a = slugify(t)
        if not a:
            continue
        if a in seen:
            i = 2
            while (a + '-' + str(i)) in seen:
                i += 1
            a = a + '-' + str(i)
        seen[a] = True
        headings.append({'t': t, 'a': a})
    # drop duplicate heading texts (chapter + slide twin): keep the
    # first occurrence, whose anchor is the chapter copy
    seen_t, uniq = set(), []
    for h in headings:
        if h['t'] in seen_t:
            continue
        seen_t.add(h['t'])
        uniq.append(h)
    headings = uniq
    index.append({
        'file': name[:-3],
        'module': m.group(1),
        'lecture': m.group(2),
        'title': clean_heading(fm.get('title', name[:-3])),
        'concepts': fm.get('concepts', []),
        'keywords': fm.get('keywords', []),
        'activity': fm.get('activity_question', ''),
        'headings': headings,
    })

out = os.path.join(root, '_site', 'search-index.json')
with open(out, 'w', encoding='utf-8') as f:
    json.dump(index, f, ensure_ascii=False)
print('built _site/search-index.json (%d lectures)' % len(index))
PYEOF
}
emit_search_index

# Emit a landing page at _site/index.html so the root URL of the
# deployed site (e.g. https://<user>.github.io/<repo>/) shows a real
# page rather than a 404. Groups lectures by module, reads titles
# from each .md file's frontmatter.
emit_index() {
  local out="$REPO_ROOT/_site/index.html"
  {
    cat <<HEAD
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Functional Programming with OCaml — NPTEL</title>
  <link rel="stylesheet" href="${ASSET_ROOT}/assets/css/chapter.css">
  <style>
    .landing { max-width: 760px; margin: 2rem auto; padding: 0 1rem; }
    .landing h1 { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 1.8rem; }
    .landing .module { border-top: 1px solid var(--rule); padding-top: 1rem; margin-top: 1.4rem; }
    .landing .module h2 { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 1.15rem; margin: 0 0 0.4rem; }
    .landing .module-no { color: var(--muted); font-size: 0.78rem; letter-spacing: 0.04em; text-transform: uppercase; }
    .landing ul { list-style: none; padding: 0; margin: 0.5rem 0 0; }
    .landing li { margin: 0.25rem 0; }
    .landing li a { color: var(--accent); text-decoration: none; }
    .landing li a:hover { text-decoration: underline; }
    .landing .lec-no { display: inline-block; min-width: 2.4em; color: var(--muted); font-size: 0.9em; font-family: ui-monospace, monospace; }
    .landing .search-box { margin: 1.4rem 0 0; }
    .landing .search-box input {
      width: 100%; box-sizing: border-box; padding: 0.55rem 0.8rem;
      font-size: 1rem; border: 1px solid var(--rule); border-radius: 6px;
      background: inherit; color: inherit;
    }
    .landing .search-results { list-style: none; padding: 0; margin: 0.5rem 0 0; border: 1px solid var(--rule); border-radius: 6px; max-height: 24rem; overflow-y: auto; }
    .landing .search-results li { margin: 0; padding: 0.4rem 0.8rem; border-top: 1px solid var(--rule); }
    .landing .search-results li:first-child { border-top: none; }
    .landing .search-results a { color: var(--accent); text-decoration: none; }
    .landing .search-results a:hover { text-decoration: underline; }
    .landing .search-results .hit-lec { color: var(--muted); font-size: 0.85em; font-family: ui-monospace, monospace; margin-right: 0.5em; }
    .landing .search-results .no-hits { color: var(--muted); }
  </style>
</head>
<body class="mode-chapter">
  <article class="landing">
    <h1>Functional Programming with OCaml</h1>
    <p>A 12-week NPTEL course. Pick a lecture below, or start at
    <a href="M01-L01-course-intro.html">Module 1, Lecture 1</a>.
    To take the course for credit (assignments, proctored exam,
    certificate), <a
    href="https://onlinecourses.nptel.ac.in/noc26_cs90/preview">sign
    up on the NPTEL portal</a>.</p>
    <div class="search-box">
      <input id="lecture-search" type="search"
        placeholder="Search lectures, sections, concepts&hellip;"
        aria-label="Search course content">
      <ul id="search-results" class="search-results" hidden></ul>
    </div>
    <script>
    (function () {
      var box = document.getElementById('lecture-search');
      var out = document.getElementById('search-results');
      var idx = null, loading = null;
      function load() {
        if (!loading) {
          loading = fetch('search-index.json')
            .then(function (r) { return r.json(); })
            .then(function (j) { idx = j; });
        }
        return loading;
      }
      function esc(s) {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;')
                .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
      }
      function render(hits) {
        if (!hits.length) {
          out.innerHTML = '<li class="no-hits">No matches.</li>';
        } else {
          out.innerHTML = hits.slice(0, 40).map(function (h) {
            return '<li><span class="hit-lec">' + h.lec + '</span>' +
              '<a href="' + esc(h.href) + '">' + esc(h.label) + '</a></li>';
          }).join('');
        }
        out.hidden = false;
      }
      box.addEventListener('input', function () {
        var q = box.value.trim().toLowerCase();
        if (q.length < 2) { out.hidden = true; out.innerHTML = ''; return; }
        load().then(function () {
          var terms = q.split(/\s+/);
          var hits = [];
          idx.forEach(function (lec) {
            if (hits.length > 40) return;
            var base = [lec.title].concat(lec.concepts, lec.keywords,
              [lec.activity]).join(' ').toLowerCase();
            var lecId = lec.module + ' ' + lec.lecture;
            if (terms.every(function (t) { return base.indexOf(t) !== -1; })) {
              hits.push({ lec: lecId, href: lec.file + '.html',
                          label: lec.title });
            }
            lec.headings.forEach(function (h) {
              var ht = h.t.toLowerCase();
              // every term must hit heading or lecture metadata, and
              // at least one must hit the heading itself
              var all = terms.every(function (t) {
                return ht.indexOf(t) !== -1 || base.indexOf(t) !== -1;
              });
              var own = terms.some(function (t) {
                return ht.indexOf(t) !== -1;
              });
              if (all && own) {
                hits.push({ lec: lecId, href: lec.file + '.html#' + h.a,
                            label: lec.title + ' › ' + h.t });
              }
            });
          });
          render(hits);
        });
      });
    })();
    </script>
HEAD

    # Walk modules in order, then lectures in order. modules.txt
    # holds "<Mnn>: <title>" lines. Lecture numbers are per-module:
    # each module's lectures start at L01.
    local modules_file="$REPO_ROOT/lectures/modules.txt"
    while IFS= read -r line; do
      line="${line%$'\r'}"
      case "$line" in
        ''|'#'*) continue ;;
      esac
      local mnum mtitle
      mnum="${line%%:*}"
      mtitle="${line#*: }"
      printf '    <section class="module">\n'
      printf '      <div class="module-no">%s</div>\n' "$mnum"
      printf '      <h2>%s</h2>\n' "$mtitle"
      printf '      <ul>\n'
      local lnum=0
      for src in "$REPO_ROOT"/lectures/"$mnum"-L*-*.md; do
        [ -f "$src" ] || continue
        local base ltitle
        base=$(basename "$src" .md)
        ltitle=$(awk '/^title:/ { sub(/^title: */, ""); sub(/^"/, ""); sub(/"$/, ""); print; exit }' "$src")
        lnum=$((lnum + 1))
        printf '        <li><span class="lec-no">L%02d</span> <a href="%s.html">%s</a></li>\n' \
          "$lnum" "$base" "$ltitle"
      done
      printf '      </ul>\n'
      printf '    </section>\n'
    done < "$modules_file"

    cat <<FOOT
    <p style="margin-top: 3rem; font-size: 0.88rem; color: var(--muted);">
      <a href="https://github.com/fplaunchpad/ocaml_nptel" target="_blank" rel="noopener">Source on GitHub</a>
      &nbsp;&middot;&nbsp;
      <a href="privacy.html">Privacy &amp; data collection</a>
      &nbsp;&middot;&nbsp;
      <a href="dashboard.html">Quiz analytics dashboard</a>
    </p>
  </article>
</body>
</html>
FOOT
  } > "$out"
  printf 'built _site/index.html\n'
}
emit_index

# Privacy / disclosure page. Documents what the analytics backend
# records, why, who has access, and lets the reader flip the
# opt-out toggle and delete prior responses via POST /quiz/forget.
emit_privacy() {
  local out="$REPO_ROOT/_site/privacy.html"
  cat > "$out" <<'PRIVACY'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="quiz-api" content="https://nptel-quiz.kc-7c7.workers.dev">
  <title>Privacy — Functional Programming with OCaml</title>
  <link rel="stylesheet" href="__ASSET_ROOT__/assets/css/chapter.css">
  <style>
    .privacy { max-width: 760px; margin: 2rem auto; padding: 0 1rem 4rem; }
    .privacy h1 { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 1.8rem; }
    .privacy h2 { margin-top: 2rem; font-size: 1.2rem; }
    .privacy .toggle-row { display: flex; align-items: center; gap: 0.7rem; margin: 0.6rem 0 1.2rem; }
    .privacy button {
      padding: 0.4rem 1rem; border: 1px solid var(--accent); background: #fff;
      color: var(--accent); border-radius: 4px; cursor: pointer;
      font: inherit;
    }
    .privacy button:hover { background: var(--code-bg); }
    .privacy button.danger { border-color: #b35858; color: #b35858; }
    .privacy button.danger:hover { background: #faecec; }
    .privacy .state { color: var(--muted); font-size: 0.95em; }
    .privacy code { font-family: ui-monospace, monospace; background: var(--code-bg); padding: 0.1em 0.3em; border-radius: 3px; font-size: 0.92em; }
  </style>
</head>
<body class="mode-chapter">
  <article class="privacy">
    <p><a href="index.html">← Course landing page</a></p>
    <h1>Privacy</h1>

    <p>The site can record <strong>anonymous</strong> responses to
    the inline quizzes if you opt in. This page explains exactly what
    is collected, what is not, who has access, how long we keep it,
    and how to opt in / out / export / delete at any time.</p>

    <p><strong>Default:</strong> opt-in. Nothing is sent until you
    explicitly click <em>Allow</em> in the consent banner. No login
    or account is involved either way.</p>

    <p><strong>Course audience:</strong> this material is intended
    for students 18 and older. We do not knowingly collect data
    from anyone under 18.</p>

    <h2>What we collect, per quiz answer</h2>
    <ul>
      <li>A random reader UUID, minted in your browser on first visit
        and stored locally. No name, no email, no account.</li>
      <li>The quiz identifier (page slug + auto-id like <code>q1</code>).</li>
      <li>The lecture page path (e.g. <code>/_site/M02-L01-literals.html</code>).</li>
      <li>The quiz kind: <code>mcq</code> (multiple choice) or
        <code>code</code> (code fill-in).</li>
      <li>For MCQs: which option you selected, and whether it was correct.</li>
      <li>For code quizzes: whether the assertions passed. <em>We do not
        record the code you wrote</em>, only pass or fail.</li>
      <li>A timestamp set by the server.</li>
      <li>The commit hash of the lecture source at the time, so we can
        compare answers before and after content changes.</li>
    </ul>

    <h2>What we do not collect</h2>
    <ul>
      <li>Name, email address, account information. There is no login.</li>
      <li>IP address. Cloudflare drops it at the edge before our code runs.</li>
      <li>Demographic data (age, region, prior experience).</li>
      <li>Your code from code-fill-in quizzes (only the pass/fail result).</li>
      <li>Browsing history beyond the quiz answer itself.</li>
    </ul>

    <h2>Why</h2>
    <p>The methodology mirrors the
    <a href="https://rust-book.cs.brown.edu/">Brown PLT TRPL quiz
    study</a> (Crichton et al., 2024). Aggregated answers tell us
    which questions are hardest, which wrong answers are most common,
    and where readers stop. We use that signal to revise difficult
    sections of the material, the same way the TRPL study did with
    twelve content interventions. We aim to publish anonymised
    aggregate results once the course has run for a semester.</p>

    <h2>Who has access</h2>
    <p>The course staff at IIT Madras (KC Sivaramakrishnan and
    teaching assistants). Aggregated dashboards may appear publicly;
    individual response rows do not. The public aggregate view lives
    at <a href="dashboard.html">dashboard.html</a> and shows only
    counts, accuracies, and option pick distributions.</p>

    <h2>Where the data lives, and cross-border transfer</h2>
    <p>Responses are stored in a single SQLite database hosted on
    <a href="https://developers.cloudflare.com/d1/">Cloudflare D1</a>,
    region-pinned to Asia-Pacific (APAC). Cloudflare may replicate
    data to other regions within its global network for resilience,
    governed by their
    <a href="https://www.cloudflare.com/cloudflare-customer-dpa/">Data
    Processing Addendum</a>. By opting in you consent to this
    cross-border transfer.</p>

    <h2>How long we keep it</h2>
    <p>Raw response rows are retained until the course completes a
    full delivery cycle (each NPTEL run is one semester) and the
    rows have been aggregated into the dashboard and any
    accompanying research dataset. After that, the raw rows are
    deleted; only the aggregate (no per-reader rows) is kept. You
    can also delete every row tied to your device immediately from
    this page using the buttons below.</p>

    <h2>Your choice on this device</h2>
    <p>Each setting is stored in your browser's localStorage, so
    it is per-device.</p>
    <div class="toggle-row">
      <button type="button" id="opt-toggle">Loading…</button>
      <span class="state" id="opt-state"></span>
    </div>

    <h2>Export your data</h2>
    <p>Download every response tied to your reader UUID, as JSON.
    Useful for transparency: see exactly what we have on you.</p>
    <p><button type="button" id="export-btn">Download my data</button>
       <span class="state" id="export-state"></span></p>

    <h2>Delete prior responses</h2>
    <p>Remove every response tied to your reader UUID. This is final
    and cannot be undone.</p>
    <p><button type="button" class="danger" id="forget-btn">Delete my data</button>
       <span class="state" id="forget-state"></span></p>

    <h2>Grievance redress</h2>
    <p>Per India's Digital Personal Data Protection Act, 2023, the
    contact for any complaint, correction request, or grievance
    related to this data collection is:</p>
    <p>KC Sivaramakrishnan,
       Assistant Professor, Dept. of Computer Science and Engineering,
       IIT Madras.<br>
       Email: <code>kc@tarides.com</code>.<br>
       Grievances are acknowledged within 7 days and addressed within
       30 days.</p>

    <h2>Source and policy version</h2>
    <p>This policy is version <strong>2026-05-20</strong>. If we
    materially change what is collected, the version bumps and the
    consent banner reappears so you can re-confirm.</p>
    <p>The Worker source is at
      <a href="https://github.com/fplaunchpad/ocaml_nptel/tree/main/tools/quiz-backend">github.com/fplaunchpad/ocaml_nptel/tools/quiz-backend</a>.
    The schema is one table; you can read it
      <a href="https://github.com/fplaunchpad/ocaml_nptel/blob/main/tools/quiz-backend/migrations/0001_init.sql">here</a>.</p>
  </article>

  <script>
    const API = document.querySelector('meta[name="quiz-api"]')?.content || '';
    const POLICY_VERSION = '2026-05-20';
    const CONSENT_KEY = 'nptel-analytics-consent';
    const CONSENT_VER_KEY = 'nptel-analytics-consent-version';
    const CONSENT_TS_KEY = 'nptel-analytics-consent-ts';
    const UUID_KEY = 'nptel-reader-uuid';

    function consentValue() {
      const v = localStorage.getItem(CONSENT_KEY);
      const ver = localStorage.getItem(CONSENT_VER_KEY);
      if ((v === 'yes' || v === 'no') && ver === POLICY_VERSION) return v;
      return 'pending';
    }
    function setConsent(v) {
      localStorage.setItem(CONSENT_KEY, v);
      localStorage.setItem(CONSENT_VER_KEY, POLICY_VERSION);
      localStorage.setItem(CONSENT_TS_KEY, new Date().toISOString());
    }
    function renderToggle() {
      const btn = document.getElementById('opt-toggle');
      const st  = document.getElementById('opt-state');
      const c = consentValue();
      if (c === 'yes') {
        btn.textContent = 'Opt out';
        const ts = localStorage.getItem(CONSENT_TS_KEY) || '';
        st.textContent  = 'Analytics is currently ON. Consent given at ' + ts + '.';
      } else if (c === 'no') {
        btn.textContent = 'Opt in';
        st.textContent  = 'Analytics is currently OFF on this device.';
      } else {
        btn.textContent = 'Opt in';
        st.textContent  = 'Analytics is currently OFF (you have not chosen yet).';
      }
    }
    document.getElementById('opt-toggle').addEventListener('click', () => {
      setConsent(consentValue() === 'yes' ? 'no' : 'yes');
      renderToggle();
    });
    renderToggle();

    document.getElementById('export-btn').addEventListener('click', async () => {
      const st = document.getElementById('export-state');
      const uuid = localStorage.getItem(UUID_KEY);
      if (!uuid) {
        st.textContent = 'No reader UUID found on this device; nothing to export.';
        return;
      }
      st.textContent = 'Fetching…';
      try {
        const r = await fetch(API + '/quiz/export', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({ reader_uuid: uuid }),
        });
        const j = await r.json();
        const blob = new Blob([JSON.stringify(j, null, 2)], { type: 'application/json' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = 'nptel-quiz-data.json';
        a.click();
        URL.revokeObjectURL(a.href);
        st.textContent = 'Downloaded ' + (j.count ?? 0) + ' response(s).';
      } catch (e) {
        st.textContent = 'Could not reach the server. Try again later.';
      }
    });

    document.getElementById('forget-btn').addEventListener('click', async () => {
      const st = document.getElementById('forget-state');
      const uuid = localStorage.getItem(UUID_KEY);
      if (!uuid) {
        st.textContent = 'No reader UUID found on this device; nothing to delete.';
        return;
      }
      if (!confirm('Delete every quiz response associated with this device? This cannot be undone.')) return;
      st.textContent = 'Deleting…';
      try {
        const r = await fetch(API + '/quiz/forget', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({ reader_uuid: uuid }),
        });
        const j = await r.json();
        st.textContent = 'Deleted ' + (j.deleted ?? 0) + ' response(s). Local reader UUID cleared.';
        localStorage.removeItem(UUID_KEY);
      } catch (e) {
        st.textContent = 'Could not reach the server. Try again later.';
      }
    });
  </script>
</body>
</html>
PRIVACY
  # The heredoc is quoted (lots of literal $ in the inline JS), so
  # expand the asset-root placeholder in a separate pass.
  local tmp
  tmp="$(mktemp)"
  sed "s|__ASSET_ROOT__|${ASSET_ROOT}|g" "$out" > "$tmp" && mv "$tmp" "$out"
  printf 'built _site/privacy.html\n'
}
emit_privacy

# Public analytics dashboard. Renders aggregated stats from the
# Cloudflare Worker at /quiz/agg and /quiz/agg/readers. Plain-JS;
# no build step. The page only ever displays counts and option-pick
# distributions; no individual response rows are shown.
emit_dashboard() {
  local out="$REPO_ROOT/_site/dashboard.html"
  cat > "$out" <<'DASHBOARD'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="quiz-api" content="https://nptel-quiz.kc-7c7.workers.dev">
  <title>Quiz analytics &middot; Functional Programming with OCaml</title>
  <link rel="stylesheet" href="__ASSET_ROOT__/assets/css/chapter.css">
  <!-- Vega-Lite powers the response-timeline chart. Loaded from a
       CDN: this is an internal, no-PII analytics page, so an
       external script is acceptable here (it is not loaded on any
       learner-facing lecture page). Pinned versions for repeatable
       rendering. -->
  <script src="https://cdn.jsdelivr.net/npm/vega@5.30.0"></script>
  <script src="https://cdn.jsdelivr.net/npm/vega-lite@5.21.0"></script>
  <script src="https://cdn.jsdelivr.net/npm/vega-embed@6.29.0"></script>
  <style>
    .dash { max-width: 980px; margin: 2rem auto; padding: 0 1rem 4rem; }
    .dash h1 { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 1.8rem; }
    .dash h2 { margin-top: 2.2rem; font-size: 1.2rem; }
    .dash .note {
      margin: 0.8rem 0 1.4rem;
      padding: 0.7rem 1rem;
      background: var(--code-bg);
      border-left: 3px solid var(--accent);
      color: var(--fg);
    }
    .dash .cards {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 0.8rem;
      margin: 0.6rem 0 1.4rem;
    }
    .dash .card {
      border: 1px solid var(--rule);
      border-radius: 4px;
      padding: 0.7rem 0.9rem;
      background: #fafafa;
    }
    .dash .card .label {
      font-size: 0.78rem;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: var(--muted);
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .dash .card .value {
      font-size: 1.5rem;
      font-weight: 600;
      margin-top: 0.2rem;
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .dash table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.92em;
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .dash th, .dash td {
      text-align: left;
      padding: 0.4rem 0.6rem;
      border-bottom: 1px solid var(--rule);
      vertical-align: middle;
    }
    .dash th {
      background: var(--code-bg);
      cursor: pointer;
      user-select: none;
      font-weight: 600;
      white-space: nowrap;
    }
    .dash th .arrow { color: var(--muted); font-size: 0.78em; margin-left: 0.2em; }
    .dash th[aria-sort="ascending"] .arrow::after { content: "\25B2"; }
    .dash th[aria-sort="descending"] .arrow::after { content: "\25BC"; }
    .dash td.num { text-align: right; font-variant-numeric: tabular-nums; }
    .dash td.code {
      font-family: ui-monospace, "JetBrains Mono", Menlo, monospace;
      font-size: 0.88em;
    }
    .dash tr.difficult td { background: #faecec; }
    .dash tr.difficult td:first-child { border-left: 3px solid #b35858; }

    /* CSS-only horizontal accuracy bar, paired with its percentage.
       The two sit in an inline-flex unit so the percentage can never
       wrap onto its own line, and the fixed-width percentage box keeps
       both the bars and the numbers aligned down the column. */
    .acc-cell {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      white-space: nowrap;
    }
    .acc-bar {
      position: relative;
      display: inline-block;
      flex: none;
      width: 110px;
      height: 0.7rem;
      background: var(--code-bg);
      border: 1px solid var(--rule);
      border-radius: 3px;
      overflow: hidden;
    }
    .acc-bar > span {
      display: block;
      height: 100%;
      background: var(--accent);
    }
    .acc-bar.low > span { background: #b35858; }
    .acc-bar.mid > span { background: #c4923a; }
    .acc-pct {
      flex: none;
      min-width: 3.6rem;
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    .dash .empty {
      padding: 2rem 1rem;
      text-align: center;
      color: var(--muted);
      border: 1px dashed var(--rule);
      border-radius: 4px;
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .dash .err {
      padding: 0.9rem 1rem;
      border: 1px solid #c98a8a;
      background: #f8e2e2;
      border-radius: 4px;
      color: #7a2929;
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-size: 0.92em;
    }
    .dash .legend {
      font-size: 0.85em;
      color: var(--muted);
      margin-top: 0.4rem;
      font-family: ui-sans-serif, system-ui, sans-serif;
    }
    .dash .legend .swatch {
      display: inline-block;
      width: 0.7em;
      height: 0.7em;
      border-radius: 2px;
      margin-right: 0.3em;
      vertical-align: -0.05em;
    }
    .dash .legend .swatch.low { background: #b35858; }
    .dash .legend .swatch.mid { background: #c4923a; }
    .dash .legend .swatch.hi  { background: var(--accent); }
    .dash .lecture-best  { color: #2e6e3a; font-weight: 600; }
    .dash .lecture-worst { color: #b35858; font-weight: 600; }
    .dash .distractor    { color: #b35858; }
    .dash .sha-pill      {
      display: inline-block; margin-left: 0.4em;
      padding: 0.05em 0.4em;
      font-family: ui-monospace, monospace; font-size: 0.78em;
      background: var(--code-bg); color: var(--muted);
      border-radius: 3px; vertical-align: 0.05em;
    }
    #timeline-chart { width: 100%; margin-top: 0.4rem; }
    /* Vega-Lite injects the granularity dropdown here. */
    #timeline-chart .vega-bindings {
      font-family: ui-sans-serif, system-ui, sans-serif;
      font-size: 0.85rem; color: var(--muted);
      margin-bottom: 0.4rem;
    }
    #timeline-chart .vega-bind select { margin-left: 0.3em; }
  </style>
</head>
<body class="mode-chapter">
  <article class="dash">
    <p><a href="index.html">&larr; Course landing page</a> &middot;
       <a href="privacy.html">Privacy</a></p>
    <h1>Quiz analytics</h1>
    <p class="note">This dashboard shows only aggregated data;
      individual responses are not displayed and cannot be
      reconstructed from this view.</p>

    <div id="status" class="empty">Loading aggregated stats&hellip;</div>

    <section id="cards-section" hidden>
      <div class="cards" id="cards"></div>
    </section>

    <section id="timeline-section" hidden>
      <h2>Responses over time</h2>
      <p class="legend">Total quiz responses per period. Switch the
        granularity (day / week / month); drag to pan and scroll to
        zoom the time window.</p>
      <div id="timeline-chart"></div>
    </section>

    <section id="lectures-section" hidden>
      <h2>Per-lecture summary</h2>
      <p class="legend">
        Highest aggregate accuracy:
        <span class="lecture-best" id="best-lecture">n/a</span>.
        Lowest aggregate accuracy:
        <span class="lecture-worst" id="worst-lecture">n/a</span>.
      </p>
      <table id="lectures-table">
        <thead>
          <tr>
            <th data-sort="lecture">Lecture <span class="arrow"></span></th>
            <th data-sort="num" class="num">Quizzes <span class="arrow"></span></th>
            <th data-sort="num" class="num">Attempts <span class="arrow"></span></th>
            <th data-sort="num" class="num">Avg accuracy <span class="arrow"></span></th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </section>

    <section id="per-quiz-section" hidden>
      <h2>Per-quiz accuracy</h2>
      <p class="legend">
        Rows where accuracy is below 30% are highlighted; these are
        TRPL-style &ldquo;difficult questions&rdquo; worth revisiting.
        <span class="swatch low"></span>&lt; 30%
        &nbsp;<span class="swatch mid"></span>30 to 70%
        &nbsp;<span class="swatch hi"></span>&gt; 70%
      </p>
      <table id="per-quiz-table">
        <thead>
          <tr>
            <th data-sort="quiz_id">Quiz <span class="arrow"></span></th>
            <th data-sort="kind">Kind <span class="arrow"></span></th>
            <th data-sort="num" class="num">Attempts <span class="arrow"></span></th>
            <th data-sort="num" class="num">Correct <span class="arrow"></span></th>
            <th data-sort="num" class="num">Accuracy <span class="arrow"></span></th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </section>

    <section id="distractor-section" hidden>
      <h2>MCQ top distractors</h2>
      <p class="legend">For each MCQ, the most popular <em>wrong</em>
        answer and how many readers picked it. Following Crichton et
        al., a high-pick distractor on a low-accuracy question is a
        signal that the wording is confusing.</p>
      <table id="distractor-table">
        <thead>
          <tr>
            <th data-sort="quiz_id">Quiz <span class="arrow"></span></th>
            <th data-sort="num" class="num">Accuracy <span class="arrow"></span></th>
            <th data-sort="num" class="num">Top distractor (option) <span class="arrow"></span></th>
            <th data-sort="num" class="num">Picks <span class="arrow"></span></th>
            <th data-sort="num" class="num">Share of wrong <span class="arrow"></span></th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </section>
  </article>

  <script>
    const API = document.querySelector('meta[name="quiz-api"]')?.content || '';

    const fmtPct = (x) => (x == null) ? 'n/a' : (Math.round(x * 1000) / 10).toFixed(1) + '%';
    const fmtInt = (x) => (x == null) ? 'n/a' : Number(x).toLocaleString();

    // Lecture slug = the page slug stripped of the [#qN] suffix.
    // quiz_id values are emitted by parse.ml as "<page>#<auto-id>",
    // where <page> is the basename of the rendered HTML. The reader
    // POSTs them including the leading "/_site/" path prefix, so we
    // strip that for a clean lecture display name.
    function lectureKey(quizId) {
      const hash = quizId.indexOf('#');
      let key = hash >= 0 ? quizId.slice(0, hash) : quizId;
      key = key.replace(/^\/?_site\//, '').replace(/^\/+/, '');
      return key;
    }
    // Pin every dashboard link to the commit_sha of the response,
    // not the current HEAD of the website. This way deleted or
    // renamed questions stay reachable: GitHub keeps every old
    // file at every old sha, so the reader sees the question text
    // exactly as it was when those responses were collected.
    // [latest_sha] comes from /quiz/agg (most recent response's
    // commit_sha for this quiz_id).
    const REPO_BLOB_BASE = 'https://github.com/fplaunchpad/ocaml_nptel/blob';
    function lectureFileFromQuizId(quizId) {
      // quiz_id is the page pathname + "#" + slug, e.g.
      // "/ocaml_nptel/M01-L02-why-fp.html#cons-immutability" on the
      // live GitHub Pages deploy (served under the repo-name base),
      // or "/_site/...html#..." locally. Lecture files are flat
      // under lectures/, so only the basename matters; any leading
      // path segment (the Pages base, "_site", a leading slash) must
      // be dropped or the .../lectures/<base>/<file>.md link 404s.
      const noFrag = quizId.split('#')[0];
      const base = noFrag.split('/').pop();
      const noHtml = base.replace(/\.html$/, '.md');
      return 'lectures/' + noHtml;
    }
    // A git sha is 7-40 hex chars. Anything else (empty, "unknown",
    // a malformed seed value like "abb9145d" that includes a stray
    // letter) we treat as missing and fall back to the main branch
    // so the link still resolves, even if it then shows the file
    // as it is in HEAD rather than at the original commit.
    const SHA_RE = /^[a-f0-9]{7,40}$/i;
    function quizLink(quizId, latestSha, latestLine) {
      const cleaned = quizId.replace(/^\/?_site\//, '').replace(/^\/+/, '');
      const fileMd = lectureFileFromQuizId(quizId);
      const validSha = (typeof latestSha === 'string' && SHA_RE.test(latestSha))
        ? latestSha : null;
      const ref = validSha || 'main';
      // GitHub's [?plain=1] toggles the source view (with line
      // numbers) instead of the rendered markdown; [#L<n>] jumps
      // to a specific line. Together they put the reader on the
      // exact quiz block.
      let href = REPO_BLOB_BASE + '/' + encodeURIComponent(ref) + '/' + fileMd;
      const validLine = Number.isInteger(latestLine) && latestLine > 0;
      if (validLine) {
        href += '?plain=1#L' + latestLine;
      }
      const pill = validSha ? validSha.slice(0, 7) : 'main';
      const pillClass = validSha ? 'sha-pill' : 'sha-pill sha-fallback';
      return '<a href="' + escapeHtml(href) + '" target="_blank" rel="noopener" '
           + 'title="View the lecture source at the commit these responses were collected against">'
           + escapeHtml(cleaned)
           + ' <span class="' + pillClass + '">' + escapeHtml(pill) + '</span></a>';
    }

    function accClass(a) {
      if (a == null) return '';
      if (a < 0.30) return 'low';
      if (a < 0.70) return 'mid';
      return 'hi';
    }

    function accBar(a) {
      const cls = accClass(a);
      const pct = (a == null) ? 0 : Math.max(0, Math.min(1, a)) * 100;
      return '<span class="acc-cell">'
           +   '<span class="acc-bar ' + cls + '"><span style="width:' + pct + '%"></span></span>'
           +   '<span class="acc-pct">' + fmtPct(a) + '</span>'
           + '</span>';
    }

    async function load() {
      const status = document.getElementById('status');
      let agg, readersInfo;
      try {
        const r1 = await fetch(API + '/quiz/agg');
        if (!r1.ok) throw new Error('HTTP ' + r1.status);
        agg = await r1.json();
      } catch (e) {
        status.className = 'err';
        status.textContent = 'Could not reach the analytics backend: ' + (e.message || e);
        return;
      }
      // Reader count is best-effort; if the endpoint is not deployed
      // yet, fall back to "unknown" rather than blocking the page.
      try {
        const r2 = await fetch(API + '/quiz/agg/readers');
        if (r2.ok) readersInfo = await r2.json();
      } catch (_) { /* ignore */ }
      // Timeline is best-effort too: an older Worker without the
      // /quiz/timeline route should not blank out the rest.
      let timeline;
      try {
        const r3 = await fetch(API + '/quiz/timeline');
        if (r3.ok) timeline = await r3.json();
      } catch (_) { /* ignore */ }

      const perQuiz = agg.per_quiz || [];
      const mcqOpts = agg.mcq_options || [];

      if (perQuiz.length === 0) {
        status.className = 'empty';
        status.textContent =
          'No quiz responses yet. Once readers start answering quizzes, '
          + 'aggregate statistics will appear here.';
        return;
      }

      // Reveal the dashboard now that we know there is data.
      status.hidden = true;
      ['cards-section', 'timeline-section', 'lectures-section',
       'per-quiz-section', 'distractor-section']
        .forEach((id) => { document.getElementById(id).hidden = false; });

      renderCards(perQuiz, readersInfo);
      renderTimeline(timeline ? (timeline.per_day || []) : []);
      renderLectures(perQuiz);
      renderPerQuiz(perQuiz);
      renderDistractors(perQuiz, mcqOpts);
    }

    // Response-timeline chart. The Worker serves daily totals; the
    // Vega-Lite spec re-buckets day -> week -> month on the client
    // via a bound dropdown, and an x-axis interval selection bound
    // to the scales gives drag-to-pan / scroll-to-zoom over the
    // window. Bucket math is in local time; for IST (UTC+5:30) a
    // UTC-midnight day stamp lands on the same calendar day, so the
    // day labels match the server's date(ts).
    function renderTimeline(perDay) {
      const section = document.getElementById('timeline-section');
      if (typeof vegaEmbed === 'undefined') {
        // CDN blocked / offline: leave a note instead of a blank box.
        section.querySelector('#timeline-chart').innerHTML =
          '<p class="note">Timeline chart could not load (the '
          + 'Vega-Lite library is unreachable).</p>';
        return;
      }
      if (!perDay.length) { section.hidden = true; return; }

      const spec = {
        $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
        width: 'container',
        height: 300,
        data: { values: perDay },
        params: [
          {
            name: 'gran',
            value: 'day',
            bind: {
              input: 'select',
              name: 'Granularity ',
              options: ['day', 'week', 'month'],
              labels: ['Day', 'Week', 'Month'],
            },
          },
          // Interval selection on x, bound to the scales: drag pans,
          // wheel zooms. This is the time-window picker.
          { name: 'window', select: { type: 'interval', encodings: ['x'] },
            bind: 'scales' },
        ],
        transform: [
          { calculate: 'toDate(datum.day)', as: 't' },
          // month() is 0-based in Vega expressions, and datetime()
          // takes a 0-based month, so they compose directly. The
          // week bucket snaps back to the preceding Sunday via
          // date - weekday (datetime handles the month underflow).
          {
            calculate:
              "gran == 'month' ? datetime(year(datum.t), month(datum.t), 1) : "
              + "gran == 'week' ? datetime(year(datum.t), month(datum.t), date(datum.t) - day(datum.t)) : "
              + "datetime(year(datum.t), month(datum.t), date(datum.t))",
            as: 'bucket',
          },
          { aggregate: [{ op: 'sum', field: 'n', as: 'total' }],
            groupby: ['bucket'] },
        ],
        // Line + points (no area fill, linear interpolation) reads
        // honestly at every granularity: ~70 daily points form a
        // sparkline; the 3-4 monthly points are clearly discrete
        // markers joined by straight segments, not a smoothed blob.
        mark: { type: 'line', point: true, interpolate: 'linear' },
        encoding: {
          x: { field: 'bucket', type: 'temporal', title: null,
               axis: { format: '%Y-%m-%d' } },
          y: { field: 'total', type: 'quantitative', title: 'Responses' },
          tooltip: [
            { field: 'bucket', type: 'temporal', title: 'Period',
              format: '%Y-%m-%d' },
            { field: 'total', type: 'quantitative', title: 'Responses' },
          ],
        },
        config: { view: { stroke: null } },
      };

      vegaEmbed('#timeline-chart', spec, { actions: false }).catch((e) => {
        section.querySelector('#timeline-chart').innerHTML =
          '<p class="note">Timeline chart failed to render: '
          + (e && e.message ? e.message : e) + '</p>';
      });
    }

    function renderCards(perQuiz, readersInfo) {
      const totalAttempts = perQuiz.reduce((a, r) => a + (r.attempts_total || 0), 0);
      const totalCorrect  = perQuiz.reduce((a, r) => a + (r.correct_total  || 0), 0);
      const overallAcc    = totalAttempts > 0 ? totalCorrect / totalAttempts : null;
      const mcqQuizzes    = perQuiz.filter((r) => r.kind === 'mcq').length;
      const codeQuizzes   = perQuiz.filter((r) => r.kind === 'code').length;

      const cards = [
        { label: 'Total responses',  value: fmtInt(totalAttempts) },
        { label: 'Distinct readers', value: readersInfo ? fmtInt(readersInfo.readers) : 'n/a' },
        { label: 'Quizzes seen',     value: fmtInt(perQuiz.length) },
        { label: 'MCQ / code',       value: fmtInt(mcqQuizzes) + ' / ' + fmtInt(codeQuizzes) },
        { label: 'Overall accuracy', value: fmtPct(overallAcc) },
      ];
      const el = document.getElementById('cards');
      el.innerHTML = cards.map(
        (c) => '<div class="card"><div class="label">' + c.label
             + '</div><div class="value">' + c.value + '</div></div>'
      ).join('');
    }

    function renderLectures(perQuiz) {
      const by = new Map();
      for (const r of perQuiz) {
        const key = lectureKey(r.quiz_id);
        let g = by.get(key);
        if (!g) { g = { lecture: key, quizzes: 0, attempts: 0, correct: 0 }; by.set(key, g); }
        g.quizzes  += 1;
        g.attempts += r.attempts_total || 0;
        g.correct  += r.correct_total  || 0;
      }
      const rows = Array.from(by.values()).map((g) => ({
        lecture:  g.lecture,
        quizzes:  g.quizzes,
        attempts: g.attempts,
        accuracy: g.attempts > 0 ? g.correct / g.attempts : null,
      }));

      // Best / worst by aggregate accuracy, ignoring lectures with no
      // attempts. Ties are broken by attempt count (more attempts wins).
      const withData = rows.filter((r) => r.accuracy != null && r.attempts > 0);
      if (withData.length > 0) {
        const sorted = withData.slice().sort((a, b) =>
          (b.accuracy - a.accuracy) || (b.attempts - a.attempts));
        document.getElementById('best-lecture').textContent =
          sorted[0].lecture + ' (' + fmtPct(sorted[0].accuracy) + ')';
        const last = sorted[sorted.length - 1];
        document.getElementById('worst-lecture').textContent =
          last.lecture + ' (' + fmtPct(last.accuracy) + ')';
      }

      const tbody = document.querySelector('#lectures-table tbody');
      rows.sort((a, b) => a.lecture.localeCompare(b.lecture));
      tbody.innerHTML = rows.map((r) => '<tr>'
        + '<td class="code">' + escapeHtml(r.lecture) + '</td>'
        + '<td class="num">' + fmtInt(r.quizzes) + '</td>'
        + '<td class="num">' + fmtInt(r.attempts) + '</td>'
        + '<td class="num">' + accBar(r.accuracy) + '</td>'
      + '</tr>').join('');

      attachSorter(document.getElementById('lectures-table'), [
        (r) => r.cells[0].textContent,
        (r) => Number(r.cells[1].textContent.replace(/,/g, '')),
        (r) => Number(r.cells[2].textContent.replace(/,/g, '')),
        (r) => parseFloat(r.cells[3].textContent.replace('%', '')) || -1,
      ]);
    }

    function renderPerQuiz(perQuiz) {
      const rows = perQuiz.slice().sort((a, b) => a.quiz_id.localeCompare(b.quiz_id));
      const tbody = document.querySelector('#per-quiz-table tbody');
      tbody.innerHTML = rows.map((r) => {
        const difficult = (r.accuracy != null && r.accuracy < 0.30) ? ' class="difficult"' : '';
        return '<tr' + difficult + '>'
          + '<td class="code">' + quizLink(r.quiz_id, r.latest_sha, r.latest_line) + '</td>'
          + '<td>' + escapeHtml(r.kind) + '</td>'
          + '<td class="num">' + fmtInt(r.attempts_total) + '</td>'
          + '<td class="num">' + fmtInt(r.correct_total)  + '</td>'
          + '<td class="num">' + accBar(r.accuracy) + '</td>'
        + '</tr>';
      }).join('');

      attachSorter(document.getElementById('per-quiz-table'), [
        (r) => r.cells[0].textContent,
        (r) => r.cells[1].textContent,
        (r) => Number(r.cells[2].textContent.replace(/,/g, '')),
        (r) => Number(r.cells[3].textContent.replace(/,/g, '')),
        (r) => parseFloat(r.cells[4].textContent.replace('%', '')) || -1,
      ]);
    }

    function renderDistractors(perQuiz, mcqOpts) {
      const byQuiz = new Map(perQuiz.map((r) => [r.quiz_id, r]));
      // Group option picks by quiz_id.
      const picksByQuiz = new Map();
      for (const o of mcqOpts) {
        let m = picksByQuiz.get(o.quiz_id);
        if (!m) { m = []; picksByQuiz.set(o.quiz_id, m); }
        m.push({ selected: o.selected, picks: o.picks });
      }

      const rows = [];
      for (const [quizId, picks] of picksByQuiz) {
        const meta = byQuiz.get(quizId);
        if (!meta || meta.kind !== 'mcq') continue;
        // The schema does not record which option index is canonical,
        // but every wrong selection is a distractor. Infer the correct
        // option as the one whose pick count exactly matches the
        // per-quiz [correct_total]. The remaining picks are all wrong.
        let correctIdx = null;
        for (const p of picks) {
          if (p.picks === meta.correct_total) { correctIdx = p.selected; break; }
        }
        const wrongOptions = picks.filter((p) => p.selected !== correctIdx);
        if (wrongOptions.length === 0) continue;
        wrongOptions.sort((a, b) => b.picks - a.picks);
        const top = wrongOptions[0];
        const wrongPicks = wrongOptions.reduce((a, p) => a + p.picks, 0);
        rows.push({
          quiz_id:     quizId,
          accuracy:    meta.accuracy,
          option:      top.selected,
          picks:       top.picks,
          wrongShare:  wrongPicks > 0 ? top.picks / wrongPicks : null,
          latest_sha:  meta.latest_sha,
          latest_line: meta.latest_line,
        });
      }

      const section = document.getElementById('distractor-section');
      if (rows.length === 0) {
        section.hidden = true;
        return;
      }
      rows.sort((a, b) => (a.accuracy ?? 1) - (b.accuracy ?? 1));

      const tbody = document.querySelector('#distractor-table tbody');
      tbody.innerHTML = rows.map((r) => {
        const difficult = (r.accuracy != null && r.accuracy < 0.30) ? ' class="difficult"' : '';
        return '<tr' + difficult + '>'
          + '<td class="code">' + quizLink(r.quiz_id, r.latest_sha, r.latest_line) + '</td>'
          + '<td class="num">' + accBar(r.accuracy) + '</td>'
          + '<td class="num distractor">option ' + fmtInt(r.option) + '</td>'
          + '<td class="num">' + fmtInt(r.picks) + '</td>'
          + '<td class="num">' + fmtPct(r.wrongShare) + '</td>'
        + '</tr>';
      }).join('');

      attachSorter(document.getElementById('distractor-table'), [
        (r) => r.cells[0].textContent,
        (r) => parseFloat(r.cells[1].textContent.replace('%', '')) || -1,
        (r) => Number((r.cells[2].textContent.match(/-?\d+/) || [0])[0]),
        (r) => Number(r.cells[3].textContent.replace(/,/g, '')),
        (r) => parseFloat(r.cells[4].textContent.replace('%', '')) || -1,
      ]);
    }

    // Click a column header to sort ascending; click again to flip.
    function attachSorter(table, accessors) {
      const ths = table.querySelectorAll('thead th');
      ths.forEach((th, i) => {
        th.addEventListener('click', () => {
          const tbody = table.querySelector('tbody');
          const rows  = Array.from(tbody.querySelectorAll('tr'));
          const dir   = th.getAttribute('aria-sort') === 'ascending' ? -1 : 1;
          ths.forEach((t) => t.removeAttribute('aria-sort'));
          th.setAttribute('aria-sort', dir === 1 ? 'ascending' : 'descending');
          rows.sort((a, b) => {
            const av = accessors[i](a);
            const bv = accessors[i](b);
            if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir;
            return String(av).localeCompare(String(bv)) * dir;
          });
          rows.forEach((r) => tbody.appendChild(r));
        });
      });
    }

    function escapeHtml(s) {
      return String(s ?? '')
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    load();
  </script>
</body>
</html>
DASHBOARD
  # Same placeholder expansion as emit_privacy (quoted heredoc).
  local tmp
  tmp="$(mktemp)"
  sed "s|__ASSET_ROOT__|${ASSET_ROOT}|g" "$out" > "$tmp" && mv "$tmp" "$out"
  printf 'built _site/dashboard.html\n'
}
emit_dashboard
