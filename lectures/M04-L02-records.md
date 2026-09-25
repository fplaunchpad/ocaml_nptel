---
title: "Records"
lecture_no: 2
week: 4
youtube_id: uWMVE0C2bxk
duration_target_min: 22
concepts: [records, named fields, record types, functional update, dot access]
keywords: [OCaml, record, named fields, record type, functional update]
activity_question: "Define a record type [book] with fields [title : string], [author : string], [year : int]. Create one. Define a function that returns the title."
think_about_this: "Records have *named* fields where tuples have *positional* components. Which is better for a function that takes both a 'first name' and a 'last name'? Which is better for a 2D point?"
reading:
  - title: "Cornell CS3110, Records and Tuples"
    url: https://cs3110.github.io/textbook/chapters/data/records_tuples.html
  - title: "Real World OCaml, Records"
    url: https://dev.realworldocaml.org/records.html
---

# Records


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Records</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

A record is a bundle, like a tuple, but with each component
identified by *name* instead of position. The
[last lecture](M04-L01-tuples.html) argued that tuples are the
right tool for two or three values whose positions are
self-evident: a 2D point, a key-value entry, a quotient-remainder
pair. The moment you want more than that, or the positions stop
telling their own story, you reach for a record.

A record in OCaml plays the same role that a `struct` plays in C
or a class with only data members plays in Java. The syntax is
similar in spirit. The semantics differs in two ways: records
are *immutable by default*, and they are *structurally
compared*. Both of those make a record behave more like a value
(an `int`, a `string`) than like an object.

If you have not built a data-modelling habit before, this is the
lecture where it starts. Most of the data structures you will
design over the rest of the course are records, variants, or
combinations of the two.

:::slide

## This lecture: records

- A *record* is a bundle, like a tuple, but with components named.
- For 2 or 3 self-evident positions: tuple. Otherwise: record.
- Same role as a C `struct` or a Java data class.
- Two semantic differences:
  - *Immutable* by default.
  - *Structurally* compared, like an `int` or a `string`.
- Where the data-modelling habit starts.

:::

## Declaring a record type

Unlike tuples, records require a *type declaration* before you can
construct one. You declare the type, with each field's name and
type; then you construct values of that type.

```ocaml
type point = { x : float; y : float }

let origin = { x = 0.0; y = 0.0 }
let p      = { x = 3.0; y = 4.0 }
```

The declaration `type point = { x : float; y : float }` introduces
a new type named `point`. It has two fields, `x` and `y`, both of
type `float`. Then `origin` and `p` are values of type `point`,
built with the record-literal syntax `{ field = value; field = value }`.

:::slide

## Declaring a record type

Records are *nominally* typed in OCaml. Declare the type first,
then construct values.

```ocaml
type point = { x : float; y : float }

let origin = { x = 0.0; y = 0.0 }
let p      = { x = 3.0; y = 4.0 }
```

- `point` is a type; `origin` and `p` are values of type `point`.
- Construction: braces, `field = value`, `;` between fields.
- Field order in a literal doesn't matter.

:::

Note the small syntactic detail: inside the *type* declaration, the
separator between fields is `;` and the punctuation between a name
and its type is `:`. Inside an *expression* that builds a record,
the separator is also `;` (not `,`!) and the punctuation between a
name and its value is `=`. This mirrors the difference between type
syntax and expression syntax we have already seen elsewhere.

The order of fields in an expression literal is irrelevant. `{ x =
3.0; y = 4.0 }` and `{ y = 4.0; x = 3.0 }` are the same value. The
type declaration gives the *canonical* order; the compiler does not
care how you list them when constructing.

OCaml's records are *nominally* typed: two record types with the
same fields are not interchangeable. If you declare `type a = { x :
int }` and `type b = { x : int }`, then an `a` value cannot be
passed where a `b` is expected, even though they have the same
shape. This is the opposite of TypeScript's structural object
types, and it is a deliberate choice to make types more meaningful
identifiers.

## Accessing fields

Two ways to get a value out of a record: *dot syntax* (like Java or
Python), and *destructuring* (like patterns).

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let _ = p.x  (* = 3. *)
let _ = p.y  (* = 4. *)
```

`p.x` and `p.y` are *field-access expressions*. The result of
`p.x` is `3.0`; the result of `p.y` is `4.0`. The field name is
syntactically restricted: you cannot write `p.(some_expression)`.
The thing after the dot must be a literal field name, not a
computed value.

:::slide

## Accessing fields: dot syntax

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let _ = p.x  (* = 3. *)
let _ = p.y  (* = 4. *)
```

- The thing after `.` must be a literal field name (no
  `p.(expr)`).

:::

:::slide

## Accessing fields: destructuring

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let { x; y } = p
let _ = x  (* = 3. *)
let _ = y  (* = 4. *)
```

- `let { x; y } = p` matches `p` against the pattern and binds
  `x` and `y` as local names.
- `{ x; y }` is sugar for `{ x = x; y = y }` (field-name = bound
  name).

:::

The destructuring form `let { x; y } = p` works the same way as
the tuple destructuring `let (x, y) = pair` from last lecture. It
matches the record against the pattern and binds each name. The
shorthand `{ x; y }` desugars to `{ x = x; y = y }`: the field name
on the left, the new local name on the right, with the convention
that they match when no rename is needed.

If you have used [JavaScript ES6](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Destructuring_assignment)
or TypeScript, this is exactly the destructuring-assignment
shorthand: `const { x, y } = p;`. Same idea, slightly different
sigil. The shorthand makes code that pulls several fields out of a
record cleaner, especially when the names line up with what you
want to call the locals.

You can rename while destructuring:

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let { x = ax; y = ay } = p
```

Now the locals are called `ax` and `ay`. This is useful when you
are pulling fields from two records in the same scope and need
to distinguish them.

## Records in function parameters

A function that takes a record can access fields either by dot or
by destructuring in the parameter pattern.

```ocaml
type point = { x : float; y : float }

let distance p q =
  let dx = q.x -. p.x in
  let dy = q.y -. p.y in
  sqrt (dx *. dx +. dy *. dy)

let _ = distance { x = 0.0; y = 0.0 } { x = 3.0; y = 4.0 }  (* = 5. *)
```

The body uses `p.x`, `q.x`, etc. The same function, written with
destructured parameters:

```ocaml
let distance { x = x1; y = y1 } { x = x2; y = y2 } =
  let dx = x2 -. x1 in
  let dy = y2 -. y1 in
  sqrt (dx *. dx +. dy *. dy)
```

:::slide

## Records in function parameters: dot syntax

```ocaml
type point = { x : float; y : float }
let distance p q =
  let dx = q.x -. p.x in
  let dy = q.y -. p.y in
  sqrt (dx *. dx +. dy *. dy)
```

- Parameters `p` and `q` are records.
- Each field accessed at the call site with `.x` / `.y`.

:::

:::slide

## Records in function parameters: destructure

```ocaml
type point = { x : float; y : float }
let distance { x = x1; y = y1 } { x = x2; y = y2 } =
  let dx = x2 -. x1 in
  let dy = y2 -. y1 in
  sqrt (dx *. dx +. dy *. dy)
```

- Same function, fields pulled out up front in the parameter list.
- Common when the body uses many fields.

:::

There is no functional difference between the two styles. The
destructuring form is denser at the top of the function and looser
in the body; the dot-syntax form is the reverse. Use whichever
makes the function read more clearly. For functions that touch
two or three fields of a five-field record, dot syntax is usually
cleaner; for functions that use every field, destructuring is
nicer.

## Functional update

Records are immutable by default. To "modify" a field, you build a
*new* record that differs from the old one in just that field.
OCaml gives you a syntactic shortcut for this, called *functional
update*:

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let p2 = { p with y = 10.0 }
```

The expression `{ p with y = 10.0 }` produces a new record whose
fields are the same as `p`'s, except `y` is `10.0`. The original
`p` is unchanged.

:::slide

## Functional update

Records are **immutable by default**. To get a record that
*differs* from another in one field:

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let p2 = { p with y = 10.0 }
```

- `with` produces a *new* record, identical to `p` except `y = 10.0`.
- `p` is **unchanged**.

:::

:::slide

## Functional update: confirming `p` is unchanged

```ocaml
type point = { x : float; y : float }
let p = { x = 3.0; y = 4.0 }
let p2 = { p with y = 10.0 }
let _ = p.y   (* = 4. *)
let _ = p2.y  (* = 10. *)
```

- Immutable equivalent of "mutate this field".

:::

In any program that needs to "modify" a record (a user's
profile, a piece of state, a configuration), you write a new
version with the changed field and pass that new version
forward. The old version is still valid; nothing observable
about it has changed.

This buys you the same property we discussed for shadowing in
[the let-bindings lecture](M02-L02-let-bindings.html#shadowing):
*equational reasoning*. The value `p` is what it is forever.
Nothing later in the program can have changed `p.y` underneath
you. Once you have a record, you can reason about it without
worrying that some other code path mutated it.

For records with many fields, the `with` syntax is essential.
Writing out a 19-field literal to change one value would be silly;
`{ r with that_one_field = new_value }` is exactly what you want.

The mechanism is *not* free: OCaml allocates a new record and
copies the unchanged fields. For most records this is
imperceptible; for performance-critical inner loops on large
records, you may eventually want mutable fields, which we cover at
the end of this lecture.

## Records vs tuples: when to use which

We have now seen both compound types. Before the practical
guidance, a motivating example. Suppose you want to model a
*rectangle* by two corner points. The tuple form is
`(int * int) * (int * int)`. Now: which point is which corner?
Bottom-left first, top-right second? Or top-left, bottom-right?
The type does not say; callers have to guess (or read the doc
comment). With a record:

```ocaml
type rectangle = {
  bottom_left : int * int;
  top_right   : int * int;
}

let r = { bottom_left = (1, 2); top_right = (5, 6) }
```

The field names make the convention explicit at the type and at
every use site. Two components is on the edge of "tuples are
fine"; the moment a position is not self-evident, the record
wins even at small arity.

:::slide

## Why named fields: rectangles

:::cols
:::col 72%

A rectangle from two corner points:

```ocaml
type rect_tuple = (int * int) * (int * int)

type rectangle = {
  bottom_left : int * int;
  top_right   : int * int;
}
```

- Tuple: which corner is *first*?
- Record: the field name says.
- Two components, positions not self-evident.

:::
:::col 28%

<svg viewBox="0 0 260 200" xmlns="http://www.w3.org/2000/svg" style="max-width: 320px;">
  <rect x="40" y="40" width="180" height="120"
        fill="#dbe9fa" stroke="#1f3b6f" stroke-width="2"/>
  <circle cx="40" cy="160" r="5" fill="#1f3b6f"/>
  <circle cx="220" cy="40" r="5" fill="#1f3b6f"/>
  <text x="40" y="182" font-family="sans-serif" font-size="14"
        text-anchor="start" fill="#1f3b6f">bottom_left</text>
  <text x="220" y="30" font-family="sans-serif" font-size="14"
        text-anchor="end" fill="#1f3b6f">top_right</text>
</svg>

:::
:::

:::

:::slide

## Records vs tuples: when to use which

Use a **record** when:

- More than three fields.
- Fields have meaningful names (`first_name`, `phone`).
- Positions are *not* self-evident (rectangle corners).
- You want functional update of a few fields (`with`).

Use a **tuple** when:

- Two or three components; positions *are* self-evident.
- Short-lived (destructure right after building).

:::

A worked example. Suppose you want to model "a person."

- *Tuple version:* `("Alice", "Smith", 30, "alice@example.com")`.
  Type: `string * string * int * string`. Which `string` was the
  email again? Which was the last name?
- *Record version:* `{ first_name = "Alice"; last_name = "Smith";
  age = 30; email = "alice@example.com" }`. Type: `person`. Every
  access site says what it wants.

The record version costs you a type declaration but pays you back
every time you read or write a field. For anything more than two
or three components, this trade is overwhelmingly worth it.

A counter-example: a 2D point. Both options work. `(x, y)` is fine
and brief. `{ x; y }` is more explicit but verbose. Most OCaml
code uses records for points too, because once you have a *named*
type `point`, every function signature that takes or returns one
says so unambiguously. A function that accepts `float * float` is
ambiguous: it could be a point, a vector, a rectangle's
dimensions, anything.

The deeper habit a record encourages is giving data a *named,
checkable type* rather than leaving it as a bare string or
number. Geneticists learned this the expensive way. For years,
spreadsheets silently turned gene symbols like `SEPT2` and
`MARCH1` into dates (`2-Sep`, `1-Mar`), corrupting published
data sets; a 2016 study found the error in hundreds of papers.
The fix, in 2020, was not better discipline but a *type* change:
the gene-naming committee
[renamed the genes themselves](https://www.nature.com/articles/d41586-020-02875-4)
(`SEPT2` became `SEPTIN2`) so the values could no longer be
mistaken for something else. A field typed and named for what it
holds is the programmer's version of the same defence.

## Records compare structurally

Like all values in OCaml, records support the structural equality
operator `=`. Two records are equal if and only if all their
corresponding fields are equal.

```ocaml
type point = { x : float; y : float }
let p1 = { x = 1.0; y = 2.0 }
let p2 = { x = 1.0; y = 2.0 }
let _ = p1 = p2  (* = true *)
```

The expression `p1 = p2` is `true`, because both records have
identical field values. This is the *same* `=` we have been using
for ints and strings throughout. No special "equals" method to
define, no `equals()` override; the compiler handles it.

:::slide

## Records compare structurally

```ocaml
type point = { x : float; y : float }
let p1 = { x = 1.0; y = 2.0 }
let p2 = { x = 1.0; y = 2.0 }
let _ = p1 = p2  (* = true *)
```

- **Structural equality**: compares field by field.
- Same `=` as for ints, strings; works on records out of the box.

:::

Contrast Java, where `==` is reference equality (almost always not
what you want) and you have to write `.equals()`, taking care to
make it consistent with `hashCode()`. Contrast C, where struct
equality is, on most compilers, simply not defined (or, worse,
compares the entire memory block including padding bytes). OCaml's
`=` does the right thing on records and gives you correct equality
"for free."

## Type inference for records can surprise you

There is one wrinkle that catches people, related to how the
compiler infers the *type* of a record literal. Tuples are
straightforward: `(3, true)` is unambiguously `int * bool` because
of the inferred types of its components. Records are different:
the compiler needs to know which record type a literal refers to,
and the way it figures that out is by looking at the field names.

```ocaml
type point2 = { x : float; y : float }
type point3 = { x : float; y : float; z : float }

let p = { x = 1.0; y = 2.0 }
```

What is the type of `p`? Both `point2` and `point3` have an `x`
and a `y` field. OCaml resolves this by preferring the *most
recently declared* matching type. Here, `point3` was declared
second, but `p` only has two fields, so `point3` cannot match (a
`point3` literal needs all three fields). The compiler falls back
to `point2`, the next match, and `p` gets type `point2`.

:::slide

## Type inference for records can surprise you

```ocaml
type point2 = { x : float; y : float }
type point3 = { x : float; y : float; z : float }

let p = { x = 1.0; y = 2.0 }
```

- Inferred type of `p` is `point2`: most recently declared matching type.
- For `point3`, you'd need `{ ...; z = 0.0 }`.
- Rarely a problem in practice; fix with an annotation if needed.

:::

In practice this rarely surfaces, because most files declare each
field name in exactly one record type. When it does come up,
add a type annotation: `let p : point2 = { x = 1.0; y = 2.0 }`,
and the ambiguity is resolved.

A consequence to be aware of: if you have two record types in the
same scope with overlapping field names, dot-access expressions
become ambiguous in the same way. We will see in
[Module 7](M07-L06-module-basics.html) how modules let you put
each record type in its own namespace, which sidesteps the
problem entirely.

Records are *immutable by default*. OCaml does allow individual
fields to be opted into in-place mutation (with a `mutable`
keyword in the type declaration and a `<-` assignment operator),
but we defer that to [Module 7](M07-L02-arrays-and-mutation.html#mutable-record-fields),
where references and the rest of the mutation story land
together. For Module 4, every record is immutable, and the
functional-update form above (`{ p with ... }`) is how you
"change" a field.

## A small check

:::quiz mcq id=M04-L02-q2
Given:

```ocaml
type rgb = { r : int; g : int; b : int }
let red = { r = 255; g = 0; b = 0 }
```

What does `{ red with g = 128 }` evaluate to?

- [ ] `{ r = 0; g = 128; b = 0 }`
- [x] `{ r = 255; g = 128; b = 0 }`
- [ ] `{ r = 255; g = 0; b = 0 }` (and `red.g` becomes 128)
- [ ] A type error.

**Why:** functional update produces a *new* record that copies the
fields of `red` and overrides `g` with `128`. `red` is unchanged.
The result has the same `r` and `b` as `red`, plus the new `g`.
:::

:::quiz code id=M04-L02-q1
Define a record `circle` with fields `cx : float`, `cy : float`,
`radius : float`, and write a function `circle_area : circle ->
float` that returns the area. Use `Float.pi`.

```ocaml
type circle = { cx : float; cy : float; radius : float }

let circle_area c =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let approx_eq a b = abs_float (a -. b) < 1e-6
let () =
  check (approx_eq (circle_area { cx = 0.0; cy = 0.0; radius = 1.0 }) Float.pi) "unit";
  check (approx_eq (circle_area { cx = 5.0; cy = 5.0; radius = 2.0 }) (4.0 *. Float.pi)) "r=2";
  check (approx_eq (circle_area { cx = 0.0; cy = 0.0; radius = 0.0 }) 0.0) "zero";
  print_endline "all tests passed"
```

:::

:::solution

Reference solution: `let circle_area c = Float.pi *. c.radius *.
c.radius`, or with destructuring `let circle_area { radius; _ } =
Float.pi *. radius *. radius`. Either works; the second ignores
the centre fields explicitly.

:::

## Activity

:::slide

## Activity

Define a record type `book` with fields `title : string`, `author :
string`, `year : int`. Create one. Define a function `book_title`
that returns the title.

:::

:::solution

:::slide

## Activity solution

```ocaml
type book = { title : string; author : string; year : int }

let real_world_ocaml =
  { title = "Real World OCaml";
    author = "Minsky, Madhavapeddy, Hickey";
    year = 2013 }

let book_title b = b.title

let _ = book_title real_world_ocaml  (* = "Real World OCaml" *)
```

:::

:::

:::solution

:::slide

## Activity solution: destructure in the parameter

More idiomatic: pattern-match the record in the parameter list.

```ocaml
type book = { title : string; author : string; year : int }
let book_title { title; _ } = title
```

- `_` ignores the other fields.
- Without the `_`, OCaml warns the pattern is incomplete.

:::

:::

The `_` at the end of `{ title; _ }` is important. Without it, the
pattern `{ title }` would be incomplete: it would mean "a record
with *only* the `title` field," and the compiler would warn that
the other fields are not mentioned. The trailing `_` says
explicitly "yes, I know there are other fields; I do not care
about them." Use it whenever you destructure a subset of fields.

## What's next

:::slide

## What's next

Lecture 3: **variants** (also called sum types or tagged unions).
Records are "this *and* that". Variants are "this *or* that". The
combination of records and variants is how you model real data in
OCaml.

:::

Tuples and records are both *product types*: a value of one has a
*piece of each* of several types. The
[next lecture](M04-L03-variants.html) introduces the dual notion,
*sum types*: a value that is *one of* several alternatives. Once
you have both products and sums, you have the full algebra of
*algebraic data types*, and you can model essentially any data
shape you encounter.

## Reading

- **Cornell CS3110**, *Records and Tuples*:
  <https://cs3110.github.io/textbook/chapters/data/records_tuples.html>
- **Real World OCaml**, *Records*:
  <https://dev.realworldocaml.org/records.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
