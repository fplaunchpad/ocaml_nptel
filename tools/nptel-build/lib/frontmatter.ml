(* Tiny YAML-subset front-matter reader.

   We accept exactly the keys we need for NPTEL lectures and reject anything
   we don't understand, so a typo in source surfaces immediately instead of
   silently dropping a field. Format:

     ---
     title: "What is functional programming?"
     lecture_no: 2
     week: 1
     duration_target_min: 25
     concepts: [pure functions, immutability]
     keywords: [OCaml, FP]
     activity_question: "Which of these..."
     think_about_this: "Can a language be both..."
     reading:
       - title: "Foo"
         url: https://example.com
     ---

   Strings may be bare or double-quoted; lists may be inline ([a, b, c])
   or block ('- ' on subsequent lines).
*)

type reading = { title : string; url : string }

type t = {
  title : string;
  youtube_id : string option;
  lecture_no : int option;
  week : int option;
  duration_target_min : int option;
  concepts : string list;
  keywords : string list;
  activity_question : string option;
  think_about_this : string option;
  reading : reading list;
}

let empty =
  {
    title = "";
    youtube_id = None;
    lecture_no = None;
    week = None;
    duration_target_min = None;
    concepts = [];
    keywords = [];
    activity_question = None;
    think_about_this = None;
    reading = [];
  }

let strip_quotes s =
  let n = String.length s in
  if n >= 2 && s.[0] = '"' && s.[n - 1] = '"' then String.sub s 1 (n - 2)
  else if n >= 2 && s.[0] = '\'' && s.[n - 1] = '\'' then String.sub s 1 (n - 2)
  else s

let trim_str = String.trim

let parse_inline_list s =
  let s = trim_str s in
  let n = String.length s in
  if n >= 2 && s.[0] = '[' && s.[n - 1] = ']' then
    let inner = String.sub s 1 (n - 2) in
    String.split_on_char ',' inner
    |> List.map trim_str
    |> List.filter (fun x -> x <> "")
    |> List.map strip_quotes
  else [ strip_quotes s ]

(* Split frontmatter from body. Returns (frontmatter_text, body). *)
let split_frontmatter src =
  let lines = String.split_on_char '\n' src in
  match lines with
  | first :: rest when String.trim first = "---" ->
      let rec scan acc = function
        | [] -> None
        | l :: tl when String.trim l = "---" ->
            Some (List.rev acc, String.concat "\n" tl)
        | l :: tl -> scan (l :: acc) tl
      in
      scan [] rest
  | _ -> None

(* Block list: collect indented '- key: val' entries below the parent key. *)
let parse_reading_block block_lines =
  let rec loop acc cur = function
    | [] -> List.rev (match cur with Some r -> r :: acc | None -> acc)
    | line :: tl ->
        let s = trim_str line in
        if s = "" then loop acc cur tl
        else if String.length s >= 2 && String.sub s 0 2 = "- " then begin
          let acc = match cur with Some r -> r :: acc | None -> acc in
          let rest = String.sub s 2 (String.length s - 2) |> trim_str in
          let r =
            match String.index_opt rest ':' with
            | Some i ->
                let k = trim_str (String.sub rest 0 i) in
                let v =
                  trim_str
                    (String.sub rest (i + 1) (String.length rest - i - 1))
                  |> strip_quotes
                in
                if k = "title" then { title = v; url = "" }
                else if k = "url" then { title = ""; url = v }
                else { title = rest; url = "" }
            | None -> { title = rest; url = "" }
          in
          loop acc (Some r) tl
        end
        else begin
          match cur, String.index_opt s ':' with
          | Some r, Some i ->
              let k = trim_str (String.sub s 0 i) in
              let v =
                trim_str (String.sub s (i + 1) (String.length s - i - 1))
                |> strip_quotes
              in
              let r' =
                match k with
                | "title" -> { r with title = v }
                | "url" -> { r with url = v }
                | _ -> r
              in
              loop acc (Some r') tl
          | _ -> loop acc cur tl
        end
  in
  loop [] None block_lines

let parse_value t key value rest_lines =
  let v_trimmed = trim_str value in
  match key with
  | "title" -> ({ t with title = strip_quotes v_trimmed }, rest_lines)
  | "youtube_id" ->
      let id = strip_quotes v_trimmed in
      if String.length id <> 11 || not (String.for_all
          (function 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' -> true | _ -> false) id)
      then failwith "frontmatter: youtube_id must be an 11-character YouTube video ID";
      ({ t with youtube_id = Some id }, rest_lines)
  | "lecture_no" -> ({ t with lecture_no = int_of_string_opt v_trimmed }, rest_lines)
  | "week" -> ({ t with week = int_of_string_opt v_trimmed }, rest_lines)
  | "duration_target_min" ->
      ({ t with duration_target_min = int_of_string_opt v_trimmed }, rest_lines)
  | "concepts" -> ({ t with concepts = parse_inline_list v_trimmed }, rest_lines)
  | "keywords" -> ({ t with keywords = parse_inline_list v_trimmed }, rest_lines)
  | "activity_question" ->
      ({ t with activity_question = Some (strip_quotes v_trimmed) }, rest_lines)
  | "think_about_this" ->
      ({ t with think_about_this = Some (strip_quotes v_trimmed) }, rest_lines)
  | "reading" ->
      (* Collect block-style entries until we hit an unindented line. *)
      let block, rest =
        let rec take acc = function
          | [] -> (List.rev acc, [])
          | (line : string) :: tl ->
              if line = "" then take (line :: acc) tl
              else if line.[0] = ' ' || line.[0] = '\t' then take (line :: acc) tl
              else (List.rev acc, line :: tl)
        in
        take [] rest_lines
      in
      ({ t with reading = parse_reading_block block }, rest)
  | _ ->
      (* A typo'd key is consequential: [week] selects the in-browser
         bundle, [activity_question] feeds the index. Fail loudly
         instead of silently dropping the field. *)
      failwith
        (Printf.sprintf
           "frontmatter: unknown key %S (known: title, youtube_id, lecture_no, week, \
            duration_target_min, concepts, keywords, activity_question, \
            think_about_this, reading)"
           key)

let parse_lines lines =
  let rec loop t = function
    | [] -> t
    | line :: rest ->
        let s = trim_str line in
        if s = "" || (String.length s > 0 && s.[0] = '#') then loop t rest
        else if line.[0] = ' ' || line.[0] = '\t' then
          (* Indented continuation lines belong to a block key that the
             key's own handler consumes (e.g. [reading]); a stray one is
             tolerated rather than misread as a top-level key. *)
          loop t rest
        else
          match String.index_opt s ':' with
          | None ->
              failwith
                (Printf.sprintf "frontmatter: malformed line %S (expected key: value)" s)
          | Some i ->
              let key = trim_str (String.sub s 0 i) in
              let value = String.sub s (i + 1) (String.length s - i - 1) in
              let t', rest' = parse_value t key value rest in
              loop t' rest'
  in
  loop empty lines

let parse src =
  match split_frontmatter src with
  | None -> (empty, src)
  | Some (lines, body) -> (parse_lines lines, body)
