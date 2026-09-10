# Project notes for Claude

NPTEL "Functional Programming with OCaml" course materials. Twelve
modules: M01-M08 functional programming, M09-M12 secure systems
(testing, memory safety, OxCaml, unikernels). Recording starts
2026-05-20 at the NPTEL studio.

For the design rationale, see the plan files (or ask the user).
The rest of this file is operational conventions.

## Author-comment workflow (KC drops notes, Claude sweeps)

KC leaves inline comments in any markdown source (lectures,
READMEs, plans). Claude sweeps and addresses them in batches so
KC does not have to interrupt the agent mid-task.

**Markers** (HTML comments, stripped by cmarkit and the build
pipeline, so they never appear in rendered output):

- `<!-- KC: <note> -->`: silent fix request. Address it, then
  remove the comment.
- `<!-- KC?: <question> -->`: KC wants an answer, not a silent
  fix. Reply by editing the comment to
  `<!-- KC?: <question> | claude: <answer> -->`, or by writing
  the answer in a follow-up chat message and removing the comment.
- `<!-- KC!: <blocker> -->`: must resolve before recording the
  lecture. Treat as priority; never leave one of these unresolved
  across sessions.

**Sweep command:**

```sh
grep -rEn '<!--[[:space:]]*KC[!?]?:' lectures/ tools/ assets/ README.md \
  2>/dev/null
```

(The pattern tolerates `<!-- KC:` and `<!--KC:` with or without
the space after `<!--`.)

Run this at the start of a session, when KC says "sweep", or
when finishing other work that may have created context for an
older comment.

**Loop:** walk matches top-to-bottom, edit the file, remove the
comment as you address it. If a comment turns out to be ambiguous
or you disagree, do not silently fix: convert it to `KC?:` form
with your question (or surface in chat).

## Style

- No em-dashes (`--` digram or `—` character) in prose. Use
  colons, semicolons, parens, commas, or separate sentences.
  Exceptions: CLI flag names (`--dce`), markdown table
  separators, YAML front-matter delimiters.
- Lectures wrap prose at ~70 columns (matches the established
  M01-M08 layout).
- Lecture markdown uses Pandoc-style fenced divs (`:::slide`,
  `:::subslide`, `:::fragment`, `:::notes`, `:::quiz mcq id=`,
  `:::quiz code id=`). See an existing lecture for the pattern.
- Commit messages: no `Co-Authored-By: Claude` trailer.

## Toolchain quick reference

- **Pre-recording sanity check**: `bash tools/run-tests.sh`.
  Runs (1) activity-fresh-code audit, (2) KC-comment sweep
  (`KC?:` and `KC!:` are blockers; plain `KC:` warns), (3)
  `dune runtest` for the mdx code blocks, (4) full site
  rebuild, (5) playwright end-to-end. Use this before
  recording any lecture; treat any non-zero exit as a "do not
  record" signal.
- Activity audit on its own: `python3 tools/audit-activities.py`
  (also called by `run-tests.sh`). Flags lectures whose
  `:::quiz code` asks for a function the chapter already
  walked through, the M07-L01 `make_counter`==`dispense` /
  M05-L04 `sign`==`sign` failure mode. Allowlist in the script
  for deliberate same-pattern-different-ADT extensions.
- Build site: `bash tools/build-site.sh` (set `COPY_ASSETS=1`
  to also refresh `_site/assets/`).
- Local server for browser checks: a Python http.server on
  `:8765` or `:8766` is often already running; check with
  `lsof -nP -iTCP -sTCP:LISTEN | grep 87`.
- Per-module in-browser bundles (see `tools/nptel-build/lib/emit.ml`):
  - M09 routes to `assets/x-ocaml/` with `m09-extras.js`
    extension (QCheck + OUnit2).
  - M11 routes to `assets/x-oxcaml/` (large OxCaml bundle).
  - Other modules route to plain `assets/x-ocaml/`.
- Rebuild the in-browser bundle: `bash tools/build-x-ocaml.sh`
  (vanilla bundle from `vendor/x-ocaml/`). The vendored
  `src/style.css` carries KC's tooltip-not-clipped fix
  (commit `b32ca84` on the `nptel` branch of
  `kayceesrk/x-ocaml`); the script's tail asserts the fix is
  present in the rebuilt bundle so a regression is caught
  loudly. The OxCaml bundle is rebuilt separately from the
  upstream `build_portable_js_extend.sh` on the OxCaml branch.
- mdx validation: `dune runtest` covers labelled, non-skip cells
  listed in `lectures/dune`: M01-M10 and M12-L03/L04 on the default
  switch. Plain fences and `ocaml skip` cells are excluded.
  M09 links qcheck/ounit2 and uses `lectures/mdx_prelude.ml` to
  control OUnit2 argv parsing and exit. The bytecode stack is
  capped so Stack_overflow demonstrations terminate promptly.
  M11 has a separate stanza: run `opam exec --switch nptel-ox --
  dune build @lectures/runtest`. `run-tests.sh` runs it when the
  switch is installed and warns when it is missing.

## Where things live

- Lectures: `lectures/MNN-Lnn-<slug>.md`.
- Plans: `/Users/kc/.claude/plans/`.
- References (gitignored): `_references/textbooks/`,
  `_references/_video/`.
- Licensing audit (gitignored, local-only): `LICENSING_AUDIT.md`.
- Recording-time estimates: `RECORDING-ESTIMATES.md`.

## What not to do without asking

- Do not commit `LICENSING_AUDIT.md` or anything under
  `_references/textbooks/` or `_references/_video/*.mp4`.
- Do not push to `main` after non-trivial restructuring without
  showing the diff first.
- Do not skip OCaml/OxCaml cells just because they raise compile
  errors: compile errors are often the point of the lecture. Use
  in-memory mocks rather than `skip` when an external dep (Unix,
  filesystem) is the only obstacle.
