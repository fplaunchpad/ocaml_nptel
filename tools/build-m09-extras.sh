#!/bin/bash
# Build the M09 in-browser extension bundle. Adds QCheck (qcheck-core)
# plus QCheck_runner (qcheck, alcotest-backed) plus OUnit2 to the
# running vanilla x-ocaml toplevel via the
# `--toplevel-extend --export units.txt` recipe described in
#   https://kcsrk.info/ocaml/oxcaml/modes/2026/05/10/shrinking-the-oxcaml-bundle/
#
# Output: assets/x-ocaml/m09-extras.js (~450 KB)
# Load via: <script ... src-load="/assets/x-ocaml/m09-extras.js"> on
# the host page; added to lecture HTML by tools/nptel-build/lib/emit.ml
# for M09 lectures only (so M01-M08 stay slim).
#
# Requires the patched js_of_ocaml from
# https://github.com/kayceesrk/js_of_ocaml/tree/kc-toplevel-extend
# checked out at ~/repos/js_of_ocaml. The patch adds `--toplevel-extend`
# which makes the bundle composable (kind=cma) instead of clobbering
# the toplevel (kind=exe).
#
# Run from the repo root:
#   $ bash tools/build-m09-extras.sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/assets/x-ocaml/m09-extras.js"
FORK="$HOME/repos/js_of_ocaml"
JSOO="$FORK/_build/default/compiler/bin-js_of_ocaml/js_of_ocaml.exe"
JSOO_LISTUNITS="$FORK/_build/default/toplevel/bin/jsoo_listunits.exe"

[ -x "$JSOO" ] || { echo "missing $JSOO; build with: cd $FORK && dune build compiler/bin-js_of_ocaml/js_of_ocaml.exe toplevel/bin/jsoo_listunits.exe"; exit 1; }
[ -x "$JSOO_LISTUNITS" ] || { echo "missing $JSOO_LISTUNITS; same build step as above"; exit 1; }
ocamlfind query qcheck-core        >/dev/null 2>&1 || { echo "qcheck-core not installed: opam install qcheck-core"; exit 1; }
ocamlfind query qcheck-core.runner >/dev/null 2>&1 || { echo "qcheck-core.runner not installed (part of qcheck-core opam package)"; exit 1; }
ocamlfind query qcheck             >/dev/null 2>&1 || { echo "qcheck not installed: opam install qcheck (pulls in alcotest-backed runner)"; exit 1; }
ocamlfind query ounit2             >/dev/null 2>&1 || { echo "ounit2 not installed: opam install ounit2"; exit 1; }

# The M09 lectures use QCheck.(list_small ...) and friends from the
# modernised qcheck-core API, which only exists from 0.91 onwards. A
# bundle built against an older switch loads fine but every list_small
# cell dies with "Unbound value", which is miserable to debug from the
# browser. Fail loudly here instead.
QC_MIN_VERSION=0.91
QC_VERSION=$(ocamlfind query -format '%v' qcheck-core)
if [ "$(printf '%s\n%s\n' "$QC_MIN_VERSION" "$QC_VERSION" | sort -V | head -n1)" != "$QC_MIN_VERSION" ]; then
  echo "qcheck-core $QC_VERSION is too old: the M09 lectures need >= $QC_MIN_VERSION (QCheck.list_small etc.)." >&2
  echo "Upgrade with: opam install 'qcheck-core>=$QC_MIN_VERSION'" >&2
  exit 1
fi

QC=$(ocamlfind query qcheck-core)
QCR=$(ocamlfind query qcheck-core.runner)
QCFULL=$(ocamlfind query qcheck)
OU=$(ocamlfind query ounit2)

workdir=$(mktemp -d)
trap "rm -rf $workdir" EXIT

# 1. Stub bytecode that pulls qcheck-core, qcheck-core.runner, qcheck
#    (alcotest-backed) and ounit2 onto the link line. The alcotest
#    backend lets students use QCheck_runner.run_tests_main even though
#    the in-browser worker has no terminal; alcotest's output just
#    lands in the cell's stdout pane.
echo 'let () = ()' > "$workdir/stub.ml"
ocamlfind ocamlc -g \
  -package qcheck-core,qcheck-core.runner,qcheck,ounit2 \
  -linkpkg -linkall \
  "$workdir/stub.ml" -o "$workdir/stub.byte"

# 2. List the units that should remain visible to the toplevel after
#    cross-cma DCE. Pass the cmis directly because the patched
#    jsoo_listunits doesn't resolve findlib package names in this switch.
#    OUnitTest exposes the suite traversal/counting used by quiz graders;
#    exporting it also makes its interface available to the browser toplevel.
$JSOO_LISTUNITS -o "$workdir/units.txt" \
  "$QC/qCheck.cmi" "$QC/qCheck2.cmi" \
  "$QCR/qCheck_base_runner.cmi" \
  "$QCFULL/qCheck_runner.cmi" \
  "$OU/oUnit.cmi"  "$OU/oUnit2.cmi" \
  "$OU/advanced/oUnitTest.cmi"

# 3. Build the extension bundle.
#
#    Do NOT pass explicit --file=<cmi>:/static/cmis/ embeds here:
#    --toplevel already auto-embeds the cmis of the exported units,
#    and a second registration of the same path makes the bundle
#    raise Sys_error("... file already exists") at load time, which
#    aborts the remaining module initialisers (QCheck/OUnit2 then
#    show up as interface-only: "Reference to undefined compilation
#    unit"). The cmis the toplevel needs to elaborate the loaded
#    signatures (so hover/type queries resolve QCheck/OUnit2 names)
#    are the auto-embedded copies.
RAW="$workdir/portable_raw.js"
$JSOO --toplevel --toplevel-extend --export="$workdir/units.txt" \
  "$workdir/stub.byte" -o "$RAW"

# 4. Assemble the final bundle from three prepended/wrapped pieces:
#
#    (a) A Unix-primitive shim. The vanilla worker runtime does not
#        provide caml_unix_gethostname, but ounit2's OUnitUtils calls
#        Unix.gethostname at module-init time; without the shim the
#        extras load dies partway (TypeError) and OUnit2 never
#        registers. Same for caml_unix_environment at run_test_tt_main.
#        Any hostname string will do.
#
#    (b) A DLS-isolating harness around the bundle's IIFE. The bundle
#        re-runs stdlib's module init when it loads, and
#        Stdlib__Domain.DLS's `let key_counter = Atomic.make 0`
#        re-allocates DLS keys from zero, colliding with the host
#        toplevel's key space in the shared caml_domain_dls array.
#        Worse, the bundle's create_dls calls caml_domain_dls_set
#        with a fresh sentinel-filled array, clobbering the host's
#        array wholesale (that is what blanked merlin's hover
#        tooltips: the host's Format.stdbuf slot was gone). An
#        earlier snapshot/restore harness fixed hover but poisoned
#        the BUNDLE's key space instead: restored host objects sat
#        where the bundle's sentinels should be, so the bundle's
#        lazily-materialised DLS values (Random's int64-bigarray
#        state, first read inside QCheck_runner.run_tests via
#        Random.self_init) came back as foreign host objects and
#        threw "TypeError: ba.offset is not a function".
#
#        The fix is full isolation: give the bundle its own private
#        DLS array. The bundle captures caml_domain_dls_get into a
#        local once, in its var-preamble (rA=p.caml_domain_dls_get),
#        so a proxy installed only around the IIFE is captured
#        permanently. caml_domain_dls_set is only called at stdlib
#        init (create_dls), inside the IIFE. compare_and_set is
#        called dynamically (runtime.caml_...) at growth time by
#        BOTH stdlib instances, so a dispatching wrapper stays
#        installed: it handles the private array by identity and
#        delegates anything else to the original. The host's array
#        is never touched, so hover keeps working by construction.
unix_shim='// Prepended by tools/build-m09-extras.sh: the vanilla worker
// runtime lacks a few Unix primitives that ounit2 calls:
// gethostname at module init (OUnitUtils), environment when
// run_test_tt_main starts (OUnitConf). Stub both so OUnit2 loads
// and its runner works in the browser toplevel.
(function (g) {
  var r = g.jsoo_runtime;
  if (!r) return;
  if (!r.caml_unix_gethostname) {
    r.caml_unix_gethostname = function () { return "browser"; };
  }
  if (!r.caml_unix_environment) {
    r.caml_unix_environment = function () { return [0]; };
  }
})(globalThis);'

dls_pre='// DLS-isolating harness (see build-m09-extras.sh step 4b): give
// the bundle'\''s stdlib instance its own private Domain.DLS array so
// neither stdlib'\''s key space can poison the other'\''s.
(function (globalThis) {
  var rt = globalThis.jsoo_runtime;
  var proxied = false;
  var orig_get, orig_set, orig_cas;
  if (rt && rt.caml_domain_dls_get && rt.caml_domain_dls_set
         && rt.caml_domain_dls_compare_and_set) {
    proxied = true;
    orig_get = rt.caml_domain_dls_get;
    orig_set = rt.caml_domain_dls_set;
    orig_cas = rt.caml_domain_dls_compare_and_set;
    var priv = [0];
    // The bundle captures get into a local in its var-preamble, so
    // this proxy is bound into the bundle permanently.
    rt.caml_domain_dls_get = function (_unit) { return priv; };
    // set is only called by create_dls during the bundle'\''s stdlib
    // init, i.e. inside this try block.
    rt.caml_domain_dls_set = function (a) { priv = a; return 0; };
    // compare_and_set is looked up dynamically at call time by BOTH
    // stdlib instances (maybe_grow), so this dispatching wrapper
    // stays installed after load: private array by identity,
    // everything else delegated to the host'\''s original.
    rt.caml_domain_dls_compare_and_set = function (old, n) {
      if (old === priv) { priv = n; return 1; }
      return orig_cas(old, n);
    };
  }
  try {'

dls_post='  } finally {
    if (proxied) {
      rt.caml_domain_dls_get = orig_get;
      rt.caml_domain_dls_set = orig_set;
      // the dispatching compare_and_set wrapper stays (see above).
    }
  }
}(globalThis));'

{
  printf '%s\n' "$unix_shim"
  printf '%s\n' "$dls_pre"
  cat "$RAW"
  printf '%s\n' "$dls_post"
} > "$OUT"

ls -lh "$OUT"
