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

```
lectures/
  M01-L01-course-intro.md          One .md per lecture: M<module>-L<lecture>-<slug>.md.
  M01-L02-why-fp.md                M01-M12, with L counts 5, 6, 6, 6, 6, 7, 10, 8, 7, 5, 6, 4.
  ...                              (76 files: 73 recorded lectures + 3 slide-free practice
  M12-L04-suresh-the-stationmaster.md  chapters, M06-L07, M07-L10 and M08-L08).
  modules.txt                      Module titles used in sidebar + landing page.
  dune                             ocaml-mdx stanza listing every lecture.

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
  identifies the correct option. JS renders the list as a radio
  group, reveals the explanation on selection, and persists the
  reader's last answer in localStorage.
- `:::quiz code ... :::` blocks are code-fill-in quizzes. The first
  ` ```ocaml ` block is the student stub (usually with
  `failwith "not implemented"`); the second ` ```ocaml skip ` block
  is a hidden assertion block exercising the implementation. The
  reader clicks **Check** to run the test. The `skip` label keeps
  ocaml-mdx happy; the build's preprocessor positionally tags the
  second cell as the assertion block. Use `failwith`-based checks;
  the in-browser OCaml runtime does not provide `Assert_failure`,
  so OCaml's built-in `assert` does not work.

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
opam install -y cmarkit fpath alcotest mdx

# build the toolchain + render every lecture into _site/
tools/build-site.sh

# preview
python3 -m http.server 8765
# open http://localhost:8765/_site/M01-L01-course-intro.html
# or http://localhost:8765/_site/ for the landing page
```

## Tests

```sh
tools/run-tests.sh
```

Runs the OCaml unit + integration tests (`dune runtest`, which also
invokes `ocaml-mdx` over every lecture's code blocks) and a
Playwright end-to-end check that loads the smoke fixture in a real
browser, exercises slide navigation, run-all / clear-all / reset,
quiz interactivity, and verifies no console errors.

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
opening paragraph of M01-L01. Analytics is opt-out by default; see
the privacy page for the rationale.

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

---

[Index of all lectures](INDEX.md)
