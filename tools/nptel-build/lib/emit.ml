(* Emit a single self-contained HTML page that hosts both the chapter
   view and a reveal.js slide view of the same content. The mode is
   selected client-side by the toggle button or the [#slides] URL hash.

   Asset paths are computed relative to the lecture HTML file's location
   inside [_site/], using a single configurable depth: the number of
   path segments between the lecture file and the repo root. For
   [_site/week01-intro/L02-what-is-fp.html] the depth is 2; for
   [_site/test/smoke.html] the depth is 2 as well. We just pass
   [relative_root] as a string like ["../.."]. *)

let quiz_api_url = "https://nptel-quiz.kc-7c7.workers.dev"

(* Short content hash of a file relative to the build cwd. Used as a
   [?v=...] cache-buster on the x-ocaml worker URL so a rebuilt bundle
   invalidates the worker the browser previously fetched. Memoized so we
   only digest each bundle once per build. *)
let bundle_hash_cache : (string, string) Hashtbl.t = Hashtbl.create 8

let bundle_hash rel_path =
  match Hashtbl.find_opt bundle_hash_cache rel_path with
  | Some h -> h
  | None ->
      let h =
        try
          let ic = open_in_bin rel_path in
          let len = in_channel_length ic in
          let s = really_input_string ic len in
          close_in ic;
          String.sub (Digest.to_hex (Digest.string s)) 0 8
        with Sys_error _ | End_of_file ->
          (* [rel_path] is cwd-relative; running the renderer from
             outside the repo root used to silently emit ?v=missing
             cache-busters. Warn so the misconfiguration is visible. *)
          Printf.eprintf
            "warning: bundle_hash: cannot read %s (run from the repo \
             root?); emitting ?v=missing\n"
            rel_path;
          "missing"
      in
      Hashtbl.add bundle_hash_cache rel_path h;
      h

let head ~asset_root ~(fm : Frontmatter.t) ~vm_terminal =
  (* [asset_root] is the prefix used in front of each asset path. For
     production we use root-relative paths like ["/assets/..."], so
     callers pass [""] and the leading slash comes from each href.
     For previewing inside a subdirectory (e.g. when assets live under
     [/_site/]), the caller can pass that prefix instead. *)
  let commit_sha =
    match Sys.getenv_opt "NPTEL_COMMIT_SHA" with
    | Some s when String.trim s <> "" -> s
    | _ -> "unknown"
  in
  (* Per-module x-ocaml runtime selection.

     M01..M10 and M12 use the vanilla x-ocaml bundle at
     [assets/x-ocaml/]. M09 (testing) additionally loads an extension
     bundle via [src-load] that adds QCheck and OUnit2 into the
     running vanilla toplevel; the bundle is produced by
     tools/build-m09-extras.sh using the patched js_of_ocaml fork and
     composes additively with the worker's Stdlib.

     M11 (OxCaml) uses an entirely different worker: the x-oxcaml
     bundle at [assets/x-oxcaml/], built against OCaml 5.2.0+ox (the
     effects=cps toplevel from the oxcaml branch of kayceesrk/x-ocaml),
     so locality / uniqueness / linearity mode syntax compiles in the
     cells. It additionally loads [portable.js] via [src-load]: the
     ~4 MB cross-cma-DCE extension bundle (basement + capsule0 +
     capsule + await + portable) built by the fork's
     build_portable_js_extend.sh, which brings [Portable.Atomic],
     [Domain.Safe.spawn] clients and the capsule API into the
     toplevel. See the 2026-05-10 kcsrk.info post "Shrinking the
     OxCaml js_of_ocaml bundle" for the recipe. *)
  let bundle_dir, src_load_attr =
    match fm.week with
    | Some 9 ->
        let v = bundle_hash "assets/x-ocaml/m09-extras.js" in
        ( "x-ocaml",
          Printf.sprintf
            "\n    src-load=\"%s/assets/x-ocaml/m09-extras.js?v=%s\""
            asset_root v )
    | Some 11 ->
        let v = bundle_hash "assets/x-oxcaml/portable.js" in
        ( "x-oxcaml",
          Printf.sprintf
            "\n    src-load=\"%s/assets/x-oxcaml/portable.js?v=%s\""
            asset_root v )
    | _ -> ("x-ocaml", "")
  in
  let main_v = bundle_hash (Printf.sprintf "assets/%s/x-ocaml.js" bundle_dir) in
  let worker_v =
    bundle_hash (Printf.sprintf "assets/%s/x-ocaml.worker.js" bundle_dir)
  in
  (* Cache-bust the local stylesheets the same way as the bundle, so an
     edited chapter.css / slides.css invalidates the browser's cached
     copy on the next build (these are served without far-future caching
     but browsers still hold a copy across visits). *)
  let chapter_css_v = bundle_hash "assets/css/chapter.css" in
  let slides_css_v = bundle_hash "assets/css/slides.css" in
  let katex_css_v = bundle_hash "assets/katex/katex.min.css" in
  let katex_js_v = bundle_hash "assets/katex/katex.min.js" in
  let katex_auto_v = bundle_hash "assets/katex/contrib/auto-render.min.js" in
  (* The in-browser VM terminal loads only on the rare lecture that
     carries a [:::vm-terminal] div. The component itself fetches
     nothing further until the student clicks Start. *)
  let vm_script =
    if not vm_terminal then ""
    else
      Printf.sprintf
        "\n  <script defer src=\"%s/assets/vm/vm-terminal.js?v=%s\"></script>"
        asset_root
        (bundle_hash "assets/vm/vm-terminal.js")
  in
  Printf.sprintf
    {|<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <meta name="commit-sha" content="%s">
  <meta name="quiz-api" content="%s">
  <title>%s</title>
  <link rel="stylesheet" href="%s/assets/reveal/dist/reveal.css">
  <link rel="stylesheet" href="%s/assets/reveal/dist/theme/white.css" id="reveal-theme">
  <link rel="stylesheet" href="%s/assets/css/chapter.css?v=%s">
  <link rel="stylesheet" href="%s/assets/css/slides.css?v=%s">
  <!-- KaTeX for inline / display math (vendored 0.16.10 under
       assets/katex/, so math also renders offline, e.g. in the
       recording studio). Auto-render walks the DOM after load and
       rewrites $...$ and \(...\) inline and $$...$$ / \[...\]
       display delimiters into rendered math. We skip <x-ocaml>, <code>,
       <pre> so OCaml source / shell output never gets math-rendered. -->
  <link rel="stylesheet" href="%s/assets/katex/katex.min.css?v=%s">
  <script defer src="%s/assets/katex/katex.min.js?v=%s"></script>
  <script defer src="%s/assets/katex/contrib/auto-render.min.js?v=%s"
    onload="renderMathInDocument()"></script>
  <script>
    function renderMathInDocument() {
      if (typeof renderMathInElement !== 'function') return;
      renderMathInElement(document.body, {
        delimiters: [
          { left: '$$', right: '$$', display: true },
          { left: '\\[', right: '\\]', display: true },
          { left: '\\(', right: '\\)', display: false },
          { left: '$', right: '$', display: false }
        ],
        ignoredTags: ['script', 'noscript', 'style', 'textarea',
                      'pre', 'code', 'x-ocaml'],
        throwOnError: false
      });
    }
  </script>
  <script async
    src="%s/assets/%s/x-ocaml.js?v=%s"
    src-worker="%s/assets/%s/x-ocaml.worker.js?v=%s"
    x-ocamlformat="margin=60"%s></script>%s
</head>|}
    (Parse.html_escape commit_sha)
    (Parse.html_escape quiz_api_url)
    (Parse.html_escape (if fm.title = "" then "(untitled lecture)" else fm.title))
    asset_root asset_root asset_root chapter_css_v asset_root slides_css_v
    asset_root katex_css_v asset_root katex_js_v asset_root katex_auto_v
    asset_root bundle_dir main_v asset_root bundle_dir worker_v
    src_load_attr (vm_script ^ (match fm.youtube_id with
      | None -> ""
      | Some _ -> Printf.sprintf
          "\n  <script defer src=\"%s/assets/lecture-video.js?v=%s\"></script>"
          asset_root (bundle_hash "assets/lecture-video.js")))

let header_bar ~(fm : Frontmatter.t) ~has_slides =
  let lecture_id =
    match fm.week, fm.lecture_no with
    | Some w, Some l -> Printf.sprintf "Module %d &middot; Lecture %d" w l
    | _ -> ""
  in
  let title = if fm.title = "" then "(untitled)" else Parse.html_escape fm.title in
  (* Practice chapters and any other slide-free page omit the
     slide-mode toggle: there is no deck to switch into. *)
  let mode_toggle =
    if has_slides then
      {|    <button class="mode-toggle" type="button" aria-label="Toggle slide mode">
      <span class="when-chapter">Slides &rarr;</span>
      <span class="when-slides">&larr; Chapter</span>
    </button>
|}
    else ""
  in
  Printf.sprintf
    {|  <header class="page-header">
    <button class="sidebar-collapse chapter-only" type="button" title="Show or hide the course outline" aria-label="Toggle course outline">&#9776;</button>
    <a class="home-link" href="index.html" title="Course landing page" aria-label="Course landing page">&#x2302;</a>
    <div class="lecture-meta">%s</div>
    <h1 class="lecture-title">%s</h1>
    <div class="cell-controls">
      <button class="run-up-to-here" type="button" title="Run all cells up to (and including) the current slide / cursor">Run &uarr; here</button>
      <button class="run-all" type="button" title="Run every cell on the page in order">Run all</button>
      <button class="clear-all" type="button" title="Clear outputs of every cell">Clear outputs</button>
      <button class="reset-all" type="button" title="Restore every cell to its source from the markdown file">Reset all cells</button>
    </div>
%s  </header>|}
    lecture_id title mode_toggle

let footer_meta ~(fm : Frontmatter.t) =
  let buf = Buffer.create 256 in
  let line label value =
    if value <> "" then
      Buffer.add_string buf
        (Printf.sprintf
           {|    <div class="meta-line"><span class="meta-label">%s</span> %s</div>|}
           label value)
  in
  Buffer.add_string buf "  <footer class=\"chapter-only lecture-meta-footer\">\n";
  line "Concepts:" (String.concat ", " fm.concepts);
  line "Keywords:" (String.concat ", " fm.keywords);
  (match fm.activity_question with
   | Some q -> line "Activity:" (Parse.html_escape q)
   | None -> ());
  (match fm.think_about_this with
   | Some q -> line "Think about this:" (Parse.html_escape q)
   | None -> ());
  if fm.reading <> [] then begin
    Buffer.add_string buf "    <div class=\"meta-line\"><span class=\"meta-label\">Reading:</span><ul>\n";
    List.iter
      (fun (r : Frontmatter.reading) ->
        Buffer.add_string buf
          (Printf.sprintf
             "      <li><a href=\"%s\">%s</a></li>\n"
             (Parse.html_escape r.url) (Parse.html_escape r.title)))
      fm.reading;
    Buffer.add_string buf "    </ul></div>\n"
  end;
  Buffer.add_string buf
    "    <div class=\"meta-line\"><a href=\"privacy.html\">Privacy &amp; data collection</a></div>\n";
  Buffer.add_string buf "  </footer>\n";
  Buffer.contents buf

let runtime_script ~asset_root =
  Printf.sprintf
    {|  <script type="module">
    import Reveal from '%s/assets/reveal/dist/reveal.esm.js';

    const body = document.body;
    const modeBtn = document.querySelector('.mode-toggle');
    let reveal = null;

    function isSlideMode() {
      return location.hash === '#slides';
    }

    // Chapter-only scratch cell under each write-code Activity, so
    // readers have somewhere to attempt the task (issue #12). Skip
    // activities that already carry an interactive quiz (its student
    // cell IS the workspace). The wrapper lives in the chapter flow,
    // never inside a section[data-slide], so decks are unchanged; it
    // must be injected BEFORE slideAnchors captures nextSibling
    // anchors below, or leaving slide mode would reorder it.
    (function injectActivityScratchCells() {
      for (const section of document.querySelectorAll('section[data-slide]')) {
        const h2 = section.querySelector('h2');
        if (!h2 || h2.textContent.trim() !== 'Activity') continue;
        // Scan the activity's chapter region (up to the next slide
        // section or heading) for an existing quiz workspace.
        let hasQuiz = false;
        for (let n = section.nextElementSibling; n; n = n.nextElementSibling) {
          if (n.matches('section[data-slide], h2')) break;
          if (n.matches('.quiz') || n.querySelector?.('.quiz')) {
            hasQuiz = true;
            break;
          }
        }
        if (hasQuiz) continue;
        const wrap = document.createElement('div');
        wrap.className = 'activity-scratch';
        const label = document.createElement('p');
        label.className = 'activity-scratch-label';
        label.textContent = 'Scratchpad for the activity:';
        const cell = document.createElement('x-ocaml');
        // Same attribute shape as build-emitted cells: data-source
        // backs the per-cell reset button and edit persistence.
        cell.setAttribute('data-source', '(* try your solution here *)');
        cell.textContent = '(* try your solution here *)';
        wrap.append(label, cell);
        section.insertAdjacentElement('afterend', wrap);
      }
    })();

    // Record each slide section's original chapter-view position so we
    // can move it back when leaving slide mode.
    const slideAnchors = Array.from(document.querySelectorAll('section[data-slide]'))
      .map(node => ({ node, parent: node.parentNode, next: node.nextSibling }));

    function moveSlidesIntoReveal() {
      const wrap = document.querySelector('.reveal .slides');
      if (!wrap) return;
      for (const { node } of slideAnchors) wrap.appendChild(node);
    }
    function restoreSlidesToChapter() {
      for (const { node, parent, next } of slideAnchors) {
        parent.insertBefore(node, next);
      }
      // Undo styles reveal.js applies to html/body. They lock scrolling
      // (overflow:hidden + position:fixed via the .reveal-viewport rule)
      // and persist after our wrapper is hidden.
      document.documentElement.classList.remove('reveal-full-page');
      document.body.classList.remove('reveal-viewport');
      for (const v of ['--slide-width', '--slide-height', '--slide-scale',
                       '--viewport-width', '--viewport-height']) {
        document.body.style.removeProperty(v);
      }
    }

    function allCells() {
      return Array.from(document.querySelectorAll('x-ocaml'));
    }

    // Hide slide area until x-ocaml has finished reflowing each
    // cell. The cell starts at its plain-text height, briefly
    // shrinks, then grows when CodeMirror takes over -- ~100px of
    // motion roughly 250-400ms after page load. We don't get a
    // reliable "ready" signal from x-ocaml, so we wait for cell
    // heights to be unchanged across [quietMs] AND at least
    // [minWaitMs] of elapsed time has passed (so the initial-stable
    // phase before CodeMirror takes over does not count as settled).
    // Find the cells on whichever slide we are about to land on
    // (the saved one from sessionStorage, or slide 0 by default).
    // Cells on other slides can reflow without the user noticing.
    function cellsOnTargetSlide() {
      let targetSection = null;
      try {
        const saved = sessionStorage.getItem('nptel-slide:' + location.pathname);
        if (saved) {
          const { h } = JSON.parse(saved);
          const sections = document.querySelectorAll('section[data-slide]');
          if (typeof h === 'number' && sections[h]) targetSection = sections[h];
        }
      } catch (_) {}
      if (!targetSection) {
        targetSection = document.querySelector('section[data-slide]');
      }
      return targetSection
        ? Array.from(targetSection.querySelectorAll('x-ocaml'))
        : [];
    }

    function waitForCellsToSettle() {
      const cells = cellsOnTargetSlide();
      // No cells on the target slide -> nothing can reflow there,
      // fade in immediately.
      if (cells.length === 0) {
        document.body.classList.remove('slides-loading');
        return;
      }
      const quietMs = 180;
      const minWaitMs = 500;
      const failsafeMs = 2000;
      const startedAt = Date.now();
      let quietTimer = null;
      let done = false;
      const finish = () => {
        if (done) return;
        done = true;
        clearTimeout(quietTimer);
        clearTimeout(failsafe);
        obs.disconnect();
        document.body.classList.remove('slides-loading');
        if (reveal) { reveal.sync(); reveal.layout(); }
      };
      const armQuiet = () => {
        clearTimeout(quietTimer);
        quietTimer = setTimeout(() => {
          const elapsed = Date.now() - startedAt;
          if (elapsed >= minWaitMs) finish();
          else quietTimer = setTimeout(armQuiet, minWaitMs - elapsed);
        }, quietMs);
      };
      const obs = new ResizeObserver(armQuiet);
      for (const c of cells) obs.observe(c);
      armQuiet();
      const failsafe = setTimeout(finish, failsafeMs);
    }

    // Click the cell's shadow-DOM "Run" button. x-ocaml's internal chain
    // automatically runs predecessors that aren't Run_ok yet.
    function clickRun(cell) {
      const btn = cell.shadowRoot?.querySelector('.run_btn button');
      if (btn) btn.click();
    }

    function runAll() {
      const cells = allCells();
      if (cells.length === 0) return;
      // If the warmup suppressor wiped the FIRST cell's output, the
      // worker still considers that cell evaluated, so the upward
      // cascade below skips it and the cell looks dead. Run it
      // explicitly first when it shows no output.
      const first = cells[0];
      const firstHasOutput = first.shadowRoot?.querySelector(
        '.caml_meta, .caml_stdout, .caml_stderr, .caml_html');
      if (!firstHasOutput) clickRun(first);
      // Triggering Run on the last cell cascades upward.
      clickRun(cells[cells.length - 1]);
    }

    // "Run up to here": in slide mode "here" = last cell within or before
    // the current slide. In chapter mode it's the last cell whose top
    // is at or above the viewport center.
    function runUpToHere() {
      const cells = allCells();
      if (cells.length === 0) return;
      let target = cells[cells.length - 1];
      if (isSlideMode() && reveal) {
        const idx = reveal.getIndices();
        const sections = reveal.getSlides();
        const cur = sections[idx.h];
        // Pick the last cell whose section index is <= current.
        const eligible = cells.filter(c => {
          const sec = c.closest('section[data-slide]');
          if (!sec) return true; // outside-slide init cells always eligible
          return sections.indexOf(sec) <= sections.indexOf(cur);
        });
        if (eligible.length) target = eligible[eligible.length - 1];
      } else {
        const mid = window.innerHeight / 2;
        const eligible = cells.filter(c => c.getBoundingClientRect().top <= mid);
        if (eligible.length) target = eligible[eligible.length - 1];
      }
      clickRun(target);
    }

    // Clear by retriggering the cell's MutationObserver: set textContent
    // to its current value, which calls set_source_from_html ->
    // invalidate_from -> Editor.clear (drops all rendered messages).
    function clearAll() {
      for (const c of allCells()) {
        const txt = c.textContent;
        // Force a mutation: clear then restore. Two passes ensures the
        // observer fires even if it would dedupe identical content.
        c.textContent = '';
        c.textContent = txt;
      }
    }

    // ---------- Per-cell edit persistence via localStorage ----------
    // Key: nptel-cell:<pathname>#<hash(data-source)>:<ordinal>.
    // Keying by content rather than by position keeps a saved edit
    // attached to the cell it came from when a lecture update inserts
    // or removes cells (position-keyed edits used to reattach to
    // whichever cell inherited the index). If the cell's own source
    // changed in a republish, the stale edit is dropped, which is
    // what a republish should do. <ordinal> disambiguates twin cells
    // that share a source (a chapter cell and its slide mirror).
    // Edits are saved with a small debounce on every CodeMirror
    // mutation; reset clears the entry; identical-to-source content
    // is also cleared so we never store useless duplicates.
    const STORAGE_PREFIX = 'nptel-cell:' + location.pathname + '#';
    // djb2 over the source, in hex. Tiny and stable; collisions among
    // the handful of cells on one page are not a realistic concern.
    function srcHash(s) {
      let h = 5381;
      for (let i = 0; i < s.length; i++) {
        h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
      }
      return h.toString(16);
    }
    const cellKeys = new Map(); // cell -> full localStorage key
    function storageKey(cell) {
      if (!cellKeys.has(cell)) {
        const ords = new Map(); // hash -> next ordinal
        for (const c of allCells()) {
          const h = srcHash(c.getAttribute('data-source') ?? '');
          const ord = ords.get(h) ?? 0;
          ords.set(h, ord + 1);
          cellKeys.set(c, STORAGE_PREFIX + h + ':' + ord);
        }
      }
      return cellKeys.get(cell);
    }
    // Drop entries no current cell owns: edits orphaned by a lecture
    // update, plus keys from the old index-based scheme.
    function gcPersistedCells() {
      const live = new Set(allCells().map(storageKey));
      for (let i = localStorage.length - 1; i >= 0; i--) {
        const k = localStorage.key(i);
        if (k && k.startsWith(STORAGE_PREFIX) && !live.has(k)) {
          localStorage.removeItem(k);
        }
      }
    }
    // Read the editor's typed source by collecting [.cm-line] text only,
    // so output widgets that x-ocaml injects into the editor are not
    // mistaken for user input.
    function cellEditorText(cell) {
      const lines = cell.shadowRoot?.querySelectorAll('.cm-line');
      if (!lines || lines.length === 0) return null;
      return Array.from(lines).map(l => l.textContent).join('\n');
    }
    function dirtyButton(cell) {
      // Reset button sits inside the [.cell-wrap] that wraps the cell.
      const wrap = cell.parentElement;
      return wrap?.classList?.contains('cell-wrap')
        ? wrap.querySelector('.reset-cell')
        : null;
    }
    function persistCell(cell) {
      const src = cell.getAttribute('data-source') ?? '';
      const cur = cellEditorText(cell);
      if (cur == null) return;
      const btn = dirtyButton(cell);
      if (cur.trim() === src.trim()) {
        localStorage.removeItem(storageKey(cell));
        btn?.classList.remove('dirty');
      } else {
        localStorage.setItem(storageKey(cell), cur);
        btn?.classList.add('dirty');
      }
    }
    const persistTimers = new Map();
    const pendingCells = new Set();
    function schedulePersist(cell) {
      pendingCells.add(cell);
      clearTimeout(persistTimers.get(cell));
      persistTimers.set(cell, setTimeout(() => {
        persistCell(cell);
        pendingCells.delete(cell);
        persistTimers.delete(cell);
      }, 400));
    }
    function flushPendingPersists() {
      for (const cell of pendingCells) {
        clearTimeout(persistTimers.get(cell));
        persistCell(cell);
      }
      pendingCells.clear();
      persistTimers.clear();
    }
    function watchCellForEdits(cell) {
      // Use [input] events on the editor's contenteditable surface
      // rather than a MutationObserver: [input] fires only on user
      // typing, not on programmatic DOM changes from output widgets.
      // This avoids two failure modes: saving widget text as "source",
      // and looping when x-ocaml re-renders the editor after persist.
      const ed = cell.shadowRoot?.querySelector('.cm-content');
      if (!ed) return;
      ed.addEventListener('input', () => {
        // Mark dirty immediately for instant visual feedback; the
        // actual localStorage write is debounced.
        dirtyButton(cell)?.classList.add('dirty');
        schedulePersist(cell);
      });
    }
    // Flush any pending debounced writes when the page is being
    // hidden or unloaded, so a quick Cmd+R after typing doesn't lose
    // the edit. [pagehide] fires more reliably than [beforeunload]
    // on mobile and bfcache transitions.
    window.addEventListener('pagehide', flushPendingPersists);
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') flushPendingPersists();
    });
    function restorePersistedCells() {
      gcPersistedCells();
      for (const cell of allCells()) {
        const saved = localStorage.getItem(storageKey(cell));
        if (saved !== null && saved !== cell.getAttribute('data-source')) {
          cell.textContent = saved;
          dirtyButton(cell)?.classList.add('dirty');
        }
      }
    }

    // Restore a cell to the source it was emitted with (carried on the
    // [data-source] attribute). The MutationObserver picks up the
    // textContent change and re-syncs the editor. Also clears the
    // persisted edit, if any.
    function resetCell(cell) {
      const src = cell.getAttribute('data-source');
      if (src === null) return;
      cell.textContent = src;
      localStorage.removeItem(storageKey(cell));
      dirtyButton(cell)?.classList.remove('dirty');
    }
    function resetAll() {
      for (const c of allCells()) resetCell(c);
    }

    // Wrap each cell in a [.cell-wrap] div and add the reset (↺)
    // button inside that wrapper. The wrapper has position:relative;
    // the reset button has position:absolute at top-right, just left
    // of the Run button (which lives in the cell's shadow DOM).
    function injectResetButtons() {
      for (const cell of allCells()) {
        if (cell.parentElement?.classList?.contains('cell-wrap')) continue;
        // Hidden quiz-test cells don't get a wrap+reset: there's no
        // point resetting a fixed test, and the absolutely-positioned
        // reset button would otherwise float beneath the quiz.
        if (cell.hasAttribute('data-quiz-test')) continue;
        const wrap = document.createElement('div');
        wrap.className = 'cell-wrap';
        cell.parentNode.insertBefore(wrap, cell);
        wrap.appendChild(cell);
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'reset-cell';
        btn.title = 'Reset this cell to its source';
        btn.textContent = '↺';
        btn.addEventListener('click', () => resetCell(cell));
        wrap.appendChild(btn);
      }
    }
    injectResetButtons();

    // After x-ocaml upgrades each cell (Run button appears in shadow),
    // wire persistence and restore any saved edits.
    // x-ocaml warms up its worker by auto-evaluating the FIRST
    // cell on the page once its runtime is ready. That auto-eval
    // happens AFTER our initial clearAll(), so the first cell can
    // show stale-looking output on a fresh page load. To suppress
    // it without interfering with anything else, we watch only the
    // first cell's shadow DOM for new output, and clear it once if
    // it appears before the reader has interacted with any cell.
    let userInteracted = false;
    function watchRunButton(cell) {
      const btn = cell.shadowRoot?.querySelector('.run_btn button');
      if (!btn) return;
      btn.addEventListener('click', () => { userInteracted = true; });
    }
    function suppressFirstCellAutoWarmup() {
      const first = allCells()[0];
      if (!first) return;
      const sr = first.shadowRoot;
      if (!sr) return;
      let cleared = false;
      const obs = new MutationObserver(() => {
        if (cleared) return;
        if (userInteracted) { obs.disconnect(); return; }
        const hasOutput = sr.querySelector(
          '.caml_meta, .caml_stdout, .caml_stderr, .caml_html');
        if (hasOutput) {
          // x-ocaml's auto-warmup output. Clear once.
          const txt = first.textContent;
          first.textContent = '';
          first.textContent = txt;
          cleared = true;
          obs.disconnect();
        }
      });
      obs.observe(sr, { childList: true, subtree: true });
      // Safety: stop watching after 10s regardless. x-ocaml's
      // warmup is much faster than this; if it hasn't fired by then
      // it probably will not.
      setTimeout(() => obs.disconnect(), 10000);
    }

    // Reserve a right-hand strip inside each cell's editor so code
    // never slides under the floating Run / reset buttons. Injected
    // host-side into the cell's open shadow root because the x-oxcaml
    // bundle predates the loader's [src-style] attribute; this path
    // covers both bundles uniformly. The width comes from a custom
    // property set per mode in chapter.css (custom properties inherit
    // into shadow trees): 5.6rem in chapter mode, 0 in slide mode so
    // recorded decks keep their exact geometry.
    function injectCellStyle(cell) {
      const sr = cell.shadowRoot;
      if (!sr || sr.querySelector('style[data-nptel-cell-style]')) return;
      const st = document.createElement('style');
      st.setAttribute('data-nptel-cell-style', '');
      st.textContent =
        '.cm-editor { padding-right: var(--x-ocaml-editor-pad, 0); ' +
        'box-sizing: border-box; }';
      sr.appendChild(st);
    }

    async function whenCellsReady() {
      while (true) {
        const ready = allCells().every(c => c.shadowRoot?.querySelector('.cm-content'));
        if (ready) break;
        await new Promise(r => setTimeout(r, 100));
      }
      restorePersistedCells();
      for (const c of allCells()) {
        injectCellStyle(c);
        watchCellForEdits(c);
        watchRunButton(c);
      }
      // Wipe any stale output left over from previous sessions.
      clearAll();
      // x-ocaml may then auto-warm the first cell; suppress that.
      suppressFirstCellAutoWarmup();
      // Code quizzes can now find the test cell's shadow Run button.
      setupCodeQuizzes();
    }
    whenCellsReady();

    // The toolbar run buttons count as interaction too; otherwise
    // the warmup suppressor above can eat the FIRST cell's output
    // when "Run all" is clicked within its 10s watch window, and
    // the first cell looks dead until run individually.
    document.querySelector('.run-all')?.addEventListener('click', () => {
      userInteracted = true; runAll();
    });
    document.querySelector('.run-up-to-here')?.addEventListener('click', () => {
      userInteracted = true; runUpToHere();
    });
    document.querySelector('.clear-all')?.addEventListener('click', clearAll);
    document.querySelector('.reset-all')?.addEventListener('click', resetAll);

    // ---------- Keep the running cell steady in the viewport ----------
    // Running a cell re-runs its not-yet-run predecessors, whose
    // output panes grow ABOVE the cell the reader is looking at, so
    // the content under the cursor slides down (the page "scrolls
    // up"). Chrome's scroll anchoring compensates only partially and
    // Safari not at all. Pin the clicked cell's viewport offset for a
    // settling window; abort as soon as the reader scrolls or types.
    function pinDuringRun(cell) {
      const top0 = cell.getBoundingClientRect().top;
      const ac = new AbortController();
      for (const t of ['wheel', 'touchstart', 'keydown']) {
        addEventListener(t, () => ac.abort(),
          { passive: true, signal: ac.signal });
      }
      const t0 = performance.now();
      (function tick() {
        if (ac.signal.aborted || performance.now() - t0 > 6000) {
          ac.abort();
          return;
        }
        const d = cell.getBoundingClientRect().top - top0;
        if (d) scrollBy(0, d);
        requestAnimationFrame(tick);
      })();
    }
    document.addEventListener('click', (ev) => {
      // Composed path pierces x-ocaml's open shadow root, so this
      // sees clicks on the in-cell Run button (and the programmatic
      // .click() the quiz Check button sends).
      const path = ev.composedPath();
      const onRunBtn = path.some(n =>
        n.nodeType === 1 && n.tagName === 'BUTTON' &&
        n.parentElement?.classList?.contains('run_btn'));
      if (!onRunBtn) return;
      const cell = path.find(n => n.nodeType === 1 && n.tagName === 'X-OCAML');
      if (cell) pinDuringRun(cell);
    }, true);

    // Cmd-Enter (mac) / Ctrl-Enter runs the cell being edited, the
    // shortcut every notebook UI trains. Composed path finds the
    // cell around the focused editor inside the shadow root.
    document.addEventListener('keydown', (ev) => {
      if (ev.key !== 'Enter' || !(ev.metaKey || ev.ctrlKey)) return;
      const cell = ev.composedPath().find(n =>
        n.nodeType === 1 && n.tagName === 'X-OCAML');
      if (!cell) return;
      ev.preventDefault();
      userInteracted = true;
      pinDuringRun(cell);
      clickRun(cell);
    }, true);

    // ---------- Quiz analytics (anonymous, opt-in) ----------
    // Default: NO data is sent until the reader explicitly opts in
    // via the consent banner on first visit. Following Crichton et
    // al.'s methodology in the TRPL inline-quiz study (which used
    // opt-in consent and still collected 62k+ responses), we ask
    // up front and respect the answer. The opt-in choice is stored
    // in localStorage as [nptel-analytics-consent] = "yes" | "no";
    // any other value (including missing) is treated as "not yet
    // decided" and reportQuiz() is a no-op.
    //
    // The privacy page (privacy.html) lets the reader flip the
    // choice at any time, export everything we have for their
    // UUID, or delete it all.
    //
    // POLICY_VERSION bumps if we materially change what is
    // collected; readers re-consent at the next bump.
    const POLICY_VERSION = '2026-05-20';

    const QUIZ_API = document.querySelector(
      'meta[name="quiz-api"]')?.getAttribute('content') || '';
    const COMMIT_SHA = document.querySelector(
      'meta[name="commit-sha"]')?.getAttribute('content') || '';

    function analyticsConsent() {
      if (!QUIZ_API) return 'no-api';
      const v = localStorage.getItem('nptel-analytics-consent');
      const at = localStorage.getItem('nptel-analytics-consent-version');
      if (v !== 'yes' && v !== 'no') return 'pending';
      if (at !== POLICY_VERSION) return 'pending';
      return v;
    }
    function setConsent(v) {
      try {
        localStorage.setItem('nptel-analytics-consent', v);
        localStorage.setItem('nptel-analytics-consent-version', POLICY_VERSION);
        localStorage.setItem('nptel-analytics-consent-ts', new Date().toISOString());
      } catch (_) {}
    }
    function readerUuid() {
      let id = localStorage.getItem('nptel-reader-uuid');
      if (!id) {
        id = (crypto?.randomUUID?.() ?? Math.random().toString(36).slice(2));
        localStorage.setItem('nptel-reader-uuid', id);
      }
      return id;
    }
    function reportQuiz(payload) {
      // Opt-in: only post when the reader has explicitly said yes
      // for the current policy version.
      if (analyticsConsent() !== 'yes') return;
      try {
        fetch(QUIZ_API + '/quiz', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            reader_uuid: readerUuid(),
            commit_sha: COMMIT_SHA,
            page: location.pathname,
            ...payload,
          }),
          keepalive: true,
        }).catch(() => {});
      } catch (_) {}
    }

    // First-visit consent banner (opt-in). Stays visible until the
    // reader explicitly picks Allow or Decline; can be summoned
    // again from the privacy page if dismissed accidentally.
    // Bypassed entirely if the page has no quiz-api configured.
    function showConsentIfPending() {
      if (analyticsConsent() !== 'pending') return;
      const banner = document.createElement('div');
      banner.className = 'privacy-banner';
      banner.innerHTML =
        '<p><strong>Help improve this course?</strong></p>' +
        '<p>With your consent, the site records <strong>anonymous</strong> ' +
        'responses to the inline quizzes so we can see which questions ' +
        'are hardest and revise the surrounding material. No name, ' +
        'no email, no IP address. ' +
        '<a href="privacy.html">What we collect</a>.</p>' +
        '<div class="privacy-actions">' +
        '<button type="button" class="privacy-allow">Allow</button> ' +
        '<button type="button" class="privacy-decline">Not now</button>' +
        '</div>';
      document.body.appendChild(banner);
      banner.querySelector('.privacy-allow')?.addEventListener('click', () => {
        setConsent('yes'); banner.remove();
      });
      banner.querySelector('.privacy-decline')?.addEventListener('click', () => {
        setConsent('no'); banner.remove();
      });
    }
    showConsentIfPending();

    // ---------- Inline quizzes ----------
    // Two kinds: [.quiz-mcq] and [.quiz-code]. Authored as
    // [:::quiz mcq] / [:::quiz code] fenced divs; the build emits the
    // wrapper [.quiz] div, CommonMark renders the body. The runtime
    // here turns the rendered body into an interactive widget. State
    // persists in localStorage under [nptel-quiz:<path>#<id>].
    const QUIZ_PREFIX = 'nptel-quiz:' + location.pathname + '#';

    // MCQ: GFM task lists give us [<li><input type="checkbox" [checked] disabled> ...]
    // We strip the checkboxes, build radio inputs in their place, and
    // reveal the explanation block (everything after the [<ul>]) on
    // selection. Correctness is decided by which option carried the
    // [checked] attribute in the source.
    function setupMcqQuiz(quiz) {
      const id = quiz.dataset.quizId;
      const ul = quiz.querySelector('ul');
      if (!ul) return;
      const items = Array.from(ul.querySelectorAll(':scope > li'));
      if (items.length === 0) return;
      const fieldset = document.createElement('fieldset');
      fieldset.className = 'quiz-choices';
      items.forEach((li, idx) => {
        const cb = li.querySelector('input[type="checkbox"]');
        const isCorrect = !!cb && cb.hasAttribute('checked');
        cb?.remove();
        const label = document.createElement('label');
        label.className = 'quiz-choice';
        const radio = document.createElement('input');
        radio.type = 'radio';
        radio.name = 'quiz-' + id;
        radio.value = String(idx);
        if (isCorrect) radio.dataset.correct = 'true';
        label.appendChild(radio);
        const text = document.createElement('span');
        text.className = 'quiz-choice-text';
        text.innerHTML = li.innerHTML.trim();
        label.appendChild(text);
        fieldset.appendChild(label);
      });
      // Collect everything after the <ul> as the explanation.
      const exp = document.createElement('div');
      exp.className = 'quiz-explanation';
      let n = ul.nextSibling;
      while (n) {
        const next = n.nextSibling;
        exp.appendChild(n);
        n = next;
      }
      ul.replaceWith(fieldset);
      quiz.appendChild(exp);

      function applySelection(idx) {
        const radios = fieldset.querySelectorAll('input[type="radio"]');
        if (idx == null || !radios[idx]) return false;
        radios[idx].checked = true;
        const isCorrect = radios[idx].dataset.correct === 'true';
        fieldset.querySelectorAll('.quiz-choice').forEach((label, i) => {
          const r = label.querySelector('input');
          label.classList.toggle('selected', i === idx);
          label.classList.toggle('correct', r.dataset.correct === 'true');
          label.classList.toggle('wrong', i === idx && !isCorrect);
        });
        quiz.classList.add('answered');
        quiz.classList.toggle('quiz-correct', isCorrect);
        return isCorrect;
      }
      fieldset.addEventListener('change', e => {
        if (e.target.type !== 'radio') return;
        const idx = parseInt(e.target.value);
        const isCorrect = applySelection(idx);
        try {
          localStorage.setItem(QUIZ_PREFIX + id,
            JSON.stringify({ kind: 'mcq', selected: idx, correct: isCorrect }));
        } catch (_) {}
        const line = parseInt(quiz.dataset.quizLine || '', 10);
        reportQuiz({
          quiz_id: location.pathname + '#' + id,
          kind: 'mcq',
          selected: idx,
          correct: isCorrect,
          line: Number.isFinite(line) ? line : null,
        });
      });
      // Restore prior attempt.
      try {
        const saved = localStorage.getItem(QUIZ_PREFIX + id);
        if (saved) {
          const { selected } = JSON.parse(saved);
          applySelection(selected);
        }
      } catch (_) {}
    }

    // Code quiz: visible <x-ocaml> (student cell) + hidden
    // <x-ocaml data-quiz-test> (assert block). We add a Check button
    // and a "Show tests" disclosure. Check clicks the test cell's
    // shadow Run button; x-ocaml's chaining runs the student cell
    // first as a predecessor. We poll the test cell's shadow DOM
    // for the success print or an exception.
    function setupCodeQuiz(quiz) {
      const id = quiz.dataset.quizId;
      const cells = Array.from(quiz.querySelectorAll('x-ocaml'));
      const testCell = cells.find(c => c.hasAttribute('data-quiz-test'));
      // The student cell is the LAST visible cell: a question may
      // legitimately contain an earlier display fence.
      const nonTest = cells.filter(c => !c.hasAttribute('data-quiz-test'));
      const studentCell = nonTest[nonTest.length - 1];
      if (!studentCell || !testCell) return;
      if (quiz.querySelector('.quiz-controls')) return;  // already set up

      const controls = document.createElement('div');
      controls.className = 'quiz-controls';
      const checkBtn = document.createElement('button');
      checkBtn.type = 'button';
      checkBtn.className = 'quiz-check';
      checkBtn.textContent = 'Check';
      const showBtn = document.createElement('button');
      showBtn.type = 'button';
      showBtn.className = 'quiz-show-tests';
      showBtn.textContent = '▸ Show tests';
      const status = document.createElement('span');
      status.className = 'quiz-status';
      controls.append(checkBtn, showBtn, status);
      // Place controls after the student cell's wrapper.
      const wrap = studentCell.closest('.cell-wrap') || studentCell;
      wrap.parentNode.insertBefore(controls, wrap.nextSibling);

      function clickRun(cell) {
        const btn = cell.shadowRoot?.querySelector('.run_btn button');
        if (btn) btn.click();
      }
      function readState() {
        // Look at x-ocaml's OUTPUT panes only, not the source. The
        // editor's [.cm-content] contains the source text verbatim,
        // which would trivially match "all tests passed" before the
        // cell even ran. x-ocaml renders output into separate
        // [.caml_stdout], [.caml_stderr], and [.caml_meta] elements.
        const sr = testCell.shadowRoot;
        if (!sr) return 'pending';
        const out = Array.from(
          sr.querySelectorAll('.caml_stdout, .caml_stderr, .caml_meta')
        ).map(e => e.textContent || '').join('\n');
        if (!out) return 'pending';
        // Failure patterns FIRST. The toplevel evaluates each phrase
        // independently and continues past exceptions, so a stray
        // success print in a later phrase must not outvote an earlier
        // failure. This relies on two test-cell conventions: (1) the
        // whole suite is ONE [let () = ...] phrase whose last action
        // is the success print (a failure aborts the phrase before
        // the print), and (2) test cells never echo values ([let _ =]
        // bindings), whose rendering could false-match the failure
        // patterns (e.g. a constructor named [Error]).
        if (/Error|Exception|Failure|Assertion/i.test(out)) return 'fail';
        if (/all tests pass/i.test(out)) return 'pass';
        return 'pending';
      }
      // On failure, name the failing check in the status line: the
      // check helper raises [Failure "<label>"], and a non-compiling
      // student cell surfaces a compiler "Error: ..." line. A bare
      // "Some assertions failed" told the student nothing (#14).
      function firstFailureLine() {
        const sr = testCell.shadowRoot;
        if (!sr) return null;
        const out = Array.from(
          sr.querySelectorAll('.caml_stdout, .caml_stderr, .caml_meta')
        ).map(e => e.textContent || '').join('\n');
        const line = out.split('\n')
          .find(l => /Error|Exception|Failure|Assertion/i.test(l));
        if (!line) return null;
        const f = line.match(/Failure\s+"([^"]*)"/);
        if (f) return 'failed: ' + f[1];
        const s = line.trim();
        return s.length > 110 ? s.slice(0, 107) + '…' : s;
      }
      function setShowTests(show) {
        quiz.classList.toggle('show-tests', show);
        showBtn.textContent = show ? '▾ Hide tests' : '▸ Show tests';
      }
      showBtn.addEventListener('click', () => {
        setShowTests(!quiz.classList.contains('show-tests'));
      });
      checkBtn.addEventListener('click', () => {
        status.textContent = 'Running…';
        status.className = 'quiz-status running';
        // Blank stale output from a previous run, else readState
        // reads the OLD verdict before the new run lands (a second
        // Check after a pass reported pass regardless of edits).
        // Blank rather than remove: x-ocaml re-renders into fresh
        // panes on the re-run this Check triggers.
        testCell.shadowRoot
          ?.querySelectorAll('.caml_stdout, .caml_stderr, .caml_meta')
          .forEach(e => { e.textContent = ''; });
        clickRun(testCell);
        let tries = 0;
        const tick = setInterval(() => {
          tries++;
          const s = readState();
          if (s !== 'pending' || tries > 80) {
            clearInterval(tick);
            if (s === 'pass') {
              status.textContent = '✓ All tests pass';
              status.className = 'quiz-status pass';
              quiz.classList.add('answered', 'quiz-correct');
              try {
                localStorage.setItem(QUIZ_PREFIX + id,
                  JSON.stringify({ kind: 'code', passed: true }));
              } catch (_) {}
              {
                const line = parseInt(quiz.dataset.quizLine || '', 10);
                reportQuiz({
                  quiz_id: location.pathname + '#' + id,
                  kind: 'code', passed: true, correct: true,
                  line: Number.isFinite(line) ? line : null,
                });
              }
            } else if (s === 'fail') {
              const why = firstFailureLine();
              status.textContent =
                why ? '✗ ' + why : '✗ Some assertions failed';
              status.className = 'quiz-status fail';
              quiz.classList.remove('quiz-correct');
              quiz.classList.add('answered');
              // Auto-reveal tests so the student can see what failed.
              setShowTests(true);
              try {
                localStorage.setItem(QUIZ_PREFIX + id,
                  JSON.stringify({ kind: 'code', passed: false }));
              } catch (_) {}
              {
                const line = parseInt(quiz.dataset.quizLine || '', 10);
                reportQuiz({
                  quiz_id: location.pathname + '#' + id,
                  kind: 'code', passed: false, correct: false,
                  line: Number.isFinite(line) ? line : null,
                });
              }
            } else {
              // tools/quiz-verdict.mjs recognizes this exact timeout text.
              // Update its retry check and tests if this wording changes.
              status.textContent = 'Timed out';
              status.className = 'quiz-status fail';
            }
          }
        }, 200);
      });
      // Restore prior result.
      try {
        const saved = localStorage.getItem(QUIZ_PREFIX + id);
        if (saved) {
          const { passed } = JSON.parse(saved);
          if (passed) {
            status.textContent = '✓ Passed previously';
            status.className = 'quiz-status pass';
            quiz.classList.add('answered', 'quiz-correct');
          }
        }
      } catch (_) {}
    }

    // ---------- Heading permalinks ----------
    // Each h2/h3/h4 inside the chapter body gets a slug-id and a
    // hover-visible "permalink" anchor, so readers can deep-link
    // to a section. Slugs are derived from heading text in the
    // standard lowercase-dashed convention.
    function slugify(s) {
      return (s || '').toLowerCase()
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 80);
    }
    function setupHeadingAnchors() {
      const seen = Object.create(null);
      const headings = document.querySelectorAll(
        '.chapter h2, .chapter h3, .chapter h4');
      for (const h of headings) {
        // Strip any existing permalink we may have already added,
        // so it doesn't end up in the slug source.
        const old = h.querySelector('.permalink');
        if (old) old.remove();
        let id = h.id || slugify(h.textContent);
        if (!id) continue;
        // Collision suffix if two headings hash to the same slug.
        if (seen[id]) {
          let i = 2;
          while (seen[id + '-' + i]) i++;
          id = id + '-' + i;
        }
        seen[id] = true;
        h.id = id;
        const a = document.createElement('a');
        a.className = 'permalink';
        a.href = '#' + id;
        a.textContent = '¶';
        a.setAttribute('aria-label', 'Permalink to ' + h.textContent.trim());
        a.setAttribute('title', 'Copy link to this section');
        h.appendChild(a);
      }
    }
    setupHeadingAnchors();

    // ---------- On-this-page TOC (chapter mode only) ----------
    // Built from the prose section headings (h2/h3 that are NOT inside
    // a slide callout), reusing the ids setupHeadingAnchors() just
    // assigned so every TOC link matches its permalink anchor. Styled
    // and hidden-by-context (slides / print / narrow) entirely in CSS.
    const TOC_KEY = 'nptel-toc-collapsed';
    function headingLabel(h) {
      // h.textContent now includes the trailing permalink glyph; drop it.
      const clone = h.cloneNode(true);
      const pl = clone.querySelector('.permalink');
      if (pl) pl.remove();
      return clone.textContent.trim();
    }
    function buildToc() {
      const heads = Array.from(
        document.querySelectorAll('.chapter h2, .chapter h3'))
        .filter(h => h.id && !h.closest('section.slide'));
      // Short lectures don't need an outline.
      if (heads.length < 3) return;

      const nav = document.createElement('nav');
      nav.className = 'toc chapter-only';
      nav.setAttribute('aria-label', 'On this page');

      const head = document.createElement('div');
      head.className = 'toc-head';
      const title = document.createElement('span');
      title.className = 'toc-title';
      title.textContent = 'On this page';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'toc-collapse';
      head.appendChild(title);
      head.appendChild(btn);

      const list = document.createElement('ul');
      list.className = 'toc-body';
      const linkFor = Object.create(null);
      for (const h of heads) {
        const li = document.createElement('li');
        li.className = (h.tagName === 'H3') ? 'toc-h3' : 'toc-h2';
        const a = document.createElement('a');
        a.href = '#' + h.id;
        a.textContent = headingLabel(h);
        li.appendChild(a);
        list.appendChild(li);
        linkFor[h.id] = a;
      }
      nav.appendChild(head);
      nav.appendChild(list);
      body.appendChild(nav);

      // Collapse toggle, persisted like the left sidebar.
      function applyCollapsed(c) {
        nav.classList.toggle('collapsed', c);
        btn.setAttribute('aria-label', c ? 'Show contents' : 'Collapse contents');
        btn.setAttribute('title', c ? 'Show contents' : 'Collapse contents');
      }
      applyCollapsed(localStorage.getItem(TOC_KEY) === '1');
      btn.addEventListener('click', () => {
        const c = !nav.classList.contains('collapsed');
        applyCollapsed(c);
        localStorage.setItem(TOC_KEY, c ? '1' : '0');
      });

      // Scroll-spy: active = the last heading whose top has scrolled
      // above a line just under the sticky header. Deterministic scan
      // (heads is short); the IntersectionObserver is only a cheap
      // "something crossed the viewport" trigger.
      const SPY_OFFSET = 96;
      let active = null;
      function setActive(id) {
        if (id === active) return;
        if (active && linkFor[active]) linkFor[active].classList.remove('active');
        active = id;
        if (active && linkFor[active]) linkFor[active].classList.add('active');
      }
      function updateActive() {
        let current = heads[0];
        for (const h of heads) {
          if (h.getBoundingClientRect().top - SPY_OFFSET <= 0) current = h;
          else break;
        }
        setActive(current.id);
      }
      const io = new IntersectionObserver(updateActive, { threshold: 0 });
      for (const h of heads) io.observe(h);
      updateActive();
    }
    buildToc();

    function setupMcqQuizzes() {
      document.querySelectorAll('.quiz-mcq').forEach(setupMcqQuiz);
    }
    function setupCodeQuizzes() {
      document.querySelectorAll('.quiz-code').forEach(setupCodeQuiz);
    }
    setupMcqQuizzes();
    // Code quizzes need the test cell's shadow Run button to exist;
    // setupCodeQuizzes is therefore deferred until cells are ready
    // (see [whenCellsReady] below).

    // Sidebar collapse, with persistence across pages.
    const SIDEBAR_KEY = 'nptel-sidebar-hidden';
    function applySidebarHidden(hidden) {
      document.body.classList.toggle('sidebar-hidden', hidden);
    }
    applySidebarHidden(localStorage.getItem(SIDEBAR_KEY) === '1');
    function toggleSidebar() {
      const hidden = !document.body.classList.contains('sidebar-hidden');
      applySidebarHidden(hidden);
      localStorage.setItem(SIDEBAR_KEY, hidden ? '1' : '0');
    }
    document.querySelector('.sidebar-collapse')?.addEventListener('click', toggleSidebar);

    function syncMode() {
      const slide = isSlideMode();
      body.classList.toggle('mode-slides', slide);
      body.classList.toggle('mode-chapter', !slide);

      if (slide) {
        moveSlidesIntoReveal();
        if (!reveal) {
          body.classList.add('slides-loading');
          waitForCellsToSettle();
          reveal = new Reveal({
            embedded: false, hash: false, history: false,
            // Show "N / M" badge in the bottom-right corner. Counts
            // every slide including verticals (subslides).
            slideNumber: 'c/t',
            // Larger canvas than the reveal.js default (960x700)
            // so slides with a tall diagram plus bullets do not
            // overflow. reveal.js then auto-scales the canvas to
            // fit the viewport, so this is a content budget, not
            // a rendering size.
            //
            // minScale=0.1 lets the slide shrink well below the
            // canvas size on small viewports. maxScale=1.5 lets the
            // slide grow on wider monitors (the canvas at 1.5x is
            // about the width of a typical laptop screen) without
            // ballooning to the reveal.js default of 2.0, which
            // defeats Cmd+- until you hit 50%% browser zoom.
            width: 1280, height: 800, minScale: 0.1, maxScale: 1.5,
            // Without this, arrow keys while typing in an x-ocaml cell
            // also navigate slides. Shadow DOM hides the inner
            // contenteditable from document.activeElement (which sees
            // only the host <x-ocaml>), so reveal.js's built-in
            // "ignore inputs" check misses it.
            keyboardCondition: (_e) => {
              const ae = document.activeElement;
              if (ae && ae.tagName === 'X-OCAML') return false;
              // Walk into nested shadow roots in case future cells
              // are wrapped in other custom elements.
              let inner = ae && ae.shadowRoot && ae.shadowRoot.activeElement;
              while (inner && inner.shadowRoot && inner.shadowRoot.activeElement) {
                inner = inner.shadowRoot.activeElement;
              }
              if (inner && (inner.isContentEditable
                            || inner.tagName === 'TEXTAREA'
                            || inner.tagName === 'INPUT')) return false;
              return true;
            },
          });
          reveal.initialize().then(() => {
            // Restore last-viewed slide indices for this page from
            // sessionStorage so a refresh keeps your place.
            try {
              const key = 'nptel-slide:' + location.pathname;
              const saved = sessionStorage.getItem(key);
              if (saved) {
                const { h, v } = JSON.parse(saved);
                if (typeof h === 'number') reveal.slide(h, v ?? 0);
              }
            } catch (_) {}
            reveal.on('slidechanged', () => {
              try {
                const { h, v } = reveal.getIndices();
                sessionStorage.setItem(
                  'nptel-slide:' + location.pathname,
                  JSON.stringify({ h, v }));
              } catch (_) {}
              // Re-run KaTeX in case the slide contains math that
              // wasn't rendered on initial load (e.g. slides hidden
              // by reveal.js's display:none before first present).
              if (typeof renderMathInDocument === 'function') {
                try { renderMathInDocument(); } catch (_) {}
              }
            });
            // Reveal computes each section's vertical centering at
            // slidechange time. If a cell expands its output after
            // the slide is already on screen (the common case when
            // the user clicks Run on the current slide), the
            // section's top stays at the pre-expansion value and the
            // grown content drifts off the bottom of the canvas. A
            // ResizeObserver on each section triggers reveal.layout()
            // when content size changes, recentering the slide.
            let layoutPending = false;
            const requestLayout = () => {
              if (layoutPending) return;
              layoutPending = true;
              requestAnimationFrame(() => {
                layoutPending = false;
                reveal.layout();
              });
            };
            const ro = new ResizeObserver(requestLayout);
            for (const sec of document.querySelectorAll('.reveal .slides section[data-slide]')) {
              ro.observe(sec);
            }
          });
          // expose for testing / diagnostics
          window.Reveal = reveal;
        } else {
          reveal.sync();
          reveal.layout();
        }
      } else {
        restoreSlidesToChapter();
      }
    }

    modeBtn?.addEventListener('click', () => {
      if (isSlideMode()) {
        // Drop the trailing '#' cleanly; setting location.hash = '' keeps it.
        history.replaceState(null, '', location.pathname + location.search);
        syncMode();
      } else {
        location.hash = 'slides';
      }
    });
    window.addEventListener('hashchange', syncMode);
    syncMode();
  </script>|}
    asset_root

let render_sidebar ~(manifest : Manifest.t option) =
  match manifest with
  | None -> ""
  | Some m ->
      let buf = Buffer.create 2048 in
      Buffer.add_string buf "<aside class=\"sidebar chapter-only\">\n";
      Buffer.add_string buf
        "  <nav class=\"sidebar-nav\" aria-label=\"Course outline\">\n";
      Buffer.add_string buf
        "    <div class=\"sidebar-title\">Course outline</div>\n";
      (* Lecture numbering is per-module: each module's lectures
         start at L01. The entry's [lecture] field comes from the
         filename's [Lnn] segment. *)
      List.iter
        (fun (w : Manifest.week) ->
          let has_current =
            List.exists (fun (e : Manifest.entry) -> e.slug = m.current_slug)
              w.lectures
          in
          let opened = if has_current then " open" else "" in
          Buffer.add_string buf
            (Printf.sprintf "    <details class=\"sidebar-week\"%s>\n" opened);
          Buffer.add_string buf
            (Printf.sprintf
               "      <summary><span class=\"week-no\">M%02d</span> %s</summary>\n"
               w.week_no (Parse.html_escape w.week_title));
          Buffer.add_string buf "      <ul class=\"sidebar-lectures\">\n";
          List.iter
            (fun (e : Manifest.entry) ->
              let cls =
                if e.slug = m.current_slug then " class=\"current\"" else ""
              in
              Buffer.add_string buf
                (Printf.sprintf
                   "        <li%s><a href=\"%s.html\"><span \
                    class=\"lec-no\">L%02d</span> %s</a></li>\n"
                   cls e.slug e.lecture (Parse.html_escape e.title)))
            w.lectures;
          Buffer.add_string buf "      </ul>\n";
          Buffer.add_string buf "    </details>\n")
        m.weeks;
      Buffer.add_string buf "  </nav>\n";
      Buffer.add_string buf "</aside>\n";
      Buffer.contents buf

let render_prev_next ~(manifest : Manifest.t option) =
  match manifest with
  | None -> ""
  | Some m ->
      let prev, next = Manifest.neighbors m in
      (* Prev/next labels use per-module lecture numbers (M02 &middot; L03)
         to match the sidebar and the slide title. *)
      let label_of (e : Manifest.entry) =
        Printf.sprintf "M%02d &middot; L%02d" e.week e.lecture
      in
      let buf = Buffer.create 256 in
      Buffer.add_string buf
        "<nav class=\"prev-next chapter-only\" aria-label=\"Lecture navigation\">\n";
      (match prev with
       | Some (e : Manifest.entry) ->
           Buffer.add_string buf
             (Printf.sprintf
                "  <a class=\"prev\" href=\"%s.html\">&larr; <span \
                 class=\"label\">Previous</span> <span \
                 class=\"sub\">%s &middot; %s</span></a>\n"
                e.slug (label_of e) (Parse.html_escape e.title))
       | None -> Buffer.add_string buf "  <span class=\"prev disabled\"></span>\n");
      (match next with
       | Some (e : Manifest.entry) ->
           Buffer.add_string buf
             (Printf.sprintf
                "  <a class=\"next\" href=\"%s.html\"><span \
                 class=\"label\">Next</span> <span class=\"sub\">%s \
                 &middot; %s</span> &rarr;</a>\n"
                e.slug (label_of e) (Parse.html_escape e.title))
       | None -> Buffer.add_string buf "  <span class=\"next disabled\"></span>\n");
      Buffer.add_string buf "</nav>\n";
      Buffer.contents buf

(* A page has a slide deck iff at least one slide section was
   emitted. Practice chapters carry no [:::slide] blocks. *)
let body_has_slides html_body =
  let needle = "data-slide" in
  let nlen = String.length needle in
  let blen = String.length html_body in
  let rec scan i =
    if i + nlen > blen then false
    else if String.sub html_body i nlen = needle then true
    else scan (i + 1)
  in
  scan 0

(* A page carries the in-browser VM terminal iff the body has a
   [:::vm-terminal] div (class emitted by Divs.preprocess). *)
let body_has_vm_terminal html_body =
  let needle = "class=\"vm-terminal\"" in
  let nlen = String.length needle in
  let blen = String.length html_body in
  let rec scan i =
    if i + nlen > blen then false
    else if String.sub html_body i nlen = needle then true
    else scan (i + 1)
  in
  scan 0

(* The runtime mounts a paused player online, retaining a link offline. *)
let with_lecture_video ~(fm : Frontmatter.t) html =
  match fm.youtube_id with
  | None -> html
  | Some id ->
      let card = Printf.sprintf
        {|
<section class="lecture-video chapter-only" aria-label="Lecture recording" data-youtube-id="%s">
  <a class="lecture-video-link" href="https://www.youtube.com/watch?v=%s" target="_blank" rel="noopener noreferrer">Watch online &#8599;</a>
  <div class="lecture-video-player" hidden></div>
</section>
|} id id in
      (* Place the recording immediately below the chapter title. *)
      try
        let at = Str.search_forward (Str.regexp_string "</h1>") html 0 + 5 in
        String.sub html 0 at ^ card ^ String.sub html at (String.length html - at)
      with Not_found -> card ^ html

let render_body ~html_body ~(fm : Frontmatter.t) ~manifest =
  let has_slides = body_has_slides html_body in
  let buf = Buffer.create (String.length html_body + 2048) in
  Buffer.add_string buf "<body class=\"mode-chapter\">\n";
  Buffer.add_string buf (header_bar ~fm ~has_slides);
  Buffer.add_string buf "\n";
  Buffer.add_string buf (render_sidebar ~manifest);
  (* In chapter mode the article holds everything inline. In slide mode
     a Reveal.js wrapper sibling becomes visible; the runtime script
     reparents the section[data-slide] elements into it on activation. *)
  Buffer.add_string buf "<article class=\"chapter\">\n";
  Buffer.add_string buf (with_lecture_video ~fm html_body);
  Buffer.add_string buf "\n</article>\n";
  Buffer.add_string buf (render_prev_next ~manifest);
  Buffer.add_string buf
    "<div class=\"reveal\" aria-hidden=\"true\"><div class=\"slides\"></div></div>\n";
  Buffer.add_string buf (footer_meta ~fm);
  Buffer.add_string buf "</body>\n";
  Buffer.contents buf

let render ~asset_root ~(fm : Frontmatter.t) ~html_body ?manifest () =
  let buf = Buffer.create (String.length html_body + 4096) in
  Buffer.add_string buf
    (head ~asset_root ~fm ~vm_terminal:(body_has_vm_terminal html_body));
  Buffer.add_char buf '\n';
  Buffer.add_string buf (render_body ~html_body ~fm ~manifest);
  Buffer.add_string buf (runtime_script ~asset_root);
  Buffer.add_char buf '\n';
  Buffer.add_string buf "</html>\n";
  Buffer.contents buf
