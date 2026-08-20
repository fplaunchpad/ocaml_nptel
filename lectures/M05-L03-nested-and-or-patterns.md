---
title: "Nested patterns and or-patterns"
lecture_no: 3
week: 5
duration_target_min: 22
concepts: [nested patterns, or-patterns, tuple patterns inside variants, alternation]
keywords: [OCaml, pattern matching, nested patterns, or-patterns, alternation]
activity_question: "Write [is_unit_shape : shape -> bool] returning [true] for [Circle 1.0] or [Rectangle (1.0, 1.0)] and [false] for everything else. Use a single clause with an or-pattern containing nested literal patterns."
think_about_this: "An or-pattern lets multiple shapes share a right-hand side. What constraint does the compiler impose on the variables bound by each alternative?"
reading:
  - title: "Cornell CS3110, Pattern matching (continued)"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
---

# Nested patterns and or-patterns


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Nested patterns and or-patterns</h2>
<p class="title-slide-label">Module 5 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The pattern forms we saw in [Lecture 1](M05-L01-basic-patterns.html)
(literals, variables, wildcards) match a value at exactly one level:
"this is the constant `0`", or "this is anything, call it `x`." Real
OCaml values are usually built out of pieces: a [tuple](M04-L01-tuples.html)
holds two things, a [constructor](M04-L03-variants.html#constructors-with-payload)
wraps a payload, a [list](M04-L04-recursive-types.html#ocamls-built-in-lists-are-just-variants)
is a head followed by a tail. Patterns mirror that nested structure.
A pattern can contain *other patterns* inside it, exactly the way a
value contains other values.

This lecture covers two extensions:

1. **Nested patterns**: a pattern inside another pattern. `Some
   (x, _)` is a pattern with a tuple pattern inside a
   constructor pattern. `(0, _) :: _` is a pattern with a tuple
   inside a cons inside another cons-context.
2. **Or-patterns**: alternation. `1 | 2 | 3` is a pattern that
   matches `1`, `2`, or `3`. Or-patterns let you give several
   shapes the same right-hand side.

Both forms compose, and you will use them heavily. Almost every
nontrivial pattern match you write uses one or both.

:::slide

## This lecture: nested and or-patterns

- Last lecture's patterns matched at *one level* (literal,
  variable, wildcard).
- Real values are built of pieces: tuples, constructors, lists.
- Patterns mirror that nested structure: a pattern can contain
  other patterns.
- Two extensions covered here:
  - *Nested* patterns: `Some (x, _)`, `(0, _) :: _`.
  - *Or-patterns*: `1 | 2 | 3`, alternation with one right-hand side.
- Both compose; almost every nontrivial match uses one or both.

:::

## Patterns inside constructors

The most common nested pattern is to look inside a constructor's
payload. We saw [variant types](M04-L03-variants.html) in Module 4
and you have seen `Some` and `None` and you have seen [records](M04-L02-records.html)
and [lists](M04-L04-recursive-types.html#ocamls-built-in-lists-are-just-variants).
Start with a record. Suppose we want to describe where a point
sits relative to the axes. Without any nesting, you would write
the logic as a cascade of `if`s on the two fields:

```ocaml
type point = { x : float; y : float }

let describe p =
  if p.x = 0.0 && p.y = 0.0 then "origin"
  else if p.x = 0.0 then "on the y-axis"
  else if p.y = 0.0 then "on the x-axis"
  else "somewhere else"

let _ = describe { x = 0.0; y = 0.0 }  (* = "origin" *)
let _ = describe { x = 3.0; y = 0.0 }  (* = "on the x-axis" *)
let _ = describe { x = 1.0; y = 2.0 }  (* = "somewhere else" *)
```

It works, but
the shape of the four cases is buried inside boolean tests. A
record *pattern* with nested field-patterns lets us write the same
function as a single match:

```ocaml
let describe = function
  | { x = 0.0; y = 0.0 } -> "origin"
  | { x = 0.0; y = _   } -> "on the y-axis"
  | { x = _;   y = 0.0 } -> "on the x-axis"
  | { x = _;   y = _   } -> "somewhere else"

let _ = describe { x = 0.0; y = 0.0 }  (* = "origin" *)
let _ = describe { x = 3.0; y = 0.0 }  (* = "on the x-axis" *)
let _ = describe { x = 1.0; y = 2.0 }  (* = "somewhere else" *)
```

Each clause describes a shape: "x is zero and y is zero," "x is
zero and y is anything," and so on. The four shapes are visible
at a glance.

:::slide

## First, without nesting

```ocaml
type point = { x : float; y : float }

let describe p =
  if p.x = 0.0 && p.y = 0.0 then "origin"
  else if p.x = 0.0 then "on the y-axis"
  else if p.y = 0.0 then "on the x-axis"
  else "somewhere else"

let _ = describe { x = 0.0; y = 0.0 }  (* = "origin" *)
let _ = describe { x = 3.0; y = 0.0 }  (* = "on the x-axis" *)
let _ = describe { x = 1.0; y = 2.0 }  (* = "somewhere else" *)
```

- Four cases, but the shapes are hidden inside `if`s.
- Each case tests `p.x` and `p.y` separately.
- Works, but reads top-down rather than shape-by-shape.

:::

:::slide

## Same logic, with nested patterns

```ocaml
type point = { x : float; y : float }

let describe = function
  | { x = 0.0; y = 0.0 } -> "origin"
  | { x = 0.0; y = _   } -> "on the y-axis"
  | { x = _;   y = 0.0 } -> "on the x-axis"
  | { x = _;   y = _   } -> "somewhere else"

let _ = describe { x = 0.0; y = 0.0 }  (* = "origin" *)
let _ = describe { x = 3.0; y = 0.0 }  (* = "on the x-axis" *)
let _ = describe { x = 1.0; y = 2.0 }  (* = "somewhere else" *)
```

- The values after `=` are themselves patterns.
- A literal `0.0`, a wildcard `_`. **Nested**.
- The four shapes line up visually.

:::

Notice that inside the curly braces, we are not just listing
field names: each field is matched against a *pattern*. `x =
0.0` is the field-match pattern "`x` must equal `0.0`." `y = _`
is "`y` can be anything." Both are sub-patterns of the larger
record pattern. When you read the clause `{ x = 0.0; y = 0.0 }`,
read it as: this record's `x`-field matches `0.0`, *and* its
`y`-field matches `0.0`. Both must hold.

## Record patterns: name only the fields you need

Often you do not want to match on values at all; you just want
to *bind* the fields you need and ignore the rest. The
shorthand form drops the `=` and uses just the field name:

```ocaml
type user = { name : string; age : int; admin : bool }

let summary { name; age; _ } =
  Printf.sprintf "%s, age %d" name age

let _ = summary { name = "Alice"; age = 30; admin = true }  (* = "Alice, age 30" *)
```

`{ name; age; _ }` does three things at once: it matches any
`user` record (the type is inferred from the field names), binds
`name` and `age` locally, and the trailing `_` says "there are
other fields; I am ignoring them on purpose."

Without the trailing `_`, OCaml warns:

```text
Warning 9 [missing-record-field-pattern]: the following labels
are not bound in this record pattern: admin
```

This warning is worth keeping on: when the record gains a new
field later, every existing pattern lights up so you decide
case-by-case whether the new field matters. With `_`, you opt
out of that warning for *this* pattern, saying "I have seen the
new field, and I do not need to update this site."

The shorthand `{ name; age }` (no equals signs) is the everyday
form. The longer `{ name = name; age = age }` is equivalent but
verbose. Use the short form unless you want to rename a field
locally.

:::slide

## Record patterns: name only the fields you need

```ocaml
type user = { name : string; age : int; admin : bool }

let summary { name; age; _ } =
  Printf.sprintf "%s, age %d" name age

let _ = summary { name = "Alice"; age = 30; admin = true }  (* = "Alice, age 30" *)
```

- `{ name; age; _ }` binds `name` and `age`; `_` ignores the rest.
- Sugar for `{ name = name; age = age }`.
- Without `_`, OCaml warns (warning 9) about unhandled fields.
- The warning is your refactoring aid when the record grows.

:::

## Renaming a field on the way in

Sometimes you want to bind a field to a *different* name. The
syntax is `{ field = local_name }`, the same form as the
value-match record but with a variable pattern instead of a
literal:

```ocaml
type user = { name : string; age : int; admin : bool }

let role { name = n; admin } =
  if admin then n ^ " (admin)" else n

let _ = role { name = "Bob";   age = 25; admin = true }  (* = "Bob (admin)" *)
let _ = role { name = "Carol"; age = 28; admin = false }  (* = "Carol" *)
```

`name = n` says "match the `name` field, and call it `n`
locally." `admin` alone uses the shorthand (sugar for `admin =
admin`).

When you explicitly list one or more specific fields, ignoring
the rest is implicit (no `_` needed). Some codebases write `_`
anyway to make the intent more visible. Both styles are common.

:::slide

## Renaming a field on the way in

```ocaml
type user = { name : string; age : int; admin : bool }

let role { name = n; admin } =
  if admin then n ^ " (admin)" else n

let _ = role { name = "Bob";   age = 25; admin = true }  (* = "Bob (admin)" *)
let _ = role { name = "Carol"; age = 28; admin = false }  (* = "Carol" *)
```

- `{ name = n; admin }` renames `name` to local `n`.
- `admin` alone is shorthand for `admin = admin`.
- Listing only some fields: "ignore the rest" is implicit.

:::

## Patterns inside a variant constructor

A pattern can also nest inside a variant constructor:

```ocaml
type shape =
  | Circle of float
  | Rectangle of float * float

let is_unit_circle = function
  | Circle 1.0 -> true
  | _ -> false

let _ = is_unit_circle (Circle 1.0)             (* = true *)
let _ = is_unit_circle (Circle 2.0)             (* = false *)
let _ = is_unit_circle (Rectangle (1.0, 1.0))   (* = false *)
```

:::slide

## Tuple/value inside a variant

```ocaml
type shape =
  | Circle of float
  | Rectangle of float * float

let is_unit_circle = function
  | Circle 1.0 -> true
  | _ -> false

let _ = is_unit_circle (Circle 1.0)             (* = true *)
let _ = is_unit_circle (Circle 2.0)             (* = false *)
let _ = is_unit_circle (Rectangle (1.0, 1.0))   (* = false *)
```

- `Circle 1.0` requires the constructor to be `Circle`.
- **And** its payload must be exactly `1.0`.
- Two checks combined into one pattern.

:::

The pattern `Circle 1.0` is a constructor pattern (`Circle`) with
a literal pattern (`1.0`) for its payload. The match succeeds if
both checks succeed: the constructor is `Circle`, *and* its
argument equals `1.0`. If you wrote `Circle x`, the second check
would be "x is anything, bind it to the name `x`." If you wrote
`Circle (_)`, the second check would be "anything, do not bind."
The point is that a constructor's payload position takes any
pattern; you choose how specific to be.

The same nesting works for tuple constructors:

```ocaml
let unit_square = function
  | Rectangle (1.0, 1.0) -> true
  | _ -> false
```

The pattern `Rectangle (1.0, 1.0)` looks for the constructor
`Rectangle` whose payload is the tuple `(1.0, 1.0)`. Two literal
patterns nested inside a tuple pattern inside a constructor
pattern. Three levels.

## Inline records inside constructors

Since OCaml 4.03, a constructor's payload can be a record
declared inline. This is the cleanest way to make a payload's
fields self-documenting, and the pattern destructures the
record exactly like any other record pattern:

```ocaml
type event =
  | Click of { x : int; y : int }
  | Key   of char
  | Quit

let describe = function
  | Click { x; y } -> Printf.sprintf "click at (%d, %d)" x y
  | Key c          -> Printf.sprintf "key: %c" c
  | Quit           -> "quit"

let _ = describe (Click { x = 100; y = 200 })  (* = "click at (100, 200)" *)
let _ = describe (Key 'q')   (* = "key: q" *)
let _ = describe Quit        (* = "quit" *)
```

`Click of { x : int; y : int }` is an inline record payload. You
do not need to declare a separate `type click = ...` and use
`Click of click`; the record is part of the constructor's
definition.

Inside the pattern, `Click { x; y }` destructures the inline
record exactly like any other record pattern. You can ignore
fields with `_`, rename fields with `field = local_name`, or
list only some, all the same way we just saw.

A small caveat: a value of type `event` cannot have a value of
type "click record" lifted out separately. The inline record
exists only as the payload of `Click`. If you want to share the
record shape between constructors, define it as a named record
type instead.

:::slide

## Variant with inline record payload

```ocaml
type event =
  | Click of { x : int; y : int }
  | Key   of char
  | Quit

let describe = function
  | Click { x; y } -> Printf.sprintf "click at (%d, %d)" x y
  | Key c          -> Printf.sprintf "key: %c" c
  | Quit           -> "quit"

let _ = describe (Click { x = 100; y = 200 })  (* = "click at (100, 200)" *)
let _ = describe (Key 'q')   (* = "key: q" *)
let _ = describe Quit        (* = "quit" *)
```

- `Click`'s payload is a **record declared inline**.
- Pattern destructures it like any record pattern.
- Avoids declaring a separate `type click = ...`.

:::

## Nesting in lists

Lists are where nested patterns earn their keep. A list is built
from `[]` (empty) and `::` (cons), and most list-processing
functions pattern-match on those constructors. Once you start
combining `::` with other patterns, the nesting gets interesting
fast.

Here is "the first component of the first pair":

```ocaml
let head_first = function
  | (x, _) :: _ -> Some x
  | [] -> None

let _ = head_first [(1, "a"); (2, "b"); (3, "c")]  (* = Some 1 *)
let _ = head_first []                              (* = None *)
```

:::slide

## Nesting in lists

```ocaml
let head_first = function
  | (x, _) :: _ -> Some x
  | [] -> None

let _ = head_first [(1, "a"); (2, "b"); (3, "c")]  (* = Some 1 *)
let _ = head_first []                              (* = None *)
```

- Pattern `(x, _) :: _` matches a non-empty list whose head is a pair.
- Binds the first component of that head to `x`.
- Three nested patterns: **Cons** at the top, **Tuple** in the head position, **Variable** `x` and **wildcard** `_` inside the tuple.

:::

Read the pattern `(x, _) :: _` from the outside in:

1. The outermost shape is `something :: something_else`, a
   non-empty list. Call the two pieces *head* and *tail*.
2. The head is `(x, _)`: a tuple whose first component is bound
   to `x` and whose second is discarded.
3. The tail is `_`: anything, discarded.

So we have three nested patterns in one clause:

- A cons pattern at the top.
- A tuple pattern in the head position.
- Variable and wildcard patterns inside the tuple.

This is the everyday shape for "look inside the first element."
Almost every list-processing function in real OCaml code has at
least one clause that looks like this.

You can go deeper. A pattern can extract the *second* element
too:

```ocaml
let first_two = function
  | a :: b :: _ -> Some (a, b)
  | _ -> None

let _ = first_two [10; 20; 30]  (* = Some (10, 20) *)
let _ = first_two [10]          (* = None *)
let _ = first_two []            (* = None *)
```

The pattern `a :: b :: _` matches a list of length at least two:
the first element bound to `a`, the second to `b`, the rest
discarded. This is just `::` cascaded, but read it carefully: it
parses as `a :: (b :: _)`, i.e. a cons whose head is `a` and
whose tail is itself a cons (head `b`, tail anything). The
right-associative reading of `::` is what makes this work.

## A note on reading nested patterns

The trick to reading deeply nested patterns is the same as
reading nested JSON or nested HTML: peel from the outside, and
name what you see at each layer. With practice you will start to
see the shape instinctively. Until then, a useful exercise is to
say the pattern out loud:

"`(x, _) :: _`: a list whose head is a pair, the first component
of the pair bound to `x`, the rest of the pair and the rest of
the list ignored."

If you can say it cleanly in English, the pattern is doing what
you think it does.

## Matching a tuple of values: the diagonal idiom

A common shape in real code is "the answer depends on the
combination of two values." The classic case is comparing two
`option`s: we want one branch each for `(None, None)`,
`(Some _, None)`, `(None, Some _)`, and `(Some _, Some _)`.

The obvious way is to nest one `match` inside another, once per
value:

```ocaml
let combine a b =
  match a with
  | None ->
    (match b with
     | None   -> "both empty"
     | Some _ -> "second only")
  | Some _ ->
    (match b with
     | None   -> "first only"
     | Some _ -> "both present")

let _ = combine (Some 1) None     (* = "first only" *)
```

It works, but the structure is muddled: the four logical cases
are spread across two `match`es, the parentheses around the
inner match are required, and the indentation grows with each
level. Worse, exhaustiveness checking happens twice (once per
match) instead of on the cross-product.

:::slide

## First, the nested way

```ocaml
let combine a b =
  match a with
  | None ->
    (match b with
     | None   -> "both empty"
     | Some _ -> "second only")
  | Some _ ->
    (match b with
     | None   -> "first only"
     | Some _ -> "both present")
```

- Four logical cases, spread across two nested matches.
- Inner `match` needs parentheses (or `begin...end`).
- Indentation grows with depth.
- Exhaustiveness checked **per inner match**, not on the cross-product.

:::

The cleaner option is to *form a tuple* of the two values and
match the whole tuple at once. `match a, b with` is shorthand
for `match (a, b) with`: the comma forms an implicit tuple, and
each clause matches a pair of patterns:

```ocaml
let combine a b =
  match a, b with
  | None,   None   -> "both empty"
  | Some _, None   -> "first only"
  | None,   Some _ -> "second only"
  | Some _, Some _ -> "both present"

let _ = combine (Some 1) None     (* = "first only" *)
let _ = combine None     None     (* = "both empty" *)
let _ = combine (Some 1) (Some 2) (* = "both present" *)
```

The four clauses line up visually, the cases read in any order,
and the compiler checks exhaustiveness on the 2x2 cross-product
in one pass. Reach for the tuple form whenever the answer
depends on the *combination* of two (or more) related values.

:::slide

## The diagonal idiom: match on a pair

```ocaml
let combine a b =
  match a, b with
  | None,   None   -> "both empty"
  | Some _, None   -> "first only"
  | None,   Some _ -> "second only"
  | Some _, Some _ -> "both present"

let _ = combine (Some 1) None     (* = "first only" *)
let _ = combine None     None     (* = "both empty" *)
let _ = combine (Some 1) (Some 2) (* = "both present" *)
```

- `match a, b with` is sugar for `match (a, b) with`.
- Four clauses cover the 2x2 grid in one match.
- Cases line up visually; order is flexible.
- Exhaustiveness checked on the cross-product.

:::

## Or-patterns: shared right-hand sides

Often you want several patterns to share the same right-hand
side. A classic example: testing whether a character is a vowel.

```ocaml
let is_vowel = function
  | 'a' | 'e' | 'i' | 'o' | 'u' -> true
  | _ -> false

let _ = is_vowel 'a'  (* = true *)
let _ = is_vowel 'b'  (* = false *)
```

:::slide

## Or-patterns

```ocaml
let is_vowel = function
  | 'a' | 'e' | 'i' | 'o' | 'u' -> true
  | _ -> false

let _ = is_vowel 'a'  (* = true *)
let _ = is_vowel 'b'  (* = false *)
```

- `'a' | 'e' | 'i' | 'o' | 'u'`: an **or-pattern**, five literals.
- Any one matching triggers the same right-hand side.
- Without or-patterns: five clauses, all returning `true`. Noisy.

:::

The `|` between `'a'`, `'e'`, `'i'`, `'o'`, `'u'` is the
*or-pattern combinator*. It is not the same as the leading `|` at
the start of each clause. The leading `|` separates clauses; the
internal `|` combines sub-patterns. Reading left to right: "match
if the value is `'a'`, or if it is `'e'`, or if it is `'i'`, or
..." If any alternative matches, the whole or-pattern matches and
the right-hand side runs.

Without or-patterns, the same logic needs five clauses:

```text
let is_vowel = function
  | 'a' -> true
  | 'e' -> true
  | 'i' -> true
  | 'o' -> true
  | 'u' -> true
  | _ -> false
```

The or-pattern version is shorter and reads better. It also
groups related cases visually, which makes intent clearer.

Or-patterns work on variants too:

```ocaml
type direction = North | South | East | West

let is_horizontal = function
  | East | West -> true
  | North | South -> false

let _ = is_horizontal East   (* = true *)
let _ = is_horizontal North  (* = false *)
```

:::slide

## Or-patterns on variants

```ocaml
type direction = North | South | East | West

let is_horizontal = function
  | East | West -> true
  | North | South -> false

let _ = is_horizontal East   (* = true *)
let _ = is_horizontal North  (* = false *)
```

- Two groups, each sharing a right-hand side.
- Reads almost like English.

:::

`East | West -> true` reads "if it is `East` or `West`, return
true." The two groups partition the four constructors. The
compiler can see that the four constructors are all covered, so
this is exhaustive: no warning needed.

## The binding constraint on or-patterns

There is one rule about or-patterns that, when you violate it,
produces a confusing error message. The rule is:

> Every alternative of an or-pattern must bind *exactly the same
> set of variables*, at *the same types*.

That is, if the left alternative binds `x : int`, the right
alternative must also bind `x : int`. Not `y`; not `x` at a
different type. The reason is that the right-hand side of the
clause references those names, and the compiler needs to know
they are bound regardless of which alternative succeeded.

:::slide

## Constraint: alternatives bind the same names

```ocaml skip
type tagged = A of int | B of int

let _ =
  match A 5 with
  | A x | B y -> x   (* error: y unbound, x unbound on right *)
```

- OCaml rejects this.
- Or-pattern requires all alternatives to bind the **same set of variables**.
- And at **compatible types**.

:::

:::slide

## Fix: use the same name in each alternative

```ocaml
type tagged = A of int | B of int

let to_int = function
  | A x | B x -> x

let _ = to_int (A 5)  (* = 5 *)
let _ = to_int (B 7)  (* = 7 *)
```

- Each alternative binds an `int` to `x`.
- Right-hand side can now refer to `x` unambiguously.

:::

If you write `| A x | B y -> x`, the compiler complains because
the right-hand side mentions `x`, but `x` is only bound in the
left alternative; if the value were `B`, there would be no `x`.
The reverse problem appears too: if your right-hand side uses
`y`, the compiler complains because `y` is only bound in the
right alternative.

The fix is to use the same name in both alternatives, *and to
mean the same thing by it*. In `A x | B x -> x`, both `A` and `B`
carry an `int`, and we name that `int` `x` in either case. The
right-hand side `x` is then unambiguously typed `int`.

This constraint is what makes or-patterns *type-safe*: the
compiler can guarantee, just from the pattern, that the
right-hand side has consistent types for all the names it
references.

## Combining or-patterns and nesting

Or-patterns can appear *anywhere* a pattern can appear, including
inside other patterns. This lets you write compact clauses:

```ocaml
let summary = function
  | (0 | 1) :: _ -> "starts with 0 or 1"
  | _ :: _       -> "starts with something else"
  | []           -> "empty"

let _ = summary [0; 5; 6]  (* = "starts with 0 or 1" *)
let _ = summary [1; 5; 6]  (* = "starts with 0 or 1" *)
let _ = summary [5; 6]     (* = "starts with something else" *)
let _ = summary []         (* = "empty" *)
```

:::slide

## Or-patterns nested inside other patterns

```ocaml
let summary = function
  | (0 | 1) :: _ -> "starts with 0 or 1"
  | _ :: _       -> "starts with something else"
  | []           -> "empty"

let _ = summary [0; 5; 6]  (* = "starts with 0 or 1" *)
let _ = summary [1; 5; 6]  (* = "starts with 0 or 1" *)
let _ = summary [5; 6]     (* = "starts with something else" *)
let _ = summary []         (* = "empty" *)
```

- Pattern `(0 | 1) :: _` reads "either 0 or 1, followed by anything".
- Or-pattern appears in the **head position** of a cons.
- Or-patterns can sit inside constructors, tuples, lists.

:::

The pattern `(0 | 1) :: _` says: a non-empty list whose head is
`0` or `1`. The or-pattern `(0 | 1)` sits in the head position of
the cons. The parentheses are necessary: without them, `0 | 1 ::
_` would parse incorrectly. As a rule, parenthesise an or-pattern
whenever it appears nested inside another pattern.

You can also or together more elaborate sub-patterns. Here is "a
non-empty list whose first element is either zero or negative":

```ocaml
let starts_nonpositive = function
  | (0 | -1 | -2 | -3) :: _ -> "small non-positive"
  | _ -> "other"
```

The or-pattern has four literal alternatives. (For a real
"non-positive" check, you would use a guard, which is the topic
of [Lecture 4](M05-L04-guards.html); this is just an illustration.)

## The `as` binder: keep a name for the whole

One more pattern form fits naturally in this lecture: `as`,
which lets you destructure a value *and* keep a name for the
whole thing.

Suppose we want to return the head of a list paired with the
list's length. Without `as`, you have to name the parameter and
reach for it on the right:

```ocaml
let head_and_full xs =
  match xs with
  | x :: _ -> Some (x, List.length xs)
  | [] -> None

let _ = head_and_full [10; 20; 30]  (* = Some (10, 3) *)
```

The clause destructures (`x :: _`) and *also*
needs the whole list (`xs`) on the right. We can get `xs` because
the parameter has a name. Inside `function` (no parameter name),
this trick is not available; `as` is the cleanest way to keep the
name in either style:

```ocaml
let head_and_full = function
  | (x :: _) as xs -> Some (x, List.length xs)
  | [] -> None

let _ = head_and_full [10; 20; 30]  (* = Some (10, 3) *)
```

Same result. The pattern `(x :: _) as xs` first
destructures (`x` is the head); then `as xs` names the *entire*
matched list `xs`. The right-hand side has both names available.

:::slide

## First, without `as`: name the parameter

```ocaml
let head_and_full xs =
  match xs with
  | x :: _ -> Some (x, List.length xs)
  | [] -> None

let _ = head_and_full [10; 20; 30]  (* = Some (10, 3) *)
```

- Clause destructures (`x :: _`) and reaches for `xs` on the right.
- Works because the parameter has the name `xs`.
- Fails the moment you switch to `function` (no parameter name).

:::

:::slide

## `as` patterns: name what you matched

```ocaml
let head_and_full = function
  | (x :: _) as xs -> Some (x, List.length xs)
  | [] -> None

let _ = head_and_full [10; 20; 30]  (* = Some (10, 3) *)
```

- `(x :: _) as xs` destructures *and* names the whole.
- `x` is the head, `xs` is the full list, in one pattern.
- Works inside `function`, where there is no outer parameter.

:::

`as` reads almost like an English aside: "the head is `x`, and
the whole list is `xs`."

## Or-patterns with `as`

The main use of `as` is with or-patterns. An or-pattern
(`p1 | p2 | ...`) cannot bind a variable in each disjunct
individually, because OCaml requires the variables of the
alternatives to agree. So if you want a name for *whichever
alternative happened to match*, `as` is the only way to do it.

```ocaml
let classify = function
  | (0 | 1 | 2)     as small -> Printf.sprintf "small: %d"  small
  | (10 | 20 | 30)  as round -> Printf.sprintf "round: %d"  round
  | n                        -> Printf.sprintf "other: %d"  n

let _ = classify 1    (* = "small: 1" *)
let _ = classify 20   (* = "round: 20" *)
let _ = classify 7    (* = "other: 7" *)
```

`as small` binds whichever of `0`, `1`, `2` matched; `as round`
likewise. Without the `as`, you would have to split the or-pattern
back into three separate clauses just to name the value.

:::slide

## Or-patterns with `as`

```ocaml
let classify = function
  | (0 | 1 | 2)     as small -> Printf.sprintf "small: %d"  small
  | (10 | 20 | 30)  as round -> Printf.sprintf "round: %d"  round
  | n                        -> Printf.sprintf "other: %d"  n

let _ = classify 1    (* = "small: 1" *)
let _ = classify 20   (* = "round: 20" *)
let _ = classify 7    (* = "other: 7" *)
```

- Or-pattern alternatives cannot bind a name on their own.
- `as` gives the matched value a single name across the disjuncts.
- Without it: three separate clauses just to name the value.

:::

## Putting it together: a small parser shape

A common shape in real code is a multi-clause match where each
clause uses nesting *and* or-patterns:

```ocaml
type token =
  | Int of int
  | Plus
  | Minus
  | Times
  | LParen
  | RParen

let is_operator = function
  | Plus | Minus | Times -> true
  | Int _ | LParen | RParen -> false
```

The or-pattern `Plus | Minus | Times` groups the three operator
constructors. The complementary or-pattern groups the
non-operators. Notice `Int _`: that is a constructor pattern
with a wildcard payload. We do not care what integer it carries;
we only care that it is an `Int`.

The function reads cleanly because the structure of the data is
mirrored in the structure of the patterns. This is the goal: let
the patterns express *what shape* you are handling, and the
right-hand sides express *what to do*.

## Two checks

:::quiz mcq id=M05-L03-q3
What does `head_and_second [1; 2; 3]` return, given:

```ocaml
let head_and_second = function
  | a :: b :: _ -> Some (a, b)
  | _ -> None
```

- [x] `Some (1, 2)`
- [ ] `Some (1, 3)`
- [ ] `Some (2, 3)`
- [ ] `None`

**Why:** the pattern `a :: b :: _` matches a list with at least
two elements. `a` is the head (`1`), `b` is the next element
(`2`), and the tail (`[3]`) is discarded.
:::

:::quiz mcq id=M05-L03-q2
The compiler rejects this with an error. Why?

```ocaml skip
type t = A of int | B of string

let f = function
  | A x | B x -> x
```

- [ ] Or-patterns are not allowed in `function`.
- [ ] The names `x` clash.
- [x] The two `x`s have incompatible types: `int` in `A`, `string` in `B`.
- [ ] `A` and `B` cannot be grouped.

**Why:** the or-pattern constraint is that every alternative
must bind the same variables at the *same types*. `A x` binds
`x : int`; `B x` binds `x : string`. The compiler cannot give
the right-hand side a consistent type for `x`, so the pattern
is rejected.
:::

A code task:

:::quiz code id=M05-L03-q1
A server's reply is either a numeric status code or a timeout.
Write `should_retry : reply -> bool` that returns `true` for
`Code 502`, `Code 503`, or `Timeout`, and `false` for everything
else. Use a single clause whose left side is an or-pattern; two of
the three alternatives are nested literal patterns inside `Code`.

```ocaml
type reply =
  | Code of int
  | Timeout

let should_retry r =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (should_retry (Code 502) = true) "bad gateway";
  check (should_retry (Code 503) = true) "unavailable";
  check (should_retry Timeout = true) "timeout";
  check (should_retry (Code 200) = false) "ok";
  check (should_retry (Code 404) = false) "not found";
  print_endline "all tests passed"
```

:::

:::solution

The shape: `function | Code 502 | Code 503 | Timeout -> true |
_ -> false`. One or-pattern with three alternatives: the literals
`502` and `503` live *inside* the `Code` constructor pattern, and
`Timeout` is a bare constructor. No alternative binds a variable,
so the same-bindings rule is trivially satisfied.

:::

## Common pitfalls

**Pitfall 1: forgetting parentheses around an or-pattern.** When
an or-pattern sits inside another pattern, parenthesise it.
`(0 | 1) :: _` is correct; `0 | 1 :: _` is parsed differently
and probably not what you meant.

**Pitfall 2: different names in different alternatives.** The
or-pattern constraint says every alternative must bind the same
names. `| A x | B y` will not work if the right-hand side uses
either name. Use the same name in both: `| A x | B x`.

**Pitfall 3: incompatible types in alternatives.** Even with the
same name, the bound types must agree. `| A x | B x` fails if
`A` carries `int` and `B` carries `string`. The fix in that case
is usually to *not* use an or-pattern, and handle the two
constructors separately.

**Pitfall 4: deep nesting without parentheses.** As patterns
grow, the parser can struggle. When in doubt, parenthesise. The
compiler is happy with extra parentheses, and your reader will
be too.

## Activity

:::slide

## Activity

Write `is_unit_shape : shape -> bool` that returns `true` for
`Circle 1.0` or `Rectangle (1.0, 1.0)`, and `false` for any other
shape. Use a single clause whose left side is an **or-pattern**
combining the two nested literal patterns.

```ocaml
type shape = Circle of float | Rectangle of float * float
(* is_unit_shape (Circle 1.0)            => true  *)
(* is_unit_shape (Rectangle (1.0, 1.0))  => true  *)
(* is_unit_shape (Circle 2.0)            => false *)
```

:::

Try it before reading the solution.

:::solution

:::slide

## Activity solution

```ocaml
type shape =
  | Circle of float
  | Rectangle of float * float

let is_unit_shape = function
  | Circle 1.0 | Rectangle (1.0, 1.0) -> true
  | _ -> false

let _ = is_unit_shape (Circle 1.0)             (* = true *)
let _ = is_unit_shape (Rectangle (1.0, 1.0))   (* = true *)
let _ = is_unit_shape (Circle 2.0)             (* = false *)
```

- One or-pattern: `Circle 1.0 | Rectangle (1.0, 1.0)`.
- Each alternative is a constructor with a nested literal payload.
- Neither alternative binds a variable, so the same-bindings rule
  holds trivially.

:::

:::

The or-pattern combines two constructor patterns, each with a
nested literal payload. `Circle 1.0` requires the constructor
*and* the float `1.0`; `Rectangle (1.0, 1.0)` requires the
constructor *and* the tuple `(1.0, 1.0)`. Either match sends us
to the same right-hand side.

This is the everyday shape for "one of these specific shapes,"
where each shape needs its own nested check.

## What's next

[Lecture 4](M05-L04-guards.html) introduces `when`-guards:
predicates attached to a pattern that further filter when the clause
fires. Guards let you express conditions that pure patterns cannot,
like "this list has a positive number at the front." They come with
one important caveat: they disable the compiler's exhaustiveness
check for that clause, which we will see why in
[Lecture 5](M05-L05-exhaustiveness.html#exhaustiveness-and-guards-one-more-reminder).

:::slide

## What's next

- Lecture 4: **guards** (`when`-clauses).
- Combine a pattern with an arbitrary boolean test.
- Express conditions that pure patterns cannot.

:::

## Reading

- **Cornell CS3110**, *Pattern matching (continued)*:
  <https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html>
- **Real World OCaml**, *Lists and patterns* (or-patterns section):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
