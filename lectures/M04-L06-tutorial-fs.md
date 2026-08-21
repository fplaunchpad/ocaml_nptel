---
title: "Tutorial: a tiny file system"
lecture_no: 6
week: 4
duration_target_min: 22
concepts: [worked ADT design, recursive variants, records, inline records, file system]
keywords: [OCaml, file system, ADT, recursive variant, record, tutorial]
activity_question: "Extend [entry] with a [Symlink of { name : string; target : string }] constructor. Then construct a directory whose contents include a regular file and a symlink to that file."
think_about_this: "Why is a directory's [contents] a list of [entry], rather than a list of strings (names)? What would the type have to look like if names were the only thing stored, and what would that cost the consumer?"
reading:
  - title: "Cornell CS3110, Algebraic data types"
    url: https://cs3110.github.io/textbook/chapters/data/algebraic_data_types.html
  - title: "Real World OCaml, Variants"
    url: https://dev.realworldocaml.org/variants.html
---

# Tutorial for Module 4 (part 2)


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: a tiny file system</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The [previous tutorial](M04-L05-tutorial.html) modelled a tiny AST
for OCaml itself. This one applies the same toolkit (records,
variants, recursion, `option`) to a very different domain: a
*file system*. The shape of the data is different, but the
ingredients are the same; that is the point of seeing two worked
examples in a row.

A file system is built out of two kinds of thing: **files**, which
hold content, and **directories**, which hold *other entries*. The
"other entries" can themselves be either kind, so the structure is
recursive. Every file system you have used (the disk on your
laptop, a tarball, a Git repository's tree) is a value of
essentially this shape.

We are still on the *design* side of the toolkit: types and
constructed values, no walks. Walking a file system (computing its
total size, finding all files with a given extension, listing
contents at a path) needs pattern matching, which lands in
[Module 5](M05-L01-basic-patterns.html); we will return to this
tree there.

## What's in a file system?

Two kinds of entry:

- A **file** has a name, a size, and access permissions.
- A **directory** has a name, access permissions, and a list of
  entries inside it.

That is it. Everything else (a path like `/home/alice`,
the notion of a "root", whether two files have the same content)
is *derived* from this structure by code that walks it. The
declared type just captures the shape.

A picture of a small tree:

```text
home/
+- alice/
   +- notes.txt
   +- photos/
   |  +- cat.jpg
   |  +- dog.jpg
   +- thesis.pdf
```

`home` is a directory. Its only entry is `alice`, also a directory.
Inside `alice` there are two files and another directory. Inside
`photos` there are two more files. The recursion bottoms out at
the files (the leaves); the branching happens at directories.

:::slide

## What's in a file system?

Two kinds of entry:

- **File**: name, size, permissions.
- **Directory**: name, permissions, and a list of entries inside.

```text
home/
+- alice/
   +- notes.txt
   +- photos/
   |  +- cat.jpg
   |  +- dog.jpg
   +- thesis.pdf
```

- Directories branch; files are the leaves.
- A directory's contents can be **any** mix of files and
  directories - the structure is **recursive**.

:::

## A first cut: file vs directory

Two pieces of data live on every entry: its `name` and its
permissions. We will use an *inline record* (from
[the variants lecture](M04-L03-variants.html)) inside each
variant constructor to keep the fields self-documenting.
Permissions get their own small record type:

```ocaml
type perms = { read : bool; write : bool; exec : bool }

type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }
```

The `File` constructor carries three fields; `Dir` carries three
as well, the last of which is a `entry list`. That self-reference
is what makes the structure recursive: a directory's contents are
themselves entries.

The smallest interesting value is a single file:

```ocaml
type perms = { read : bool; write : bool; exec : bool }

type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }

let rw = { read = true; write = true;  exec = false }
let rx = { read = true; write = false; exec = true  }

let notes =
  File { name = "notes.txt"; size = 1284; perms = rw }
```

`rw` is a re-usable "read-write" permission value; `notes` is a
1284-byte file with those permissions. The OCaml value names the
fields by hand, which costs a few extra characters but reads like
a small data sheet.

:::slide

## A first cut

```ocaml
type perms = { read : bool; write : bool; exec : bool }

type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }
```

- Two variant constructors, each with an inline record payload.
- `Dir.contents : entry list` is the recursion.

:::

:::slide

## A first value

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }

let rw = { read = true; write = true; exec = false }

let notes = File { name = "notes.txt"; size = 1284; perms = rw }
```

- `rw`: a re-usable read-write permission value.
- `notes`: a 1284-byte file value of type `entry`.

:::

## Constructing the tree

Building up the tree from the picture, leaves first. The `photos`
directory holds two image files:

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }
let rw = { read = true; write = true;  exec = false }
let rx = { read = true; write = false; exec = true  }

let cat = File { name = "cat.jpg"; size = 184_000; perms = rw }
let dog = File { name = "dog.jpg"; size = 220_000; perms = rw }

let photos =
  Dir { name     = "photos";
        perms    = rx;
        contents = [cat; dog] }
```

`photos` is a directory whose `contents` is a two-element list of
files. The variant constructor names the kind (`Dir`), the inline
record names the fields, and the list literal carries the children.

The `alice` directory holds two files and the `photos` directory:

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }
let rw = { read = true; write = true;  exec = false }
let rx = { read = true; write = false; exec = true  }
let notes  = File { name = "notes.txt";  size = 1284;    perms = rw }
let thesis = File { name = "thesis.pdf"; size = 3_900_000; perms = rw }
let cat    = File { name = "cat.jpg";    size = 184_000; perms = rw }
let dog    = File { name = "dog.jpg";    size = 220_000; perms = rw }
let photos =
  Dir { name = "photos"; perms = rx; contents = [cat; dog] }

let alice =
  Dir { name     = "alice";
        perms    = rx;
        contents = [notes; photos; thesis] }
```

The mix of files and a directory in the same list is fine: every
element has type `entry`, regardless of which constructor it was
built with. That is the whole point of a variant: a *single* type
that absorbs multiple shapes.

And the root:

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size  : int;   perms : perms }
  | Dir  of { name : string; perms : perms; contents : entry list }
let rw = { read = true; write = true;  exec = false }
let rx = { read = true; write = false; exec = true  }
let alice =
  Dir { name = "alice"; perms = rx; contents = [] }  (* contents elided *)

let home =
  Dir { name = "home"; perms = rx; contents = [alice] }
```

The OCaml value is the tree. Each constructor names its kind; each
inline record names its fields; the recursion threads through the
`contents` field of every `Dir`. No path strings, no separators, no
parsing: just constructors and records.

:::slide

## A small directory

:::cols
:::col 62%

```ocaml
let rx = { read = true; write = false; exec = true }

let cat =
  File { name = "cat.jpg"; size = 184_000; perms = rw }
let dog =
  File { name = "dog.jpg"; size = 220_000; perms = rw }

let photos =
  Dir { name = "photos"; perms = rx; contents = [cat; dog] }
```

- `contents` is a list of `entry` values; files and
  directories share that type, so they share the list.

:::
:::col 38%

```text
photos/
+- cat.jpg
+- dog.jpg
```

:::
:::

:::

:::slide

## Nesting all the way to the root

```text
let alice =
  Dir { name = "alice"; perms = rx;
        contents = [notes; photos; thesis] }

let home =
  Dir { name = "home"; perms = rx; contents = [alice] }
```

- The OCaml value *is* the tree.
- No path strings, no separators - just constructors and records.

:::

## Adding an owner: optional metadata

Some entries have an owner (a user that owns the file or directory);
some, for our purposes, do not (think of a public-read mount, or
an entry whose owner data is missing from a backup). The "may or
may not be present" pattern is exactly what `option` is for. We
add an `owner` field of type `string option` to both variants:

```ocaml
type perms = { read : bool; write : bool; exec : bool }

type entry =
  | File of { name : string; size  : int;   perms : perms;
              owner : string option }
  | Dir  of { name : string; perms : perms;
              contents : entry list; owner : string option }
```

Two example files, one with an owner and one without:

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size : int; perms : perms;
              owner : string option }
  | Dir of { name : string; perms : perms;
             contents : entry list; owner : string option }
let rw = { read = true; write = true; exec = false }

let owned =
  File { name  = "notes.txt"; size = 1284; perms = rw;
         owner = Some "alice" }

let anonymous =
  File { name  = "backup.bin"; size = 9_000; perms = rw;
         owner = None }
```

`Some "alice"` says "this file is owned by `alice`"; `None` says
"no owner data attached." Note that this is "no value
attached," not "an owner who is the empty string"; the type
forces the two cases apart. That distinction (and the
[recursive-types lecture's rule of thumb](M04-L04-recursive-types.html#when-to-use-option):
`option` for *consumer uncertainty*, not for an explicit domain
value) is what this kind of design buys you.

:::slide

## Adding an owner: optional metadata

```ocaml
type perms = { read : bool; write : bool; exec : bool }

type entry =
  | File of { name : string; size : int; perms : perms;
              owner : string option }
  | Dir of { name : string; perms : perms;
             contents : entry list; owner : string option }
```

- `owner : string option`: "may or may not have one."
- `Some "alice"` vs `None` - the type forces the cases apart.
- *Consumer uncertainty*, not a domain value (no empty string).

:::

## Design decision: lookup outcome with `result`

A common operation a consumer will write (in Module 5, once we
have pattern matching) is "find the entry at path `/home/alice/cat.jpg`."
That operation can succeed (return the entry) or fail in two
different ways: the path may not exist, or the entry may exist but
the consumer may lack read permission on it. Plain `option` cannot
distinguish those two outcomes; `result` can.

We declare a domain type for the failure reason and use `result`:

```ocaml
type lookup_error =
  | Not_found
  | Permission_denied
```

The signature of the future lookup function will then be:

```text
val lookup : entry -> string list -> (entry, lookup_error) result
```

(`string list` is the path, broken into segments; the result is
either the found `entry` or one of the two failure reasons.)

We are not writing `lookup` here, but we can still construct
example *values* of the return type, to make sure the design fits:

```ocaml
type perms = { read : bool; write : bool; exec : bool }
type entry =
  | File of { name : string; size : int; perms : perms;
              owner : string option }
  | Dir of { name : string; perms : perms;
             contents : entry list; owner : string option }
type lookup_error =
  | Not_found
  | Permission_denied
let rw = { read = true; write = true; exec = false }

let ok_result   : (entry, lookup_error) result =
  Ok (File { name = "notes.txt"; size = 1284; perms = rw;
             owner = Some "alice" })

let missing : (entry, lookup_error) result =
  Error Not_found

let blocked : (entry, lookup_error) result =
  Error Permission_denied
```

Three values of the same `(entry, lookup_error) result` type. The
constructors carry the meaning: `Ok` says success and carries the
found entry; `Error Not_found` and `Error Permission_denied`
distinguish the two failure modes.

:::slide

## Lookup outcome with `result`

A `lookup` function will (in M05) return an entry, or fail in one
of two ways:

```ocaml
type lookup_error = Not_found | Permission_denied
```

```text
val lookup : entry -> string list -> (entry, lookup_error) result
```

- `result` separates "found it" from two **distinct** failures.

:::

:::slide

## Lookup outcome: example values

```ocaml
let rw = { read = true; write = true; exec = false }

let ok : (entry, lookup_error) result =
  Ok (File { name = "notes.txt"; size = 1284; perms = rw;
             owner = Some "alice" })

let missing : (entry, lookup_error) result = Error Not_found
let blocked : (entry, lookup_error) result = Error Permission_denied
```

- Three values of `(entry, lookup_error) result`.
- `Ok` carries the found entry; the two `Error` cases name the
  distinct failure modes.

:::

## The shape of Module 4

This tutorial used the same Module 4 toolkit as the AST tutorial,
applied to a very different domain:

- **Records** (`perms`, the inline records inside each variant).
- **Variants** with payloads (`File`, `Dir`).
- **Recursive variants** (`Dir.contents : entry list`).
- **Lists** (`entry list` for directory contents).
- **`option`** for optional metadata (`owner : string option`).
- **`result`** for a lookup outcome with **two** failure modes.

What we have **not** done is take any of these values apart.
Computing the total size of a directory, listing the names at a
path, finding all `.jpg` files - each is a recursive function on
the tree, and each needs pattern matching. That arrives in
[Module 5](M05-L01-basic-patterns.html), where we will pick this
exact `entry` tree back up.

:::slide

## The shape of Module 4

This tutorial used:

- **Records** (`perms`, inline records inside variants).
- **Variants with payloads** (`File`, `Dir`).
- **Recursive variants** (a `Dir`'s contents).
- **`option`** for optional metadata.
- **`result`** for a lookup outcome with two failure modes.

Module 5: **pattern matching** to walk these trees (`du`, `find`,
`ls` for our tiny FS).

:::

## A quick check

:::quiz mcq id=M04-L06-q2
The `entry` type's `Dir` variant has `contents : entry list`.
Why does that one field make the type *recursive*?

- [ ] Because `Dir` is a variant constructor.
- [x] Because `entry list` refers back to the type being defined.
- [ ] Because `list` is itself a recursive type.
- [ ] Because `File` and `Dir` are mutually recursive.

**Why:** the recursive self-reference is `entry list`. That
single occurrence of `entry` inside its own definition is what
lets `Dir` hold sub-`Dir`s, which can hold further sub-`Dir`s.
Without that reference the tree could only be one level deep:
a directory of files. `File` and `Dir` are not "mutually
recursive" in the OCaml sense; they are the two cases of one
recursive type.
:::

:::quiz mcq id=M04-L06-q3
Why use `owner : string option` instead of `owner : string`
(using `""` to mean "no owner")?

- [ ] `string option` saves memory.
- [ ] The two are equivalent; the choice is purely stylistic.
- [x] It represents “no owner” explicitly as `None`.
- [ ] `string option` is required by OCaml whenever a field
      may be missing.

**Why:** this is the "make illegal states unrepresentable"
slogan from the recursive-types lecture. With `owner : string`,
the absence of an
owner is encoded as a sentinel (the empty string), and the
compiler cannot tell that sentinel apart from a genuine owner
named `""`; you would rely on every reader remembering to
check. With `owner : string option`, the two cases are
separate constructors (`None` vs `Some _`), and the type
system forces every consumer to handle both.
:::

## Activity: a new kind of entry

:::slide

## Activity

Extend `entry` with a new constructor `Symlink` carrying a
`name` and a `target` (both strings). Then construct a directory
whose `contents` list contains:

- the regular file `notes.txt` from earlier, and
- a symlink named `"latest.txt"` whose `target` is `"notes.txt"`.

:::

:::quiz mcq id=M04-L06-q1
Which of these is the correct constructed value?

```text
type entry =
  | File of { name : string; size : int; perms : perms }
  | Dir of { name : string; perms : perms; contents : entry list }
  | Symlink of { name : string; target : string }   (* new *)
```

- [x] `Dir { name = "alice"; perms = rx; contents = [notes; Symlink { name = "latest.txt"; target = "notes.txt" }] }`
- [ ] `Dir { name = "alice"; perms = rx; contents = [notes; "latest.txt" -> "notes.txt"] }`
- [ ] `Symlink { name = "alice"; target = "notes.txt" }`
- [ ] `Dir { name = "alice"; perms = rx; contents = [File { name = "latest.txt"; target = "notes.txt" }] }`

**Why:** the directory holds a list of `entry` values. The first
element is the existing file `notes`; the second is a fresh
`Symlink { ... }` value with the two required string fields.
The second option uses a notation that is not OCaml; the third
makes the directory itself a symlink; the fourth tries to give
`File` a `target` field that does not exist in the `File`
constructor's payload (it would not type-check).
:::

:::slide

## Activity discussion: new constructor

Add one constructor:

```text
type entry =
  ...
  | Symlink of { name : string; target : string }   (* new *)
```

- Inline-record payload with two `string` fields.
- Files, dirs, and symlinks all share the `entry` type.

:::

:::slide

## Activity discussion: constructed value

```text
let notes =
  File { name = "notes.txt"; size = 1284; perms = rw }

let latest =
  Symlink { name = "latest.txt"; target = "notes.txt" }

let alice =
  Dir { name = "alice"; perms = rx;
        contents = [notes; latest] }
```

- A directory whose `contents` mixes a file and a symlink.

:::

## What you should be able to do now

:::slide

## What you should be able to do now

After Module 4 you can:

- Model a domain (AST, file system, anything) as records +
  variants.
- Express recursion in the type when the data is recursive.
- Reach for `option` / `result` instead of nulls / sentinels.
- Pick between the construction-side trade-offs (per-op vs
  generic, list vs map, separate variant vs option) thoughtfully.

Module 5: pattern matching, the everyday way to take any of these
trees apart.

:::

You have now seen the same construction toolkit applied to two
domains: an [AST for OCaml](M04-L05-tutorial.html) and a small
file system (this tutorial). The shapes are very different; the ingredients are the
same. That is the through-line for Module 4: variants + records +
recursion is enough to describe almost any data you will encounter.
[Module 5](M05-L01-basic-patterns.html) gives you the matching
syntax to take these values apart.

## Reading

- **Cornell CS3110**, *Algebraic data types*:
  <https://cs3110.github.io/textbook/chapters/data/algebraic_data_types.html>
- **Real World OCaml**, *Variants*:
  <https://dev.realworldocaml.org/variants.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
