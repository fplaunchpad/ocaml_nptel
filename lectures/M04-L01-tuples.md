---
title: "Tuples"
lecture_no: 1
week: 4
youtube_id: 4MvZxs5tuRs
duration_target_min: 22
concepts: [tuples, product types, pair, fst, snd, destructuring, tuple patterns]
keywords: [OCaml, tuple, pair, product type, destructuring]
activity_question: "Given [let p = (3, true, \"hi\")], what is the type of [p]? Write a function [first3 : 'a * 'b * 'c -> 'a] that returns the first component."
think_about_this: "Tuples in OCaml are *fixed-arity*: an [int * int] and an [int * int * int] are different types. Compare that to Python tuples, which are variable-arity. What does the OCaml choice buy you, and what does it cost?"
reading:
  - title: "Cornell CS3110, Records and Tuples"
    url: https://cs3110.github.io/textbook/chapters/data/records_tuples.html
  - title: "Real World OCaml, Lists and Patterns"
    url: https://dev.realworldocaml.org/lists-and-patterns.html
---

# Tuples


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tuples</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The first three modules of this course have been about computation:
literals, bindings, conditionals, functions, recursion. We have
moved a lot of `int`s and `string`s and `bool`s through the
language, but always one at a time. Real programs rarely deal with
single values. They deal with *aggregates*: a 2D point bundles an
`x` and a `y`; a key-value entry bundles a key with its value; a
return value from "divide with remainder" is a quotient *and* a
remainder. Module 4 is about how OCaml lets you build, name, and
take apart such aggregates.

:::slide

## So far: one value at a time

- Modules 1-3 moved single values: `int`, `string`, `bool`.
- Real programs deal with *aggregates*:
  - a 2D point bundles `x` and `y`
  - a dictionary entry bundles a key with its value
  - "divide with remainder" returns a quotient *and* a remainder
- Module 4: how OCaml builds, names, and takes apart aggregates.

:::

This first lecture covers the simplest aggregate the language
offers: the *tuple*. A tuple is a fixed-size bundle of values,
possibly of different types, identified by *position*. The number
of components a tuple carries is called its *arity* (borrowed
from logic: "arity" is the number of arguments a relation takes).
The pair `(3, "hello")` is a tuple of arity two; the triple
`(1, 2.0, true)` is a tuple of arity three. The next two lectures cover
[*records*](M04-L02-records.html) (aggregates with named fields)
and [*variants*](M04-L03-variants.html) (a different kind of
aggregate: "one of several shapes" rather than "this and that").
Together, tuples, records, and variants are the three building
blocks of *every* data type you will design in OCaml.

:::slide

## The plan for Module 4

Three building blocks for *every* data type in OCaml:

- **Tuples** (this lecture): bundle by position, e.g. `(3, "hi")`.
- **Records** ([L2](M04-L02-records.html)): bundle by name, e.g. `{x = 3; y = 4}`.
- **Variants** ([L3](M04-L03-variants.html)): "one of several shapes", e.g. `Some 3` vs `None`.

Then [recursive types](M04-L04-recursive-types.html) and two tutorial lectures put them to work.

:::

If you have used Python or Go, you have seen tuples before. OCaml
tuples are similar in spirit but differ in one important way: their
*arity is part of their type*. A pair and a triple are not just
"tuples of different sizes"; they are different types entirely.
That is a small detail with large consequences, and we will spend
much of this lecture on what it buys you.

## A tuple is several values bundled

The syntax is what you would guess from any other language. Put
several expressions inside parentheses, separated by commas, and
you have a tuple.

```ocaml
let pair    = (3, true)
let triple  = (1, "two", 3.0)
let nested  = ((1, 2), (3, 4))
```

The toplevel reports the types as `int * bool`, `int * string *
float`, and `(int * int) * (int * int)`. The `*` in a *type
position* is read as "and": "an `int` *and* a `bool`," "an `int`
*and* a `string` *and* a `float`."

:::slide

## A tuple is several values bundled

```ocaml
let pair    = (3, true)
let triple  = (1, "two", 3.0)
let nested  = ((1, 2), (3, 4))
```

- `pair : int * bool`
- `triple : int * string * float`
- `nested : (int * int) * (int * int)`
- `*` in a type position reads as "and"; not the multiplication operator.

:::

The product-type notation `int * bool` trips up beginners, because
in expression position `*` is integer multiplication. There is no
ambiguity for the compiler: the `*` between `int` and `bool` is in
a *type position*, and the `*` in `3 * 4` is in a *value position*.
Two different syntactic worlds, sharing one symbol. You will get
used to reading `int * bool` as "pair of `int` and `bool`" quickly
enough.

The mathematical reason for the symbol is that *the set of values
of type `int * bool` is the Cartesian product of the set of `int`s
and the set of `bool`s*. Every pair is one `int` paired with one
`bool`; the number of distinct pairs is `|int| * |bool|`. Hence the
name *product type*, and hence the `*`. The
[next lecture](M04-L02-records.html) covers records, which are
also product types (just with named components instead of
positional ones). The
[lecture after that](M04-L03-variants.html) covers variants, which
are *sum types*: the dual notion.

## Tuples have a fixed size as part of their type

Here is the property that distinguishes OCaml tuples from Python
tuples or JavaScript arrays:

```ocaml
let _ : int * int       = (1, 2)
let _ : int * int * int = (1, 2, 3)
```

These two values have *different types*. You cannot pass an `int *
int * int` where an `int * int` is expected, and vice versa. Each
tuple shape is its own type, distinguished by both the arity and
the types of the components.

You can watch the compiler reject the mismatch in the live cell
below: the annotation says `int * int`, but the value is a triple.

```ocaml skip
let _ : int * int = (1, 2, 3)
```

The error names the mismatch explicitly: the expression has type
`int * int * int` but an expression of type `int * int` was
expected. The rejection happens at type-checking time, before any
code runs.

:::slide

## Fixed arity is part of the type

```ocaml
let _ : int * int       = (1, 2)
let _ : int * int * int = (1, 2, 3)
```

- *Arity* = number of components a tuple carries.
- These are *different types*: arity 2 vs arity 3.
- Contrast Python: 2-tuple and 3-tuple are both `tuple`.
- OCaml: static checking, but a fresh type for every shape.

:::

:::slide

## Try it: arity is a type error

```ocaml skip
let _ : int * int = (1, 2, 3)
```

- Click **Run**: the binding fails to type-check.
- Error: expression has type `int * int * int`, expected `int * int`.
- Rejected before any code runs.

:::

Compare this with Python: `(1, 2)` and `(1, 2, 3)` both have type
`tuple`. A Python function that "takes a 2-tuple" cannot say so in
its signature; it has to check at runtime that the length is 2 and
raise an error otherwise. OCaml's choice is the opposite: a
function that takes an `int * int` cannot even be *called* with a
3-tuple. The compiler rejects the call site. The dividend is that
you cannot accidentally hand a "point in 3D" to a function that
expected a "point in 2D"; the type system rules out the bug before
your test suite gets a chance.

The cost is conceptual: each shape is its own type, so a function
that "averages a tuple of numbers" cannot be written once and used
on tuples of any size. If you genuinely need that, you reach for a
list of numbers rather than a tuple. Tuples are for *small, fixed*
groups where the shape is part of the type's identity.

## Constructing and extracting

Construction is just the literal you have already seen: write the
components inside parentheses, separated by commas.

```ocaml
let p = (10, 20)
```

Extraction is the more interesting part. For pairs, OCaml's standard
library gives you two convenience functions:

```ocaml
let p = (10, 20)
let _ = fst p  (* = 10 *)
let _ = snd p  (* = 20 *)
```

`fst` returns the first component of a pair; `snd` returns the
second. Their types tell the story:

```
val fst : 'a * 'b -> 'a
val snd : 'a * 'b -> 'b
```

They are *polymorphic*: they work on any pair, regardless of the
types of the two components. But notice they are for *pairs only*.
There is no `third` function in the standard library. For triples
and larger, OCaml expects you to *destructure*.

:::slide

## Extracting from a pair: `fst` and `snd`

```ocaml
let p = (10, 20)
let _ = fst p  (* = 10 *)
let _ = snd p  (* = 20 *)
```

- `fst : 'a * 'b -> 'a`, `snd : 'a * 'b -> 'b`.
- Polymorphic; work on any pair regardless of element types.
- **Pairs only**: no `fst` / `snd` for triples or larger.

:::

:::slide

## Triples and larger: destructure

```ocaml
let (x, y, z) = (1, 2, 3)
let _ = x  (* = 1 *)
let _ = y  (* = 2 *)
let _ = z  (* = 3 *)
```

- `(x, y, z)` on the left is a **pattern**, not a tuple expression.
- Binds three names at once, in one `let`.
- Works at any arity; the standard way past pairs.

:::

This is the first time we have put anything more structured than a
single name to the left of `let =`. The thing to the left is called
a *pattern*. For tuples, the pattern is `(x, y)` or `(x, y, z)`,
with one name (or `_`) per component. OCaml matches the right-hand
side against this pattern and binds each name to the corresponding
component. Pattern matching is the subject of all of
[Module 5](M05-L01-basic-patterns.html); for this module we use it
informally as it appears.

If the pattern's arity does not match the value's arity, the
compiler complains *at compile time*, not at runtime. Writing `let
(x, y) = (1, 2, 3)` is a type error: the pattern expects a pair,
the value is a triple, and the two types do not match. You cannot
get into a situation where the code compiles but then crashes
because you destructured the wrong shape.

The underscore `_` in a pattern means "match anything here, but do
not bind a name to it." If you want only the first component of a
triple, write:

```ocaml
let (x, _, _) = (1, "two", 3.0)
```

`x` is now `1`; the other two components are discarded. This is
the standard way to project out a single component of a larger
tuple.

## Pattern matching in function arguments

Patterns are not just for `let`. They can appear in function
parameters too. Here is a function that computes Euclidean distance
between two 2D points represented as pairs:

```ocaml
let distance (x1, y1) (x2, y2) =
  let dx = x2 -. x1 in
  let dy = y2 -. y1 in
  sqrt (dx *. dx +. dy *. dy)

let _ = distance (0.0, 0.0) (3.0, 4.0)  (* = 5. *)
```

The two parameters are *patterns* `(x1, y1)` and `(x2, y2)`. When
you call `distance (0.0, 0.0) (3.0, 4.0)`, OCaml matches the first
argument against `(x1, y1)`, binding `x1 = 0.0` and `y1 = 0.0`,
and similarly for the second. We will study pattern matching deeply
in [Module 5](M05-L01-basic-patterns.html), where you will see that
function parameters are one of several places where any OCaml
pattern can appear.

:::slide

## Pattern matching in function arguments

```ocaml
let distance (x1, y1) (x2, y2) =
  let dx = x2 -. x1 in
  let dy = y2 -. y1 in
  sqrt (dx *. dx +. dy *. dy)

let _ = distance (0.0, 0.0) (3.0, 4.0)  (* = 5. *)
```

- Each parameter is a *pattern* `(x1, y1)`.
- Inferred type: `float * float -> float * float -> float`.
- Patterns in depth in [Module 5](M05-L01-basic-patterns.html).

:::

The inferred type is `float * float -> float * float -> float`. The
function takes two arguments, each a pair of floats, and returns a
float. We did not write a single type annotation; the body forced
all components to be floats (because of `-.`), and the parameter
shape forced each argument to be a pair.

A subtle point: the *function* `distance` takes two arguments, each
of which happens to be a pair. It is *not* a function of one
argument that is a 4-tuple. The difference shows up in the type:
`float * float -> float * float -> float` vs `float * float * float
* float -> float`. We will see in
[Module 6](M06-L01-functions-revisited.html) that the choice
matters when partial application enters the picture.

## Argument lists versus tuples: a common confusion

This is the single largest source of confusion for students
arriving in OCaml from C-family languages.
Consider these two function definitions:

```ocaml
let add_curried x y    = x + y
let add_tupled (x, y)  = x + y
let _ = add_curried 3 4    (* = 7 *)
let _ = add_tupled (3, 4)  (* = 7 *)
```

Both compute `7`, but the function signatures are different:

- `add_curried : int -> int -> int`
- `add_tupled  : int * int -> int`

`add_curried` takes *two* arguments, applied one at a time (this
is the curried form we saw in
[the functions-as-values lecture](M03-L01-functions-as-values.html#multiple-parameters)
and studied in [the currying lecture](M03-L03-currying.html)). It
can be
partially applied: `add_curried 3` is a meaningful value of type
`int -> int`.

`add_tupled` takes *one* argument, which happens to be a pair. It
cannot be "partially applied to the first component"; the whole
pair must be supplied at once.

:::slide

## Argument list vs tuple

```ocaml
let add_curried x y    = x + y
let add_tupled (x, y)  = x + y
```

- `add_curried : int -> int -> int`. Two arguments.
- `add_tupled  : int * int -> int`. One argument: a pair.
- Call sites: `add_curried 3 4` vs `add_tupled (3, 4)`.
- Prefer curried for arguments you may partially apply.
- Use tuple when values **belong together**.

:::

If you have C or Python reflexes, you may want to write `f(x, y)`
for every two-argument function. In OCaml, `f (x, y)` calls a
function that takes a *single pair* as its argument. The curried
call is `f x y`, with arguments separated by spaces, no parens.
Mixing these up is the most common syntax mistake of the first
week. The error message you get is usually some variant of "this
expression has type `int * int` but an expression was expected of
type `int`," and at first it is mysterious; once you have seen it
twice, the cause is obvious.

The idiomatic rule: use curried arguments (`f x y`) by default,
because they allow partial application and read more naturally in
the higher-order style we will lean on in
[Module 6](M06-L01-functions-revisited.html). Use a tuple argument
only when the two values *genuinely belong together as one unit*
(a coordinate pair, a key-value entry) and never make sense in
isolation.

## Tuples are for heterogeneous data of known shape

A short summary of when to reach for a tuple:

:::slide

## When to use a tuple

Use a tuple when:

- Small, fixed bundle (2, 3, maybe 4).
- Possibly different types.
- Shape is obvious: `(x, y)`, `(key, value)`.

Don't use a tuple when:

- You want access by *name* (use a record).
- Ten components (use a record).
- Number of values varies (use a list).

**Rule of thumb:** two or three things, positions speak for themselves.

:::

The "rule of thumb" is informal but practical. A 2D point is a
pair: `(x, y)`. Nobody confuses which is the abscissa. A key-value
entry is a pair: `(key, value)`. The convention is universal
enough that the position is self-documenting. But a "person" with
a `first_name`, `last_name`, `age`, `phone`, `email`, `address` is
*not* a 6-tuple, even though you could technically write it that
way. Code that consumes such a tuple would start asking, "wait,
was the email index 4 or 5?" and the bugs follow.
[Records](M04-L02-records.html) are for that case; we will see
them in the next lecture.

## Returning multiple values

OCaml functions always return *one* value. But that value can be a
tuple, which is the standard way to return multiple results.

```ocaml
let divmod a b =
  (a / b, a mod b)

let _ = divmod 17 5  (* = (3, 2) *)
```

The function returns a pair `(quotient, remainder)`. The caller
destructures:

```ocaml
let divmod a b = (a / b, a mod b)
let (q, r) = divmod 17 5
let _ = q + r  (* = 5 *)
```

:::slide

## Returning multiple values

OCaml functions return a **single** value: can be a tuple.

```ocaml
let divmod a b =
  (a / b, a mod b)

let _ = divmod 17 5  (* = (3, 2) *)
```

- Caller destructures:

```ocaml
let divmod a b = (a / b, a mod b)
let (q, r) = divmod 17 5
```

- The OCaml idiom for multiple return values.

:::

Python has `return q, r`. Go has named return values and `return q,
r`. C does not have anything good (people pass output pointers).
OCaml's mechanism is a tuple return, which is the same answer
Python is implicitly giving (Python's "multiple return values"
build a tuple under the hood). The only difference is that OCaml
makes the tuple explicit, which is exactly the trade we have seen
the language make many times: more visible syntax, less hidden
machinery.

## Tuples in collections

You will often see *lists of tuples*. Each tuple is a "row" in a
small table.

```ocaml
let pairs = [(1, "one"); (2, "two"); (3, "three")]
```

The type of `pairs` is `(int * string) list`: a list of `int *
string` pairs. Building these tables is something we can do now;
searching them by key needs pattern matching, which is the topic
of [Module 5](M05-L01-basic-patterns.html). The standard library
function `List.assoc_opt` is what you reach for once you have
`option` and patterns in hand.

:::slide

## Tuples in collections

You'll see lists of tuples constantly (each tuple a "row"):

```ocaml
let pairs = [(1, "one"); (2, "two"); (3, "three")]
```

- Type: `(int * string) list`.
- Searching by key needs pattern matching (Module 5).

:::

## A common pitfall: tuples and operator precedence

The comma operator binds *looser* than most things. When you write
a tuple inside a more complex expression, the parentheses are not
just for show:

```ocaml
let f x = (x, x + 1)
```

Without parens, `f x = x, x + 1` would still parse (commas at the
top of a `let` body are tuple constructors), so you sometimes see
it. But the moment you have anything around the tuple, you need
the parens.

```ocaml
let xs = [1, 2]
```

This is the booby trap. You expect `xs` to be a list of two
integers. It is *not*. It is a list of *one element*, that element
being the pair `(1, 2)`. The type is `(int * int) list`, not `int
list`. The compiler does not warn you; it is a perfectly valid
list literal, just not the one you meant.

:::slide

## Pitfall: `[1, 2]` is not what you think

```ocaml
let xs = [1, 2]
```

- Type: `(int * int) list`.
- One element: the pair `(1, 2)`.
- For a list of two ints, use `;`:

```ocaml
let xs = [1; 2]
```

- Lists: `;`. Tuples: `,`.
- Compiler does not warn; be careful.

:::

The right separator for lists is `;`. The right separator inside
tuples (or between fields in a record) is `,`. Confusing the two
gives you valid-looking code that means something different. The
first time you write `[1, 2]` instead of `[1; 2]`, the compiler
will give you a strange error somewhere downstream (typically when
you try to add the elements: it complains that the elements are
`int * int`, not `int`). That stranger error is your hint that the
list literal misparsed.

## Pattern matching in `let`: a small check

:::quiz mcq id=M04-L01-q3
What is the type of the function below?

```ocaml
let swap (x, y) = (y, x)
```

- [ ] `'a -> 'a -> 'a * 'a`
- [x] `'a * 'b -> 'b * 'a`
- [ ] `'a * 'a -> 'a * 'a`
- [ ] `'a -> 'b -> 'b * 'a`

**Why:** the function takes *one* argument, a pair, and returns a
pair with the components swapped. The two components can have
*different* types, so the type variables for input and output are
`'a` and `'b`. The output is a pair `(y, x)` of types `'b * 'a`. So
the whole thing is `'a * 'b -> 'b * 'a`. The `'a -> 'a -> ...`
options would mean a curried function of two arguments, which is
not what the pattern `(x, y)` does.
:::

:::quiz mcq id=M04-L01-q2
Which of these expressions has type `int list`?

- [ ] `[1, 2, 3]`
- [x] `[1; 2; 3]`
- [ ] `(1, 2, 3)`
- [ ] `[(1, 2, 3)]`

**Why:** lists separate elements with `;`. The expression `[1, 2,
3]` is a one-element list whose element is the triple `(1, 2, 3)`,
so its type is `(int * int * int) list`. `(1, 2, 3)` is a triple,
not a list. `[(1, 2, 3)]` is a one-element list of triples.
:::

A small code task:

:::quiz code id=M04-L01-q1
Write `pair_max : int * int -> int` that returns the larger of the
two components.

```ocaml
let pair_max p =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (pair_max (3, 7) = 7) "3,7";
  check (pair_max (10, 2) = 10) "10,2";
  check (pair_max (5, 5) = 5) "equal";
  check (pair_max (-1, -8) = -1) "negative";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution: `let pair_max (x, y) = if x > y then x else y`.
Pattern destructure in the argument; one `if`-expression body.

:::

## Activity

:::slide

## Activity

Given `let p = (3, true, "hi")`, predict:

1. The type of `p`.
2. The body of a function `first3 : 'a * 'b * 'c -> 'a` that returns
   the first component.

Write the function.

:::

:::solution

:::slide

## Activity solution

```ocaml
let p = (3, true, "hi")
```

1. `p : int * bool * string`.
2. Function:

```ocaml
let first3 (x, _, _) = x

let _ = first3 (3, true, "hi")  (* = 3 *)
```

- `val first3 : 'a * 'b * 'c -> 'a = <fun>`.
- `_` ignores a component.

:::

:::

The function works on any triple, regardless of the types of the
three components. That is *parametric polymorphism* at work: we did
not constrain `'a`, `'b`, or `'c`, so the function can be called on
a triple of any types and will return whatever was in the first
slot.

## What's next

:::slide

## What's next

Lecture 2: **records**. Same idea as tuples, but components have
*names*. When your bundle has more than three things, or when the
positions are not self-evident, records are clearer.

:::

We have seen how to bundle a small fixed number of values by
position. The next lecture extends this to *named* fields, which
is the right tool for any bundle larger than three components or
where the positions do not tell their own story.

## Reading

- **Cornell CS3110**, *Records and Tuples*:
  <https://cs3110.github.io/textbook/chapters/data/records_tuples.html>
- **Real World OCaml**, *Lists and Patterns* (tuple section):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
