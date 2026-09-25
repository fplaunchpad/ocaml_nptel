---
title: "Variants (sum types)"
lecture_no: 3
week: 4
youtube_id: a10Lc5Tva7o
duration_target_min: 24
concepts: [variants, sum types, constructors, payloads, parameterised variants]
keywords: [OCaml, variant, sum type, constructor, ADT, algebraic data type]
activity_question: "Design a variant [light] for a traffic-light controller with four states: [Red], [Green], [Yellow of int] (seconds remaining), and [Off]. Declare the type and construct one example value of each constructor."
think_about_this: "If you wanted to add a [Triangle] case to the [shape] type, what files in a real codebase would you have to touch? What does the compiler do for you, and what does it not?"
reading:
  - title: "Cornell CS3110, Variants"
    url: https://cs3110.github.io/textbook/chapters/data/variants.html
  - title: "Cornell CS3110, Algebraic data types"
    url: https://cs3110.github.io/textbook/chapters/data/algebraic_data_types.html
  - title: "Real World OCaml, Variants"
    url: https://dev.realworldocaml.org/variants.html
---

# Variants (sum types)


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Variants (sum types)</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[Tuples](M04-L01-tuples.html) and
[records](M04-L02-records.html) express *and*: a 2D point has an
`x` *and* a `y`; a person has a name *and* an age *and* an email.
Variants express *or*: a `shape` is a circle *or* a square *or* a
rectangle; the result of parsing is a success *or* a failure; a
value in an arithmetic expression is a number *or* a sum *or* a
product. Almost every interesting data type you will design in
OCaml is a combination of these two: variants for the "kinds,"
records (or tuples) for the data inside each kind.

The name *variant* refers to the fact that a value of a variant
type *varies* between several possibilities. The names *sum type*
and *disjoint union* refer to the underlying set theory: the set
of values of a variant is the disjoint union of the sets of values
of its alternatives. The two names you will hear most often in
practice are *variant* (OCaml's term) and *tagged union* (the
implementation view: each value carries a tag identifying which
alternative it is, plus the payload data for that alternative).
*Algebraic data type* is the umbrella term that combines variants
and records.

If you have used C, the closest analogue is `enum` plus a tagged
`union` plus the programmer discipline to keep the tag and the
union consistent. OCaml folds all three into a single declaration
and asks the compiler to enforce the consistency. If you have used
Rust, the same idea appears as `enum`; if you have used Java with
sealed interfaces or Kotlin with sealed classes, the same idea
appears there too. Each of these is following the lead of the
ML family, where variants have been around since the 1970s.

:::slide

## Product types vs. sum types

- [Tuples](M04-L01-tuples.html) and
  [records](M04-L02-records.html) are **product types**: AND.
  - A `point` has an `x` *and* a `y`.
  - A `person` has a `name` *and* an `age` *and* an `email`.
- **Variants** are **sum types**: OR.
  - A `shape` is a `Circle` *or* a `Square` *or* a `Rectangle`.
  - A parse result is `Ok` *or* `Error`.
- Like a C / Java `enum`, but each alternative can carry data.
- Most useful data types combine both: variants for the *kinds*,
  records / tuples for the data inside each kind.

:::

## Type aliases

Before getting to variants proper, one bit of supporting syntax.
OCaml lets you give a short name to an existing type. This is
called a *type alias* (or *type abbreviation*):

```ocaml
type point = float * float
type points = point list
```

After these declarations, `point` and `float * float` are *the
same type*; the compiler treats them as interchangeable. The name
exists purely for readability. `points` is `point list`, which is
`(float * float) list`. Three names for the same type, depending
on what you want to emphasise at each call site.

```ocaml
type point = float * float
let origin : point = (0.0, 0.0)
```

:::slide

## Type aliases

```ocaml
type point = float * float
type points = point list
```

- `point` and `float * float`: the **same type**.
- Compiler treats them interchangeably; names are for
  *readability*, not type safety.

```ocaml
let origin : point = (0.0, 0.0)
```

:::

Aliases are useful when the underlying type is verbose, when the
same compound type shows up in many signatures, or when the name
carries information beyond the structure. They are *not* useful
when you want type safety between two structurally-identical
concepts. `type ms = int` and `type fps = int` are both `int` to
the compiler; you can freely substitute one for the other. For
real type safety here, you need a [record](M04-L02-records.html)
or a single-constructor variant (see below).

## Declaring a variant: the enum case

The simplest variant is one whose alternatives carry no data:

```ocaml
type direction = North | South | East | West

let d = North
```

Four *constructors* (`North`, `South`, `East`, `West`), separated
by `|`. A value of type `direction` is exactly one of these four.

:::slide

## Declaring a variant

```ocaml
type direction = North | South | East | West

let d = North
```

- Four *constructors*, separated by `|`.
- Constructors are **capitalized**.
- A `direction` value holds *exactly one* of the four.
- The OCaml equivalent of an `enum`.

:::

The capitalisation is mandatory: OCaml uses the first character of
an identifier to distinguish a *constructor* (starts with capital,
denotes a variant case) from a *variable* (starts with lowercase,
denotes a binding). The compiler tells the two apart by lexical
rule alone, which saves you from ambiguity later when we get to
patterns.

A value of type `direction` is just one of the four named tags.
There is no implicit numeric encoding (C lets you write `North = 0`
and treat directions as ints; OCaml does not). If you want a
mapping to ints, write a function:

```ocaml
type direction = North | South | East | West

let int_of_direction d =
  if d = North then 0
  else if d = South then 1
  else if d = East  then 2
  else 3
```

This is more verbose than C's implicit enumeration, but it is
explicit: the mapping is in *one place*. (We will see in
[Module 5](M05-L01-basic-patterns.html) how `match` makes this
cascade much tidier, and how the compiler can warn you if a case
is missing.)

## Combining variants and records: a card

The domain often has more than one axis of choice. A playing card
has a *suit* and a *rank*, each independent of the other. Each
axis is a small enum variant; the card itself is a
[record](M04-L02-records.html) that bundles both:

```ocaml
type suit = Spades | Hearts | Diamonds | Clubs

type rank =
  | Two | Three | Four | Five | Six | Seven | Eight | Nine | Ten
  | Jack | Queen | King | Ace

type card = { suit : suit; rank : rank }

let ace_of_spades = { suit = Spades; rank = Ace }
let two_of_hearts = { suit = Hearts; rank = Two }
```

Two enum-case variants and one record that combines them. The
variants capture "exactly one of these alternatives"; the record
captures "all of these together". A `card` is therefore "this
suit *and* this rank", drawn from the 4 x 13 = 52 combinations.

This is the everyday shape of Module 4 data: variants for the
axes of choice, records for the bundling. Recursion in the
variants (lists, trees, expressions) is the topic of the next
lecture.

:::slide

## Combining variants and records: a card

```ocaml
type suit = Spades | Hearts | Diamonds | Clubs

type rank =
  | Two | Three | Four | Five | Six | Seven | Eight | Nine | Ten
  | Jack | Queen | King | Ace

type card = { suit : suit; rank : rank }

let ace_of_spades = { suit = Spades; rank = Ace }
```

- Two enum variants (the *axes* of choice).
- One record (the *bundling*).
- A card is "this suit AND this rank" - 4 x 13 = 52 in total.

:::

:::slide

## Variants AND records, side by side

The two Module 4 building blocks answer two different questions:

- **Variant** = "which *one* of these?" (a sum).
- **Record** = "all of these *together*?" (a product).

Most domain types reach for both. Variants for the axes of
choice; records for the bundling.

Next lecture: recursion in the variants - lists, trees,
arithmetic expressions.

:::

## Constructors with payload

A variant becomes much more interesting when its constructors carry
data. This is the syntax for *attaching* data to a constructor:

```ocaml
type shape =
  | Circle of float
  | Square of float
  | Rectangle of float * float

let c = Circle 3.0
let s = Square 5.0
let r = Rectangle (4.0, 6.0)
```

Each `of TYPE` clause specifies what data the constructor carries.
`Circle of float` says "a `Circle` carries one `float` (its
radius)"; `Rectangle of float * float` says "a `Rectangle` carries
two `float`s (its width and height)."

:::slide

## Constructors with payload

```ocaml
type shape =
  | Circle of float
  | Square of float
  | Rectangle of float * float

let c = Circle 3.0
let s = Square 5.0
let r = Rectangle (4.0, 6.0)
```

- `Circle of float`: radius. `Square of float`: side.
- `Rectangle of float * float`: width, height.
- All three are values of type `shape`.
- Constructor says *which kind*; payload is the data for that kind.

:::

A constructor is *applied* to its payload by juxtaposition (like a
function call without parentheses): `Circle 3.0`, `Square 5.0`. For
constructors that take multiple components, the payload is a tuple,
wrapped in parens: `Rectangle (4.0, 6.0)`. The parentheses around
the tuple are required when the tuple has more than one component
and the constructor takes a tuple payload.

`Rectangle` does *not* take two arguments. It takes *one*
argument, which happens to be a pair. The type `float * float`
in `of float * float` is a single tuple type, not "two
arguments." This matters for pattern matching: you write
`Rectangle (w, h)` (one pair-pattern, parens required), not
`Rectangle w h` (which would not parse).

## Using a variant: forward-pointer to pattern matching

To *use* a variant value, we need a language feature that
inspects a value and dispatches on which constructor was used,
binding the payload along the way. That feature is *pattern
matching*, the subject of
[Module 5](M05-L01-basic-patterns.html). Pattern matching also
brings two compiler-checked guarantees you will lean on heavily:

- **Exhaustiveness**: the compiler tracks every constructor of
  the variant and warns if your code forgets a case.
- **Refactor-with-the-compiler**: when you add a new
  constructor, the compiler flags every site that pattern-matches
  on the type, giving you a punch list of places to update.

The combination of variants + pattern matching is the engine of
nearly every interesting OCaml program: interpreters, parsers,
type checkers, network protocol decoders, configuration loaders,
web routers. We will spend Module 5 on it.

## Constructors with multi-field payloads: inline records

When a constructor's payload has more than one or two components,
the tuple form (`Constructor of t1 * t2 * t3`) becomes unwieldy.
For these cases, OCaml supports *inline records* as constructor
payloads:

```ocaml
type tcp_state =
  | Listening
  | Connecting of { peer : string }
  | Connected of { peer : string; bytes_sent : int }
  | Closed of { reason : string }
```

Each non-trivial state carries the data relevant to that state,
and each piece of data has a name. Constructing values works the
same as before, but with the field-name syntax:

```ocaml
let s1 = Listening
let s2 = Connecting { peer = "10.0.0.1" }
let s3 = Connected  { peer = "10.0.0.1"; bytes_sent = 4096 }
```

Extracting the data uses pattern matching with the inline-record
syntax on the pattern side, which we will see in
[Module 5](M05-L03-nested-and-or-patterns.html#inline-records-inside-constructors).

:::slide

## Constructors with named-field payloads

```ocaml
type tcp_state =
  | Listening
  | Connecting of { peer : string }
  | Connected of { peer : string; bytes_sent : int }
  | Closed of { reason : string }
```

- Four states; each carries only the data it needs.
- `Listening`: no payload.
- `{ ... }` after `of`: an **inline record** payload.
- Use when names beat positions.

:::

This is OCaml's version of Rust's struct-style enums:

```rust
enum TcpState {
    Listening,
    Connected { peer: String, bytes_sent: usize },
}
```

The inline record syntax was added to OCaml in 4.03 (2016) and has
become idiomatic for variant payloads of more than two pieces of
data.

Variants are *pervasive* in OCaml: `bool`, `list`, `option`,
and `result` are all variants. We will see the
recursive ones (`list`, trees, expressions) in the
[next lecture](M04-L04-recursive-types.html), where they are also
the natural setting to introduce *parameterised variants* (lists
of *anything*, trees of *anything*) and *polymorphism*.

## A small check

:::quiz mcq id=M04-L03-q2
Given:

```ocaml
type shape =
  | Circle of float
  | Square of float
  | Rectangle of float * float
```

Consider these constructor applications:

1. `Circle 3.0`
2. `Square "5"`
3. `Rectangle (4.0, 6.0)`
4. `Triangle 5.0`

Which set contains **all and only** the valid applications?

- [ ] 1 and 2
- [x] 1 and 3
- [ ] 2 and 4
- [ ] 3 and 4

**Why:** each constructor is applied to a payload that matches its
declared type. `Circle 3.0` and `Rectangle (4.0, 6.0)` are
well-typed values of type `shape`. `Square "5"` has a `string`
payload where the type says `float`; the compiler rejects it.
`Triangle` is not a constructor of `shape`, so the compiler reports
`Unbound constructor Triangle`.
:::

:::quiz code id=M04-L03-q1
Design a variant `http_response` for HTTP responses. Cover three
shapes:

- A `Success` carrying the response `body : string`.
- A `Redirect` carrying the target `url : string`.
- An `Error` carrying an inline record
  `{ code : int; message : string }`.

Then construct one example value of each constructor.

```ocaml
(* declare http_response here *)
type http_response = unit

(* construct one example of each *)
let example_success  = ()
let example_redirect = ()
let example_error    = ()
```

```ocaml skip
(* The checker uses patterns to inspect the constructors.
   You will learn to write these patterns in M05. *)
let check b m = if not b then failwith m
let () =
  check (match (example_success : http_response) with
         | Success (_ : string) -> true | _ -> false)
    "example_success must use Success with a string";
  check (match (example_redirect : http_response) with
         | Redirect (_ : string) -> true | _ -> false)
    "example_redirect must use Redirect with a string";
  check (match (example_error : http_response) with
         | Error { code = (_ : int); message = (_ : string) } -> true
         | _ -> false)
    "example_error must use Error with code and message";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type http_response =
  | Success of string
  | Redirect of string
  | Error of { code : int; message : string }

let example_success  = Success "<html>hello</html>"
let example_redirect = Redirect "https://example.com/new-page"
let example_error    = Error { code = 404; message = "not found" }
```

The `Error` case uses an inline record because two named fields
read more cleanly than `Error of int * string`.

:::

## Activity

:::slide

## Activity

Design a variant for a traffic-light controller. Cover four states:

- `Red`, `Green` (no payload).
- `Yellow of int` (seconds remaining).
- `Off` (no payload, e.g. an outage).

Declare the type and construct one example value of each
constructor.

:::

:::solution

:::slide

## Activity solution

```ocaml
type light =
  | Red
  | Green
  | Yellow of int
  | Off

let l1 = Red
let l2 = Green
let l3 = Yellow 3
let l4 = Off
```

- Three constructors with no payload; one carries `int`.
- Each value has type `light`.
- *How* to use a `light` (dispatching on the state) is M05's job.

:::

:::

Notice how the lecture has so far only *declared* variant types
and *constructed* values of them. We have not written a single
function that takes a variant apart. That deconstruction step is
exactly what pattern matching gives us, and we will spend the
whole of [Module 5](M05-L01-basic-patterns.html) on it.

## What's next

:::slide

## What's next

Lecture 4: **recursive types**. Variants whose payloads include
the type being defined. Lists, trees, expressions, JSON values fit
this shape. The recursive case lets ADTs describe unbounded
data, not just fixed alternatives.

:::

We have seen variants with *fixed* payloads: a `Circle` always
carries one float. The
[next lecture](M04-L04-recursive-types.html) lets a constructor's
payload include a value of *the type being defined*. That is the
doorway to lists, trees, and arbitrary tree-shaped data.

## Reading

- **Cornell CS3110**, *Variants*:
  <https://cs3110.github.io/textbook/chapters/data/variants.html>
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
