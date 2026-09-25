(* Unit tests for the OCaml side of the toolchain. *)

open Nptel_build

let check_string = Alcotest.(check string)
let check_int = Alcotest.(check int)
let check_bool = Alcotest.(check bool)
let check_string_list = Alcotest.(check (list string))

(* ---- Frontmatter ---------------------------------------------------- *)

let fm_video () =
  let fm, _ = Frontmatter.parse "---\nyoutube_id: 5f-fi2sl9ec\n---\n# Lecture" in
  Alcotest.(check (option string)) "video ID" (Some "5f-fi2sl9ec") fm.youtube_id;
  Alcotest.(check (option string)) "optional" None Frontmatter.empty.youtube_id;
  List.iter (fun id ->
    let rejected = try
      ignore (Frontmatter.parse ("---\nyoutube_id: " ^ id ^ "\n---\n")); false
      with Failure _ -> true in
    check_bool "invalid video ID rejected" true rejected)
    ["short"; "https://youtube.com/watch?v=5f-fi2sl9ec"; "1234567890<"]

let fm_basic () =
  let src =
    {|---
title: "Hello world"
lecture_no: 3
week: 2
duration_target_min: 25
concepts: [pure functions, immutability]
keywords: [OCaml, FP]
activity_question: "Is this referentially transparent?"
think_about_this: "Why?"
reading:
  - title: "CS3110"
    url: https://cs3110.github.io/textbook/
---

# Body
|}
  in
  let fm, body = Frontmatter.parse src in
  check_string "title" "Hello world" fm.title;
  Alcotest.(check (option int)) "lecture_no" (Some 3) fm.lecture_no;
  Alcotest.(check (option int)) "week" (Some 2) fm.week;
  Alcotest.(check (option int)) "duration_target_min" (Some 25) fm.duration_target_min;
  check_string_list "concepts" ["pure functions"; "immutability"] fm.concepts;
  check_string_list "keywords" ["OCaml"; "FP"] fm.keywords;
  Alcotest.(check (option string)) "activity"
    (Some "Is this referentially transparent?") fm.activity_question;
  Alcotest.(check (option string)) "think" (Some "Why?") fm.think_about_this;
  check_int "reading count" 1 (List.length fm.reading);
  check_string "reading title" "CS3110" (List.hd fm.reading).title;
  check_string "reading url" "https://cs3110.github.io/textbook/"
    (List.hd fm.reading).url;
  check_bool "body starts with # Body" true
    (String.length body > 0 && String.contains body '#')

let fm_no_frontmatter () =
  let fm, body = Frontmatter.parse "# Just a heading\n\nno frontmatter\n" in
  check_string "title is empty" "" fm.title;
  check_string "body preserved" "# Just a heading\n\nno frontmatter\n" body

let fm_unknown_key_rejected () =
  let src = {|---
title: "ok"
weeek: 3
---
body
|} in
  let raised =
    try
      ignore (Frontmatter.parse src);
      false
    with Failure msg ->
      check_bool "message names the key" true
        (try ignore (Str.search_forward (Str.regexp_string "weeek") msg 0); true
         with Not_found -> false);
      true
  in
  check_bool "unknown top-level key fails" true raised

let fm_quoted_strings () =
  let src = {|---
title: 'single quoted'
keywords: ["with spaces", bare]
---
|} in
  let fm, _ = Frontmatter.parse src in
  check_string "title unquoted" "single quoted" fm.title;
  check_string_list "keywords mixed quoting" ["with spaces"; "bare"] fm.keywords

(* ---- Divs preprocessor --------------------------------------------- *)

let divs_slide_simple () =
  let out = Divs.preprocess ":::slide\nhello\n:::\n" in
  check_bool "opens section" true
    (Str.string_match (Str.regexp_string "<section class=\"slide\"") out 0
     || (try ignore (Str.search_forward (Str.regexp_string "<section class=\"slide\"") out 0); true
         with Not_found -> false));
  check_bool "closes section" true
    (try ignore (Str.search_forward (Str.regexp_string "</section>") out 0); true
     with Not_found -> false)

let divs_notes () =
  let out = Divs.preprocess ":::notes\nspeaker\n:::\n" in
  check_bool "aside.notes opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<aside class=\"notes\">") out 0); true
     with Not_found -> false);
  check_bool "aside closes" true
    (try ignore (Str.search_forward (Str.regexp_string "</aside>") out 0); true
     with Not_found -> false)

let divs_fragment () =
  let out = Divs.preprocess ":::fragment\nbullet\n:::\n" in
  check_bool "div.fragment opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"fragment\">") out 0); true
     with Not_found -> false)

let divs_nesting () =
  let out = Divs.preprocess ":::slide\n:::fragment\nx\n:::\n:::\n" in
  let count_sub sub =
    let r = Str.regexp_string sub in
    let rec go i n =
      match Str.search_forward r out i with
      | exception Not_found -> n
      | j -> go (j + String.length sub) (n + 1)
    in
    go 0 0
  in
  check_int "two opens (section + div.fragment)"
    1 (count_sub "<section class=\"slide\"");
  check_int "one fragment div" 1 (count_sub "<div class=\"fragment\">")

let divs_cols_basic () =
  let src =
    ":::cols\n:::col 60%\nhi\n:::\n:::col 40%\nhello\n:::\n:::\n"
  in
  let out = Divs.preprocess src in
  check_bool "cols container opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"cols\">") out 0); true
     with Not_found -> false);
  check_bool "first col width 60%" true
    (try ignore
         (Str.search_forward
            (Str.regexp_string "<div class=\"col\" style=\"flex: 0 0 60%;\">")
            out 0);
       true
     with Not_found -> false);
  check_bool "second col width 40%" true
    (try ignore
         (Str.search_forward
            (Str.regexp_string "<div class=\"col\" style=\"flex: 0 0 40%;\">")
            out 0);
       true
     with Not_found -> false)

let divs_col_no_width () =
  let out = Divs.preprocess ":::cols\n:::col\nhi\n:::\n:::\n" in
  check_bool "bare col emits no inline style" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"col\">") out 0); true
     with Not_found -> false);
  check_bool "no flex inline style on bare col" true
    (try
       ignore (Str.search_forward (Str.regexp_string "flex: 0 0") out 0);
       false
     with Not_found -> true)

let divs_col_malformed () =
  (* "60" without %, "abc", "150%", "0%": each should fall through and
     leave the [:::col ...] line literal in the output (no <div class=
     "col"> emitted). *)
  let cases = [ "60"; "abc"; "150%"; "0%" ] in
  List.iter
    (fun spec ->
      let src = Printf.sprintf ":::col %s\nhi\n:::\n" spec in
      let out = Divs.preprocess src in
      let opened =
        try
          ignore (Str.search_forward (Str.regexp_string "<div class=\"col\"") out 0);
          true
        with Not_found -> false
      in
      Alcotest.(check bool)
        (Printf.sprintf "malformed `%s` does not open a col div" spec) false opened;
      let literal =
        try
          ignore
            (Str.search_forward (Str.regexp_string (Printf.sprintf ":::col %s" spec)) out 0);
          true
        with Not_found -> false
      in
      Alcotest.(check bool)
        (Printf.sprintf "malformed `%s` left as literal" spec) true literal)
    cases

let divs_no_match () =
  let src = "plain prose, no divs\n" in
  let out = Divs.preprocess src in
  (* Should pass through, possibly with trailing newlines. *)
  check_bool "plain prose preserved" true
    (try ignore (Str.search_forward (Str.regexp_string "plain prose") out 0); true
     with Not_found -> false)

(* ---- :::vm-terminal ------------------------------------------------ *)

let divs_vm_terminal_basic () =
  let out = Divs.preprocess ":::vm-terminal\nplaceholder prose\n:::\n" in
  check_bool "vm-terminal div opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"vm-terminal\">") out 0); true
     with Not_found -> false);
  check_bool "no data-dir without an argument" true
    (try ignore (Str.search_forward (Str.regexp_string "data-dir") out 0); false
     with Not_found -> true)

let divs_vm_terminal_dir () =
  let out = Divs.preprocess ":::vm-terminal dir=/root/morse\n:::\n" in
  check_bool "data-dir carries the start directory" true
    (try
       ignore
         (Str.search_forward
            (Str.regexp_string "<div class=\"vm-terminal\" data-dir=\"/root/morse\">")
            out 0);
       true
     with Not_found -> false)

let divs_vm_terminal_malformed () =
  (* Not absolute, shell-unsafe characters, unknown argument: each
     falls through and leaves the line literal, like :::col. *)
  let cases = [ "dir=morse"; "dir=/root/morse; rm"; "wat" ] in
  List.iter
    (fun spec ->
      let src = Printf.sprintf ":::vm-terminal %s\nhi\n:::\n" spec in
      let out = Divs.preprocess src in
      let opened =
        try
          ignore
            (Str.search_forward (Str.regexp_string "<div class=\"vm-terminal\"") out 0);
          true
        with Not_found -> false
      in
      Alcotest.(check bool)
        (Printf.sprintf "malformed `%s` does not open a vm-terminal" spec)
        false opened)
    cases

let divs_vm_terminal_max_one () =
  let src = ":::vm-terminal\na\n:::\n\n:::vm-terminal\nb\n:::\n" in
  let failed =
    try
      ignore (Divs.preprocess src);
      false
    with Failure _ -> true
  in
  check_bool "second vm-terminal per file fails the build" true failed

(* ---- OCaml fence -> <x-ocaml> -------------------------------------- *)

let parse_ocaml_block () =
  let doc =
    Cmarkit.Doc.of_string "```ocaml\nlet x = 1\n```\n"
  in
  let doc' = Parse.transform doc in
  let html = Cmarkit_html.of_doc ~safe:false doc' in
  check_bool "emits x-ocaml" true
    (try ignore (Str.search_forward (Str.regexp_string "<x-ocaml") html 0); true
     with Not_found -> false);
  check_bool "carries source verbatim" true
    (try ignore (Str.search_forward (Str.regexp_string "let x = 1") html 0); true
     with Not_found -> false);
  check_bool "carries data-source attribute" true
    (try ignore (Str.search_forward (Str.regexp_string "data-source=") html 0); true
     with Not_found -> false)

let parse_ocaml_attrs () =
  let doc =
    Cmarkit.Doc.of_string "```ocaml init=true autorun\nprint_endline \"hi\"\n```\n"
  in
  let html = Cmarkit_html.of_doc ~safe:false (Parse.transform doc) in
  check_bool "init=true preserved" true
    (try ignore (Str.search_forward (Str.regexp_string "init=\"true\"") html 0); true
     with Not_found -> false);
  check_bool "bare attribute -> =true" true
    (try ignore (Str.search_forward (Str.regexp_string "autorun=\"true\"") html 0); true
     with Not_found -> false)

let parse_non_ocaml_fence () =
  let doc =
    Cmarkit.Doc.of_string "```python\nprint('hi')\n```\n"
  in
  let html = Cmarkit_html.of_doc ~safe:false (Parse.transform doc) in
  check_bool "python fence stays as code" true
    (try ignore (Str.search_forward (Str.regexp_string "<code") html 0); true
     with Not_found -> false);
  check_bool "no x-ocaml emitted" true
    (try
       ignore (Str.search_forward (Str.regexp_string "<x-ocaml") html 0);
       false
     with Not_found -> true)

let parse_html_escape_in_cell () =
  let doc =
    Cmarkit.Doc.of_string "```ocaml\nlet s = \"<&>\"\n```\n"
  in
  let html = Cmarkit_html.of_doc ~safe:false (Parse.transform doc) in
  check_bool "angle brackets escaped" true
    (try ignore (Str.search_forward (Str.regexp_string "&lt;&amp;&gt;") html 0); true
     with Not_found -> false)

let parse_quiz_test_attr () =
  (* The build's [Divs.preprocess] adds [quiz-test] to the info
     string for the 2nd+ ocaml fence inside a [:::quiz code] block.
     Here we simulate that rewrite directly. *)
  let doc =
    Cmarkit.Doc.of_string
      "```ocaml skip quiz-test\nlet () = print_endline \"ok\"\n```\n"
  in
  let html = Cmarkit_html.of_doc ~safe:false (Parse.transform doc) in
  check_bool "data-quiz-test marker present" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-test=\"true\"") html 0); true
     with Not_found -> false);
  check_bool "implicit hidden=true" true
    (try ignore (Str.search_forward (Str.regexp_string "hidden=\"true\"") html 0); true
     with Not_found -> false);
  check_bool "quiz-test=true NOT emitted as own attribute" true
    (try
       ignore (Str.search_forward (Str.regexp_string " quiz-test=\"") html 0);
       false
     with Not_found -> true);
  check_bool "skip NOT emitted as own attribute" true
    (try
       ignore (Str.search_forward (Str.regexp_string " skip=\"") html 0);
       false
     with Not_found -> true)

(* ---- Quiz fenced divs ---------------------------------------------- *)

let divs_quiz_mcq () =
  let out = Divs.preprocess ":::quiz mcq\nq?\n- [x] yes\n- [ ] no\n:::\n" in
  check_bool "quiz-mcq class opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"quiz quiz-mcq\"") out 0); true
     with Not_found -> false);
  check_bool "auto-id q1" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q1\"") out 0); true
     with Not_found -> false)

let divs_quiz_code () =
  let out = Divs.preprocess ":::quiz code\nprompt\n```ocaml\nlet x = 1\n```\n:::\n" in
  check_bool "quiz-code class opens" true
    (try ignore (Str.search_forward (Str.regexp_string "<div class=\"quiz quiz-code\"") out 0); true
     with Not_found -> false);
  check_bool "auto-id q1" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q1\"") out 0); true
     with Not_found -> false)

let divs_quiz_ids_sequential () =
  (* Two quizzes in one document get q1 and q2 respectively. *)
  let src =
    ":::quiz mcq\n- [x] a\n:::\n\nprose\n\n:::quiz code\n```ocaml\nlet _ = 1\n```\n:::\n"
  in
  let out = Divs.preprocess src in
  check_bool "first quiz is q1" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q1\"") out 0); true
     with Not_found -> false);
  check_bool "second quiz is q2" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q2\"") out 0); true
     with Not_found -> false)

let divs_quiz_explicit_id () =
  (* Author-pinned id wins over the positional fallback. *)
  let src = ":::quiz mcq id=cons-immutability\n- [x] yes\n:::\n" in
  let out = Divs.preprocess src in
  check_bool "uses author id" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"cons-immutability\"") out 0); true
     with Not_found -> false);
  check_bool "no q1 fallback when explicit id given" true
    (try
       ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q1\"") out 0);
       false
     with Not_found -> true)

let divs_quiz_id_slugged () =
  (* Author id is sanitised: lowercased, weird chars dropped. *)
  let src = ":::quiz mcq id=Cons & Immutability!\n- [x] yes\n:::\n" in
  let out = Divs.preprocess src in
  check_bool "slugified" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"cons-immutability\"") out 0); true
     with Not_found -> false)

let divs_quiz_mix_ids () =
  (* Mixed: one explicit, one fallback. The fallback counter still
     advances past every quiz, so the second quiz here is q2. *)
  let src =
    ":::quiz mcq id=alpha\n- [x] a\n:::\n\n:::quiz code\n```ocaml\nlet _ = 1\n```\n:::\n"
  in
  let out = Divs.preprocess src in
  check_bool "first quiz keeps explicit id" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"alpha\"") out 0); true
     with Not_found -> false);
  check_bool "second quiz is q2 (positional counter advanced)" true
    (try ignore (Str.search_forward (Str.regexp_string "data-quiz-id=\"q2\"") out 0); true
     with Not_found -> false)

(* ---- Divs hardening -------------------------------------------------- *)

let divs_marker_inside_code_fence_is_literal () =
  let src = "```\n:::slide\n:::\n```\nafter\n" in
  let out = Divs.preprocess src in
  check_bool "no section emitted for ::: inside a code fence" true
    (try ignore (Str.search_forward (Str.regexp_string "<section") out 0); false
     with Not_found -> true);
  check_bool ":::slide preserved literally" true
    (try ignore (Str.search_forward (Str.regexp_string ":::slide") out 0); true
     with Not_found -> false)

let divs_unclosed_fails () =
  let src = ":::slide\n\n# Heading\n" in
  let raised =
    try
      ignore (Divs.preprocess src);
      false
    with Failure msg ->
      check_bool "message says unclosed" true
        (try ignore (Str.search_forward (Str.regexp_string "unclosed") msg 0); true
         with Not_found -> false);
      true
  in
  check_bool "unclosed div fails the build" true raised

(* ---- Run ----------------------------------------------------------- *)

let () =
  Alcotest.run "nptel-build"
    [
      ( "frontmatter",
        [
          Alcotest.test_case "lecture video metadata" `Quick fm_video;
          Alcotest.test_case "basic" `Quick fm_basic;
          Alcotest.test_case "missing" `Quick fm_no_frontmatter;
          Alcotest.test_case "quoted strings" `Quick fm_quoted_strings;
          Alcotest.test_case "unknown key rejected" `Quick fm_unknown_key_rejected;
        ] );
      ( "divs",
        [
          Alcotest.test_case "slide" `Quick divs_slide_simple;
          Alcotest.test_case "notes" `Quick divs_notes;
          Alcotest.test_case "fragment" `Quick divs_fragment;
          Alcotest.test_case "nesting" `Quick divs_nesting;
          Alcotest.test_case "cols basic widths" `Quick divs_cols_basic;
          Alcotest.test_case "col no width" `Quick divs_col_no_width;
          Alcotest.test_case "col malformed/out-of-range" `Quick divs_col_malformed;
          Alcotest.test_case "no match" `Quick divs_no_match;
          Alcotest.test_case "vm-terminal basic" `Quick divs_vm_terminal_basic;
          Alcotest.test_case "vm-terminal dir arg" `Quick divs_vm_terminal_dir;
          Alcotest.test_case "vm-terminal malformed" `Quick divs_vm_terminal_malformed;
          Alcotest.test_case "vm-terminal max one" `Quick divs_vm_terminal_max_one;
          Alcotest.test_case "::: inside code fence is literal" `Quick
            divs_marker_inside_code_fence_is_literal;
          Alcotest.test_case "unclosed div fails" `Quick divs_unclosed_fails;
        ] );
      ( "parse",
        [
          Alcotest.test_case "ocaml block -> x-ocaml" `Quick parse_ocaml_block;
          Alcotest.test_case "attrs in info string" `Quick parse_ocaml_attrs;
          Alcotest.test_case "non-ocaml fence untouched" `Quick parse_non_ocaml_fence;
          Alcotest.test_case "html escape" `Quick parse_html_escape_in_cell;
          Alcotest.test_case "ocaml skip quiz-test -> quiz test cell" `Quick parse_quiz_test_attr;
        ] );
      ( "quizzes",
        [
          Alcotest.test_case "quiz mcq div" `Quick divs_quiz_mcq;
          Alcotest.test_case "quiz code div" `Quick divs_quiz_code;
          Alcotest.test_case "ids sequential" `Quick divs_quiz_ids_sequential;
          Alcotest.test_case "explicit id wins" `Quick divs_quiz_explicit_id;
          Alcotest.test_case "id is slugified" `Quick divs_quiz_id_slugged;
          Alcotest.test_case "mix explicit + fallback" `Quick divs_quiz_mix_ids;
        ] );
    ]
