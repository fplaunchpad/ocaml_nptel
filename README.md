# OCaml NPTEL course

Source repository for **Functional Programming with OCaml**, a 12-week
NPTEL MOOC taught by KC Sivaramakrishnan at IIT Madras. The first
eight modules cover functional programming in OCaml; the final four
turn to secure systems software (testing, memory safety, OxCaml's
type-level safety extensions, and unikernels with MirageOS). All
twelve modules are now authored.

Course launches on SWAYAM/NPTEL in **July 2026**.

Live preview: <https://fplaunchpad.github.io/ocaml_nptel/>.

## What's in here

<!-- course-inventory:start -->
80 lecture files: 73 non-practice chapters and 7 practice worksheets.
Module file counts (M01-M12): 5, 6, 7, 6, 7, 7, 10, 8, 8, 5, 7, 4.
<!-- course-inventory:end -->

Regenerate these counts from lecture metadata with
`python3 tools/course-inventory.py --write`.

```
lectures/
  M01-L01-course-intro.md          One .md per lecture: M<module>-L<lecture>-<slug>.md.
  M01-L02-why-fp.md                M01-M12, including practice worksheets.
  ...
  M12-L04-suresh-the-stationmaster.md
  modules.txt                      Module titles used in sidebar + landing page.
  dune                             Version-gated ocaml-mdx validation stanzas.

tools/
  nptel-build/                     OCaml binary: .md -> HTML (cmarkit + frontmatter
                                   parser + line-oriented fenced-div preprocessor
                                   + <x-ocaml> cell rendering + dual-mode HTML emit).
  build-site.sh                    Wrapper: builds the binary then renders every
                                   lecture into _site/, plus a landing index.html.
  build-diagrams.sh                pdflatex + pdftocairo pipeline: TikZ -> SVG
                                   for diagrams under assets/diagrams/.
  run-tests.sh                     dune runtest + Playwright smoke check.
  video-pipeline/                  yt-dlp + ffmpeg + mlx-whisper pipeline that
                                   turns the CS3100 YouTube playlist into local
                                   transcripts under _references/_video/.
  playwright-check.mjs             Headless render check used during development.

assets/
  x-ocaml/                         Prebuilt in-browser OCaml WebComponent
                                   (host + worker JS, vanilla OCaml 5.4.0).
  reveal/dist/                     reveal.js 5.x for slide mode.
  css/chapter.css                  Long-form chapter styling, sidebar, prev/next.
  css/slides.css                   Slide-mode overrides for reveal.js.
  diagrams/                        TikZ sources (.tex) + generated SVGs.

vendor/
  x-ocaml/                         Submodule: kayceesrk/x-ocaml @ nptel.
                                   Used only to rebuild the bundles in
                                   assets/x-ocaml/ when needed.

_references/                       Source material consulted by authors.
  textbooks/                       cs3110, RWO v2, Whitington PDF (gitignored).
  profiling_a_programming_language/ Crichton et al. paper (gitignored).
  _video/                          CS3100 transcripts (commit: transcript.md +
                                   slides_with_narration.json; gitignored:
                                   raw .mp4 / .wav / .json).
  cs3100_m20/, cs3100_m25/         Prior-iteration source notebooks (gitignored).

PLAN.md                            Module-by-module mapping from CS3100 to NPTEL.
```

## Authoring a lecture

Each lecture is one markdown file `lectures/M<nn>-L<nn>-<slug>.md`
with a YAML frontmatter block. Inside the body, CommonMark plus a
few extensions:

- ` ```ocaml ` fenced blocks render as `<x-ocaml>` runnable cells
  (with optional attributes: `init`, `autorun`, `hidden`, `skip`).
- `:::slide ... :::` blocks become slides in reveal.js mode.
- `:::notes ... :::` blocks are speaker notes.
- `:::fragment ... :::` blocks are progressive reveals inside a slide.
- `:::quiz mcq ... :::` blocks are inline multiple-choice quizzes.
  The author writes the answers as a GFM task list; the `[x]` marker
  identifies the single correct option. Exactly one `[x]` is required;
  the MCQ authoring audit rejects missing or multiple answers.
  JS renders the list as a radio
  group, reveals the explanation on selection, and persists the
  reader's last answer in localStorage.
- `:::quiz code ... :::` blocks are code-fill-in quizzes. The first
  ` ```ocaml ` block is the student stub (usually with
  `failwith "not implemented"`); the second ` ```ocaml skip ` block
  is a hidden assertion block exercising the implementation. The
  reader clicks **Check** to run the test. The `skip` label keeps
  ocaml-mdx happy; the build's preprocessor positionally tags the
  second cell as the assertion block. Use `failwith`-based checks;
  the OxCaml browser bundle lacks the predefined `Assert_failure`
  exception, so built-in `assert` cannot compile there.

See [`lectures/M02-L01-literals.md`](lectures/M02-L01-literals.md)
for the canonical example: ~700 lines, prose-first chapter view,
slides as terse video summaries, with both an MCQ and a code quiz.

Lecture numbers **restart within each module**: the header bar and
title slide of each lecture show `Module <m> · Lecture <n>`, where
`<n>` is the lecture's position inside its own module (so the first
lecture of Module 5 reads `Module 5 · Lecture 1`).

## Build & preview locally

```sh
opam switch create . 5.4.0   # only the first time
opam install . --deps-only --with-test -y

# build the toolchain + render every lecture into _site/
tools/build-site.sh

# preview
python3 -m http.server 8765
# open http://localhost:8765/_site/M01-L01-course-intro.html
# or http://localhost:8765/_site/ for the landing page
```

## Distribute an offline book

From a checkout with the usual build dependencies and Python 3.8+:

```sh
python3 tools/build-offline.py
# produces dist/ocaml-nptel-offline.tar.gz
```

The archive includes all 80 lectures, static assets, OCaml/OxCaml
runtimes, and the Linux terminal's VM snapshot and filesystem. It
builds in a temporary directory without changing the local `_site/`
preview. The default VM source is `_vm-prototype/images-v6/`;
provide another complete, compatible course image with:

```sh
python3 tools/build-offline.py --vm-dir /path/to/current \
  --output /path/to/ocaml-nptel-offline.tar.gz
```

The image directory must contain `ocaml-state.bin.zst`,
`ocaml-fs.json`, and `ocaml-rootfs-flat/`. Every chunk referenced
by the manifest is checked before building. Missing VM data is a
build error; see `tools/vm-image/README.md` for image preparation.
The script uses the prebuilt browser bundles in `assets/`.
Building requires Bash 4+ (on macOS, put Homebrew Bash on `PATH`).

Readers extract the archive and double-click **`index.html`**.
Only a modern browser is required. There is no local server,
launcher, installation, or special browser flag.

The packager keeps the existing x-ocaml and v86 runtimes. It
bundles x-ocaml's worker code into local scripts that create Blob
workers, converts slide initialization to a classic script, and
embeds the search index. VM binaries are encoded as scripts and
loaded on demand through a local-file adapter. The online assets
and deployment are unchanged. Adapter substitutions are checked
at build time so an upstream runtime change fails explicitly.

Saved answers and edits use browser storage. Persistence for
`file://` pages varies by browser, and moving the extracted folder
may make earlier saved work unavailable.

External links, videos, and the analytics dashboard require internet.
Quiz analytics keeps its existing consent behaviour and silently
ignores failed submissions. The course itself, including the VM,
uses bundled resources.

To verify an extracted archive with development dependencies:

```sh
node tools/playwright-offline-check.mjs /path/to/ocaml-nptel-offline/index.html
```

This blocks remote requests and checks search, slides, all three
browser runtime configurations, and a build inside the Linux VM.
Set `BROWSER=firefox` or `BROWSER=webkit` to check those engines
(default: Chromium); install them with
`npx playwright install firefox webkit`.

## Tests

```sh
tools/run-tests.sh
```

Runs source audits, OCaml unit and integration tests, quiz checks,
a site rebuild, browser and VM smoke checks, and a slide-overflow
scan. The browser smoke fixture exercises slide navigation,
run-all / clear-all / reset, and quiz interactivity.

`dune runtest` also runs `ocaml-mdx` on labelled, non-`skip` OCaml
fences listed in `lectures/dune`: M01-M10 and M12-L03/L04 on the
default switch. Plain fences and `ocaml skip` cells are excluded;
M12-L01/L02 are not listed. M11 has a separate stanza requiring the
course `nptel-ox` switch (compiler version `5.2.0+ox`).
`run-tests.sh` prefers that switch, falls back to an existing
`5.2.0+ox` switch, and warns if neither is installed. Use
`bash tools/setup-switch.sh` to install the declared build/test
dependencies and provision OxCaml; validate M11 separately with:

```sh
opam exec --switch nptel-ox -- dune build @lectures/runtest
opam exec --switch nptel-ox -- python3 tools/check-quiz-solutions.py --oxcaml
```

Build dependencies and test-only dependencies are declared in
`dune-project`; `nptel-ocaml.opam` is generated by Dune. README,
setup, and CI use `opam install . --deps-only --with-test` so the
test libraries are included. QCheck 0.90 or later is required by
the lecture API names.

The separate OxCaml switch does not install this package's
default-switch dependencies. The setup script pins an
OxCaml repository snapshot and explicitly installs its compatible
Dune and MDX versions; those tools do not ship with a bare compiler.
It creates a separate `nptel-ox` switch and keeps the current switch
selected.

Set `OX_SWITCH=5.2.0+ox` for both setup and tests to reuse
an existing compatible switch. Existing package versions are frozen
during setup, so an incompatible compiler causes an error instead
of a silent downgrade.

A small local compiler-package overlay fixes an old build-script
bug that truncated preprocessor flags at `=`;
see `tools/oxcaml-opam/README.md`.

The quiz regression check runs the references, unfinished starters, and
known incorrect answers for the quizzes listed in
`tools/quiz-regressions.json`, using the actual lecture assertion cells.
Each answer gets a fresh toplevel. OxCaml cases are marked separately
in the manifest and run with `--oxcaml` under the OxCaml switch;
the browser harness includes both runtimes. CI and deployment run
the default OCaml cases with
`opam exec -- python3 tools/check-quiz-solutions.py`; this supplements
MDX, which skips the quiz assertion cells. It does not yet cover every
quiz in the course. Add prerequisite fence anchors and counterexamples
to the manifest when extending coverage.

`tools/run-tests.sh` checks the repaired single-choice MCQs with
`tools/playwright-mcq-check.mjs`, including saved-answer recovery.
It also checks the code answers through the browser's
**Check** button. A reported timeout is retried once in the same
browser context; a second timeout fails the harness even for an
answer expected to be rejected. To run just that check locally:
`node tools/playwright-quiz-check.mjs http://localhost:8765/_site`.

## Hosting

`.github/workflows/pages.yml` deploys `_site/` to GitHub Pages on
every push to `main`. After the first push:

1. On GitHub: **Settings → Pages**.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Wait for the first workflow run to finish; the site URL appears
   at the top of the Pages settings page.

The workflow does not build `vendor/x-ocaml`; it uses the prebuilt
bundles already committed under `assets/x-ocaml/`.

## Quiz analytics

The site records anonymous quiz responses via a small Cloudflare
Worker (`tools/quiz-backend/`). Per response we store: an anonymous
reader UUID minted in localStorage on first visit, the quiz id, the
page slug, the MCQ option selected (or pass/fail for code quizzes),
correctness, a server-side timestamp, and the lecture commit SHA.
**No PII**: no name, email, IP, demographic data, or code text. The
backend is a single Worker file plus a D1 (SQLite) schema; deploy
runs from `.github/workflows/quiz-backend.yml` on push to main. The
disclosure surfaces in three places: a first-visit banner on every
lecture, the [`/privacy.html`](https://fplaunchpad.github.io/ocaml_nptel/privacy.html)
page (with an opt-out toggle and a "delete my data" button that
exercises `POST /quiz/forget` for DPDPA right-to-erasure), and the
opening paragraph of M01-L01. Analytics is opt-in: responses are
sent only after explicit consent to the current policy. Readers can
withdraw consent on the privacy page.

## Learn more about OCaml

- The OCaml language home page: <https://ocaml.org/>. Install
  instructions, the language manual, and the ecosystem of libraries
  and tools.

## Acknowledgements

- [`art-w/x-ocaml`](https://github.com/art-w/x-ocaml) by Arthur
  Wendling: the in-browser OCaml WebComponent that powers every
  runnable cell on the site.
- [Cornell CS3110 textbook](https://cs3110.github.io/textbook/),
  [Real World OCaml v2](https://dev.realworldocaml.org/), and
  John Whitington's *OCaml from the Very Beginning*: the three
  reference texts the lecture material draws on most heavily.
- Crichton et al., *Profiling Programming Language Learning*
  (Brown PLT): the TRPL inline-quiz study that motivated the
  quiz infrastructure.
- The CS3100 students at IIT Madras whose questions over four
  semesters shaped how this material is taught.

## License

Course material distributed under **CC-BY-NC-SA** per the NPTEL
faculty guidelines.
