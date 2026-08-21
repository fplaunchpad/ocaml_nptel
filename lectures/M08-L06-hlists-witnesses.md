---
title: "GADTs: hlists and witnesses"
lecture_no: 6
week: 8
duration_target_min: 22
concepts: [heterogeneous list, hlist, type witness, generic programming, fold over witnesses]
keywords: [OCaml, GADT, hlist, witness, Format, printf]
activity_question: "Write [length_hlist : type ix. ix hlist -> int] that returns the number of elements in a heterogeneous list. (No witnesses needed: counting ignores the element values.)"
think_about_this: "[Printf.printf]'s format strings have a type that depends on the literal characters in the string. That dependency is encoded with GADTs of essentially the same shape we build in this lecture. Where else have you seen a value's type depend on another value's contents?"
reading:
  - title: "Real World OCaml, More GADTs"
    url: https://dev.realworldocaml.org/gadts.html
---

# GADTs: hlists and witnesses


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">GADTs: hlists and witnesses</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[The GADT basics lecture](M08-L04-gadts-basics.html) showed GADTs
with a single type index (the `int expr` / `bool expr` AST).
[The use-cases lecture](M08-L05-gadts-use-cases.html) built a typed
pretty-printer, `show : 'a ty -> 'a -> string`, that read a witness
(`T_int`, `T_string`, ...) to decide how to render *one* value. This
lecture lifts that from a single value to a whole *heterogeneous
list* (an "hlist"): a list whose elements may have different types,
all tracked at the type level. We pair the hlist with a *list of
witnesses*, one per element, and reuse `show` on each. The result is
a clean answer to "how do I write a generic operation across a
fixed-but-mixed collection of typed values?"

This pattern is the engine behind OCaml's `Format` module: every
`%d`, `%s`, `%b` in a format string is a witness, and `printf`
folds across them. We will sketch the connection at the end.

:::slide

## This lecture

- Start from last lecture's typed pretty-printer `show`, lifted to
  a *list*.
- **Heterogeneous lists** (hlists): lists with different element
  types tracked in the type.
- **Witness list**: reuse last lecture's `ty` witness, one per
  element, indexed to match the hlist.
- `pp_hlist`: last lecture's `show`, folded across the whole list.
- Aside: OCaml's `Printf.printf` uses GADTs of this shape.

:::

## Why we need hlists

An ordinary `'a list` requires every element to share `'a`. A
tuple like `(int, string, bool)` works for a fixed shape but does
not let you recurse over its elements; there is no "fold over a
tuple". When you need a *fixed-shape but mixed-typed* collection
that you can also recurse over, the OCaml answer is an hlist.

:::slide

## When you reach for an hlist

- Ordinary `list`: every element has the same type.
- Tuple: a fixed shape, but no recursion across elements.
- **hlist**: each element can have a different type, *and* you
  can recurse across them.

Use cases:

- Database rows where each column has a known type.
- Function arguments with a known number and pattern of types.
- Heterogeneous configuration bundles.
- The implementation of typed `printf`.

:::

The encoding uses GADTs (so each `HCons` cell can carry its own
type for the head while preserving the rest in the tail's type)
plus a nested-pair convention in the type parameter to record the
sequence of element types.

## Defining the hlist GADT

The two constructors are `HNil` (the empty hlist) and `HCons`
(prepend an element of any type to an existing hlist):

:::slide

## The hlist GADT

```ocaml
type _ hlist =
  | HNil  : unit hlist
  | HCons : 'a * 'rest hlist -> ('a * 'rest) hlist

let hl : (int * (string * (bool * unit))) hlist =
  HCons (42, HCons ("hi", HCons (true, HNil)))
```

- `HNil : unit hlist` is the base case.
- `HCons (x, rest) : ('a * 'rest) hlist` records `x`'s type as the
  *head* of the index pair.
- The type `(int * (string * (bool * unit))) hlist` says "an int,
  then a string, then a bool, then end".

:::

Read the index type from the outside in: the outermost component
of the tuple is the first element's type; the rest is the index
of the tail. `HNil`'s index is `unit`, which is the "we are done"
marker. The encoding lets the compiler keep track of the entire
sequence of element types.

`HCons (42, HCons ("hi", HCons (true, HNil)))` builds the example
above. Its type is `(int * (string * (bool * unit))) hlist`, which
spells out the sequence: int, string, bool, end.

## Pattern-matching an hlist

A function that pulls the head off an hlist must use `type a r.`
to allow refinement, just like every GADT pattern match:

:::slide

## Reading the first element

```ocaml
type _ hlist =
  | HNil  : unit hlist
  | HCons : 'a * 'rest hlist -> ('a * 'rest) hlist

let hhead : type a r. (a * r) hlist -> a = function
  | HCons (x, _) -> x

let _ = hhead (HCons (42, HCons ("hi", HNil)))  (* = 42 *)
```

The signature says: given an hlist whose index starts with `a`,
return an `a`.

- `HCons (x, _)` matches the only constructor that produces an
  `('a * 'r) hlist`.
- The compiler refines `a` to the head's type at this branch.

:::

The function's type `(a * r) hlist -> a` rules out applying
`hhead` to `HNil`, because `HNil : unit hlist` and `unit` does
not match the shape `a * r`. The compiler verifies this at the
call site: you cannot accidentally take the head of an empty hlist.

## A witness list for the hlist

To *print* an element we need to know its type at runtime, and that
is exactly the witness `ty` from
[the previous lecture's pretty-printer](M08-L05-gadts-use-cases.html). We reuse
it unchanged. The one new idea: pair a whole *list* of those
witnesses with the hlist, indexed by the **same** type, so each
witness sits opposite the element it describes.

:::slide

## A witness list matching the hlist

```ocaml
type _ ty =                     (* the witness from last lecture *)
  | T_int    : int ty
  | T_string : string ty
  | T_bool   : bool ty

type _ tylist =                 (* one witness per element *)
  | TyNil  : unit tylist
  | TyCons : 'a ty * 'rest tylist -> ('a * 'rest) tylist

let tys : (int * (string * (bool * unit))) tylist =
  TyCons (T_int, TyCons (T_string, TyCons (T_bool, TyNil)))
```

- `tylist` mirrors `hlist`: the same `unit` / `'a * 'rest` index.
- **Witness list and hlist share one index**, so a witness
  lines up with each element and any mismatch is rejected.

:::

That shared index is the whole trick: an `hlist` of shape
`(int * (string * (bool * unit)))` demands a `tylist` of the same
shape, so the two recurse together with a witness always opposite
its value.

## Generic pretty-printer: `pp_hlist`

Now the payoff: one recursive function walks both structures in
lock-step, using each witness to render its element.

:::slide

## `pp_hlist`: walking both in lock-step

```ocaml
let pp_one : type a. a ty -> a -> string =  (* last lecture's show *)
  fun t v -> match t with
  | T_int    -> string_of_int v
  | T_string -> "\"" ^ v ^ "\""
  | T_bool   -> string_of_bool v

let rec pp_hlist : type ix. ix tylist -> ix hlist -> string list =
  fun tys hl ->
    match tys, hl with
    | TyNil, HNil -> []
    | TyCons (t, trest), HCons (v, vrest) ->
        pp_one t v :: pp_hlist trest vrest
```

- `pp_one` is last lecture's `show`, on the three primitive
  witnesses.
- `pp_hlist` folds it over both structures in lock-step; the shared
  index `ix` forces witness and hlist to align.

:::

:::slide

## Running `pp_hlist`

```ocaml
let tys : (int * (string * (bool * unit))) tylist =
  TyCons (T_int, TyCons (T_string, TyCons (T_bool, TyNil)))

let hl : (int * (string * (bool * unit))) hlist =
  HCons (42, HCons ("hi", HCons (true, HNil)))

let _ = pp_hlist tys hl   (* = ["42"; "\"hi\""; "true"] *)
```

- Each element printed using its corresponding witness.
- The compiler verifies that 42 lines up with `T_int`, `"hi"` with
  `T_string`, `true` with `T_bool`.
- A mismatched pair would be a compile error.

:::

Read what just happened. We wrote one recursive function that
walks the hlist *and* the parallel witness list, dispatching on
the witness to choose how to render each element. We could write
`fold_hlist` of the same shape, or `map_hlist`, or whatever pattern
fits the problem.

The compiler refines `ix` (the shared index) at each `TyCons /
HCons` step. In the body, `t : 'a ty` and `v : 'a` for the same
`'a` at this position. The compiler keeps the witness and the
value aligned every step of the recursion.

## What if the witness disagrees with the value?

This is where the type system saves us. Try mismatching the
witnesses and the values:

:::slide

## Mismatching witness and value: compile error

```ocaml skip
let tys' : (int * (string * unit)) tylist =
  TyCons (T_int, TyCons (T_string, TyNil))

let hl' : (string * (int * unit)) hlist =
  HCons ("oops", HCons (5, HNil))

let _ = pp_hlist tys' hl'
```

```text
Error: This expression has type (string * (int * unit)) hlist
       but an expression was expected of type
         (int * (string * unit)) hlist
       Type string is not compatible with type int
```

- The witness list claims "int, then string".
- The hlist actually carries "string, then int".
- The compiler rejects the call.

:::

The signature `pp_hlist : 'ix tylist -> 'ix hlist -> string list`
shares one type variable. The compiler unifies the witness list's
index with the hlist's index; if they disagree, the call does not
compile. We get type-safe generic programming for free.

This is the design strength of GADTs: a single shared type
parameter across two structures pins down a constraint that would
otherwise be a runtime "I hope the types match" assertion.

## Closing aside: `Printf.printf` does the same thing

OCaml's `Printf.printf` (and its `Format` cousin) work by exactly
this mechanism, but the witness list is encoded inside the format
string. When you write `Printf.printf "%d %s %b\n"`, the compiler
parses the format string into a witness list of essentially the
shape `TyCons (T_int, TyCons (T_string, TyCons (T_bool, TyNil)))`
and uses it to insist on `int -> string -> bool -> unit` as the
type of the remaining call.

:::slide

## `Printf.printf`: a witness list in disguise

```ocaml
let _ = Printf.printf "%d %s %b\n" 42 "hi" true   (* prints 42 hi true *)
```

- The compiler reads `"%d %s %b\n"` and synthesises an internal
  type like `int -> string -> bool -> unit`.
- The arguments must match by type, in order.
- A wrong argument type is a compile error, *not* a runtime crash.

You will not implement `printf` in this course. You use it every
day; the implementation uses GADTs of essentially the shape we
built above.

:::

The technical details of OCaml's `format` GADT are involved (the
encoding is more elaborate to handle alignment, padding, and other
format specifiers). The principle is the one we just demonstrated:
a list of witnesses, walked in parallel with a list of values, with
the compiler enforcing alignment.

This is what we mean when we say GADTs are everywhere in OCaml,
quietly. Every time you call `printf` you are touching the
infrastructure; you do not have to build it yourself.

## When *not* to reach for hlists

The general [when-to-reach-for-GADTs
guidance](M08-L04-gadts-basics.html#when-to-reach-for-gadts)
applies; hlists add one more choice to make. A plain `list`, a
record, or a tuple is usually what you want:

:::slide

## When *not* to use an hlist

- For a list of items of one type: ordinary `list`.
- For a fixed small tuple: a plain tuple or record.
- For a long sequence of *mixed* types you need to recurse over:
  hlist is the right tool.
- If you find yourself reaching for hlists for "convenience", you
  probably want a record with named fields instead.

:::

Hlists are a power tool. Reach for them when you have a real
problem (database row types, format strings, typed-DSL argument
lists) and not just to be clever.

## A quick check

:::quiz mcq id=M08-L06-q3
Why does `pp_hlist : 'ix tylist -> 'ix hlist -> string list` use
*the same* type variable `'ix` for both arguments?

- [ ] OCaml requires identical type variables for argument pairs.
- [x] It makes the witness and value share one type sequence.
- [ ] It is purely cosmetic.
- [ ] It makes the function faster.

**Why:** the *whole point* of using witnesses is that the compiler
can pair up the witness's claim ("this slot is an int") with the
value's actual type. Sharing `'ix` is what wires that together. If
the two parameters used different type variables, the compiler
would accept mismatched calls, defeating the purpose.
:::

:::quiz mcq id=M08-L06-q2
What is the index type of `HCons (1, HCons (true, HNil))`?

- [ ] `int * bool`
- [ ] `(int * bool) hlist`
- [x] `int * (bool * unit)`
- [ ] `unit * (bool * (int * unit))`

**Why:** the type index of an hlist is a right-nested pair, with
the head element's type at the outermost position. Two elements,
int then bool, give `int * (bool * unit)`. The `unit` at the end
is the `HNil`-marker. Reading from left to right gives the order
the elements were prepended.
:::

## Activity

:::slide

## Activity

Write `length_hlist : type ix. ix hlist -> int` that returns the
number of elements in an hlist. (Hint: walk the hlist; you do not
need a witness list for this one.)

:::

:::solution

:::slide

## Activity solution

```ocaml
type _ hlist =
  | HNil  : unit hlist
  | HCons : 'a * 'rest hlist -> ('a * 'rest) hlist

let rec length_hlist : type ix. ix hlist -> int = function
  | HNil -> 0
  | HCons (_, rest) -> 1 + length_hlist rest

let _ = length_hlist (HCons (1, HCons ("hi", HCons (true, HNil))))  (* = 3 *)
let _ = length_hlist HNil                                           (* = 0 *)
```

- The `type ix. ...` annotation lets the compiler refine `ix` per
  branch (to `unit` for `HNil`, to `'a * 'rest` for `HCons`).
- The function ignores the *value* of each element; it only counts
  how many there are.
- No witness list needed because counting is value-agnostic.

:::

:::

A code quiz to consolidate the witness-driven pattern:

:::quiz code id=M08-L06-q1
Write `sum_int_hlist : (int * (int * unit)) hlist -> int` that
sums a two-element hlist of ints. (No witnesses needed: the *type*
already promises both elements are `int`.)

```ocaml
type _ hlist =
  | HNil  : unit hlist
  | HCons : 'a * 'rest hlist -> ('a * 'rest) hlist

let sum_int_hlist (_ : (int * (int * unit)) hlist) : int =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let hl = HCons (3, HCons (4, HNil)) in
  check (sum_int_hlist hl = 7) "3 + 4 = 7";
  let hl2 = HCons (10, HCons (20, HNil)) in
  check (sum_int_hlist hl2 = 30) "10 + 20 = 30";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let sum_int_hlist (HCons (x, HCons (y, HNil))) = x + y
```

The single pattern destructures the fixed-shape hlist down to its
two `int` elements. The type signature is enough to convince
OCaml that the pattern is exhaustive (no other shape can have
index `int * (int * unit)`). No `type a. ...` annotation needed
because the shape is fully concrete.

:::

## What is next

:::slide

## What is next

Lecture 7: the **Module 8 tutorial**.

- Tie monads and GADTs together.
- Build a tiny well-typed evaluator with a GADT-indexed AST.
- The capstone of the functional half of the course.

:::

The [closing tutorial](M08-L07-tutorial.html) brings monads
and GADTs together one more time. We build a small typed AST
(GADTs), evaluate it with an option monad (`let*`), and close by
showing how the GADT version rejects the
[Module 5 tutorial's](M05-L06-tutorial.html) `bad1` example
(`Add (Bool true, _)`) at compile time, sealing the forward
pointer that opened Module 8.

## Reading

- **Real World OCaml**, *More GADTs*:
  <https://dev.realworldocaml.org/gadts.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The hlist encoding and witness-driven recursion draw
on the author's CS3100 GADTs notebook, used here as a private
structural reference; the surface code, comments, and explanations
are written from scratch. Real World OCaml is CC
BY-NC-ND-licensed and has not been derivatively reused. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
