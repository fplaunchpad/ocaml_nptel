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

val empty : t

(** [parse src] returns the parsed frontmatter and the body text after the
    closing [---]. If no frontmatter is present, returns [(empty, src)]. *)
val parse : string -> t * string
