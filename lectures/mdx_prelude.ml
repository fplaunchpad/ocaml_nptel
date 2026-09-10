(* mdx prelude for the lecture code blocks (see the mdx stanza in
   ./dune). In the browser the M09 cells run OUnit2 under
   m09-extras.js, whose worker tolerates [exit]. Under mdx the same
   cells would kill the toplevel: [run_test_tt_main] parses
   [Sys.argv] (which holds the .md filename mdx_gen was invoked
   with, an "unexpected argument" that exits with code 2) and calls
   [exit] after the report. Hook the conf to feed a clean argv, and
   shadow [OUnit2] so [run_test_tt_main] returns instead of
   exiting. The sequential runner avoids the default processes
   runner forking the toplevel (which would duplicate the captured
   stdout); -no-output-file stops OUnit writing oUnit-*.log into
   the build dir. *)

let () =
  let orig = !OUnitCore.run_test_tt_main_conf in
  OUnitCore.run_test_tt_main_conf :=
    fun ?preset ?argv:_ specs ->
      orig ?preset
        ~argv:[| "mdx"; "-runner"; "sequential"; "-no-output-file" |]
        specs

module OUnit2 = struct
  include OUnit2

  let run_test_tt_main ?(exit = fun _ -> ()) test =
    OUnit2.run_test_tt_main ~exit test
end
