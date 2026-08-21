#!/usr/bin/env bash
# Full test pipeline -- the pre-recording sanity check.
#   1. tools/audit-activities.py  -- activity-fresh-code rule
#                                    (M07-L01 / M05-L04 failure
#                                    mode: chapter walks function
#                                    through, activity asks
#                                    student to recreate it)
#   2. tools/audit-mcq-length.py   -- prevent longest-answer MCQ bias
#   3. KC-comment sweep            -- any unresolved silent-fix
#                                    or blocker comments KC drops
#                                    in lecture markdown. KC! and
#                                    KC? block; plain KC: warns.
#   4. tools/check-links.py        -- cross-lecture links, heading
#                                    anchors, asset refs
#   5. dune runtest                -- mdx code blocks compile
#                                    (default switch for M01-M10/M12,
#                                    plus a 5.2.0+ox pass for M11)
#   6. tools/build-site.sh         -- rebuild + smoke pages
#   7. tools/playwright-check.mjs  -- end-to-end browser test
#   8. playwright VM boot          -- M01-L01 embed: boot + run hello
#   9. dashboard smoke             -- dashboard renders against the
#                                    live worker (skipped offline)
#  10. slide-overflow scan         -- every deck fits 1280x800
#                                    (parallel, ~15s; CHECK_OVERFLOW=0
#                                    to skip)
#
# Exits non-zero on any failure. Run from anywhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

bold '[1/10] activity-fresh-code audit'
python3 tools/audit-activities.py

bold '[2/10] MCQ answer-length audit'
python3 tools/audit-mcq-length.py

bold '[3/10] KC-comment sweep'
# `KC:` (silent fix) is allowed to linger; `KC?:` and `KC!:` are
# blockers per CLAUDE.md. Surface all three so the user sees them.
KC_HITS=$(grep -rEn '<!--[[:space:]]*KC[!?]?:' \
  lectures/ tools/ assets/ README.md 2>/dev/null || true)
if [ -n "$KC_HITS" ]; then
  red "Unresolved KC comments:"
  echo "$KC_HITS"
  # Fail only on KC! or KC? (the explicit-attention markers).
  # Plain KC: is the silent-fix backlog and doesn't block recording.
  if echo "$KC_HITS" | grep -qE '<!--[[:space:]]*KC[!?]:'; then
    red 'KC!: or KC?: present -- resolve before recording.'
    exit 1
  fi
  green '  (only silent KC: notes; not blocking.)'
else
  green '  no KC comments outstanding'
fi

bold '[4/10] link + anchor check'
python3 tools/check-links.py

bold '[5/10] dune runtest (mdx + OCaml tests)'
# Pass 1 (default switch): validates M01-M10 and M12. The M11 stanza
# in lectures/dune is gated off here (it needs the OxCaml compiler).
opam exec -- dune runtest
# Pass 2 (OxCaml switch): M11 mode syntax compiles only on 5.2.0+ox.
# The non-M11 stanza is gated off there, so this checks just the M11
# cells (and does not rebuild nptel-build on the ox switch). Skipped
# with a warning if the switch is not installed.
OX_SWITCH=5.2.0+ox
if opam switch list -s 2>/dev/null | grep -qx "$OX_SWITCH"; then
  opam exec --switch "$OX_SWITCH" -- dune build @lectures/runtest
else
  red "  ($OX_SWITCH switch not found; skipping M11 mdx validation)"
fi

bold '[6/10] build site'
tools/build-site.sh

bold '[7/10] playwright end-to-end'
# Find a server rooted at the repo (so /_site/... resolves): reuse one
# that already serves the smoke page correctly, else bind the first
# free port from the candidate list. A stale server squatting a port
# from the wrong document root no longer fails the run; we just move
# to the next port.
PORT=""
SERVER_PID=""
for p in 8765 8766 8867 8964; do
  url="http://localhost:$p/_site/test/smoke.html"
  if curl -sf -o /dev/null "$url"; then
    PORT=$p
    break
  fi
  if ! lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    green "  starting http.server on $p for the duration of the test"
    python3 -m http.server "$p" --directory . >/dev/null 2>&1 &
    SERVER_PID=$!
    for _ in 1 2 3 4 5; do
      sleep 0.3
      curl -sf -o /dev/null "$url" && break
    done
    if curl -sf -o /dev/null "$url"; then
      PORT=$p
      break
    fi
    kill "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
  fi
done
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true' EXIT
if [ -z "$PORT" ]; then
  red "  could not reach or start a repo-rooted http.server on any of"
  red "  the candidate ports (8765 8766 8867 8964)."
  exit 1
fi
SMOKE_URL="http://localhost:$PORT/_site/test/smoke.html"

node "$SCRIPT_DIR/playwright-check.mjs" "$SMOKE_URL"

bold '[8/10] playwright VM boot (M01-L01 embed)'
# Boot the dune VM embedded in M01-L01 (:::vm-terminal dir=/root/hello)
# and build+run hello end-to-end. Use the local VM data when the build
# scratch dir is present (fast, no network); otherwise fall back to the
# production fplaunchpad/ocaml-browser-vm Pages site baked into the
# component.
if [ -f "$REPO_ROOT/_vm-prototype/images/ocaml-state.bin.zst" ]; then
  export VMBASE="http://localhost:$PORT/_vm-prototype/images"
  green "  using local VM data ($VMBASE)"
fi
node "$SCRIPT_DIR/playwright-vm-check.mjs" \
  "http://localhost:$PORT/_site/M01-L01-course-intro.html"

bold '[9/10] dashboard smoke'
# The dashboard JS needs the live worker; skip (don't fail) when it
# is unreachable, e.g. recording offline in the studio.
QUIZ_API="https://nptel-quiz.kc-7c7.workers.dev"
if curl -sf -o /dev/null --max-time 10 "$QUIZ_API/quiz/agg"; then
  node "$SCRIPT_DIR/playwright-dashboard-check.mjs" \
    "http://localhost:$PORT/_site/dashboard.html"
else
  red "  quiz worker unreachable (offline?); skipping dashboard smoke."
fi

bold '[10/10] slide-overflow scan (all decks)'
# Parallel scan of every deck against the 1280x800 canvas (~15s with
# the default 6-tab pool). Skip with CHECK_OVERFLOW=0; single pages:
#   node tools/playwright-overflow-check.mjs http://localhost:8765/_site page.html
if [ "${CHECK_OVERFLOW:-1}" = "1" ]; then
  node "$SCRIPT_DIR/playwright-overflow-check.mjs" \
    "http://localhost:$PORT/_site"
else
  red '  skipped (CHECK_OVERFLOW=0)'
fi

green 'All tests passed.'
