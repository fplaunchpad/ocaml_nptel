(lang dune 3.17)

(using mdx 0.4)

(name nptel-ocaml)

(generate_opam_files true)

(maintainers "KC Sivaramakrishnan <kc@kcsrk.info>")

(authors "KC Sivaramakrishnan")

; The opam package is the course toolchain (OCaml code), which is ISC.
; The course *content* (lectures/, assets/css/, README) is CC-BY-NC-SA-4.0;
; see LICENSE / LICENSES.md. They are deliberately different.
(license "ISC")

(source
 (github fplaunchpad/ocaml_nptel))

; Build dependencies are unconditional; lecture validation and unit-test
; dependencies use with_test. Install both with
; `opam install . --deps-only --with-test`.
; M11 validates on the separate nptel-ox switch; see tools/setup-switch.sh.
(package
 (name nptel-ocaml)
 (synopsis "Functional Programming with OCaml: NPTEL lecture sources and toolchain")
 (description
  "Lecture sources, the static-site toolchain, and the in-browser OCaml/OxCaml notebooks for the NPTEL course 'Functional Programming with OCaml'. This package declares the site-builder dependencies and the test dependencies needed to validate lecture code and the toolchain.")
 (depends
  ; the default switch we build/test the toolchain on; the M11 OxCaml
  ; cells validate on a separate switch with OxCaml-compatible
  ; dune/mdx packages (see tools/setup-switch.sh).
  (ocaml (>= 5.4.0))
  cmarkit
  fpath
  (alcotest :with-test)
  (mdx (and :with-test (>= 2.4)))
  (qcheck (and :with-test (>= 0.90)))
  (qcheck-core (and :with-test (>= 0.90)))
  (ounit2 :with-test)))
