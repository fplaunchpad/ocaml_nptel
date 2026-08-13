---
title: "Operators, precedence, and common pitfalls"
lecture_no: 4
week: 2
duration_target_min: 22
concepts: [operator precedence, arithmetic operators, comparison, logical operators, common type errors]
keywords: [OCaml, operators, precedence, comparison, equality, logical operators]
activity_question: "Without parentheses, how does OCaml parse [1 + 2 * 3 = 7 && true]? What does it evaluate to?"
think_about_this: "Why does OCaml have [&&] short-circuit but not, say, a special short-circuiting form of [+]? What property of [&&] makes short-circuiting safe?"
reading:
  - title: "OCaml manual, Operators section"
    url: https://v2.ocaml.org/manual/expr.html
---

# Operators, precedence, and common pitfalls


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Operators, precedence, and common pitfalls</h2>
<p class="title-slide-label">Module 2 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: operators

- The comprehensive reference for OCaml's operators.
- Three unusual choices that catch beginners:
  - separate arithmetic for `int` and `float` (`+` vs `+.`);
  - structural equality `=`, not physical `==`;
  - restricted polymorphic comparison.
- Precedence: which binds tighter than which.
- The pitfalls every first-week student hits.
- Nothing deep here, but sharp-edged.

:::

You already know most of OCaml's operators from school arithmetic
and from previous lectures (the
[tour](M01-L03-ocaml-tour.html#integers) introduced `+`, `*`, `/`,
`mod`; the [literals lecture](M02-L01-literals.html#float-arithmetic-uses-different-operators)
contrasted `+` and `+.`). This lecture is the comprehensive
reference. It lays out the full set, says which bind tighter than
which, and walks through the small set of mistakes that beginners
reliably make in their first week. There is nothing deep here, but
a lot of it is sharp-edged: every one of the pitfalls in the second
half of the lecture has caught me out at some point.

The reason to have a dedicated lecture on operators is that OCaml
makes some unusual choices: separate arithmetic operators for `int`
and `float`, structural-not-physical equality as the default, and a
restricted notion of polymorphic comparison. These choices have good
reasons (we have argued for them throughout Module 1 and the first
half of Module 2), but they generate a predictable set of beginner
type errors. Pre-reading those errors here will save you debugging
time later.

## Arithmetic, by type

OCaml has separate arithmetic operators for `int` and `float`. The
float versions all carry a trailing dot. You have seen this before;
the full table is worth having in one place.

:::slide

## Arithmetic, by type

| Operation | `int` | `float` |
| --- | --- | --- |
| Add | `a + b` | `a +. b` |
| Subtract | `a - b` | `a -. b` |
| Multiply | `a * b` | `a *. b` |
| Divide | `a / b` (truncating) | `a /. b` |
| Remainder | `a mod b` | (`Float.rem a b`) |

- Float operators all end in `.`.
- Mixing `int` and `float`: **type error**.
- Convert with `float_of_int` or `int_of_float`.

:::

:::slide

## Arithmetic, by type: power, negate, abs

| Operation | `int` | `float` |
| --- | --- | --- |
| Power | (no built-in; write `x * x * x`) | `a ** b` |
| Negate | `-a` | `-. a` |
| Absolute | `abs a` | `Float.abs a` |

- `**` is float-only; the stdlib has no integer `pow`. Spell out
  the multiplication, or write a small recursive `pow`.
- Float negation `-.` is the one prefix-operator-with-a-dot.
- `abs_float` is deprecated; prefer `Float.abs`.

:::

A few details worth flagging:

**Division.** `a / b` on `int` is *truncating*: it throws away the
fractional part. So `7 / 2 = 3`, not `3.5`. The companion is `a
mod b`, the integer remainder. For floats, `a /. b` is the ordinary
mathematical division, returning `float`.

**Power.** OCaml's `**` operator is float exponentiation:
`2.0 ** 10.0 = 1024.0`. The standard library has no built-in
integer power. For small powers, spell out the multiplication
(`let cube x = x * x * x`); for arbitrary integer powers, write a
small recursive helper (`let rec pow a b = if b = 0 then 1 else
a * pow a (b - 1)`).

**Negation.** Unary negation on `int` uses the same `-` symbol as
subtraction, but it sits in front of a single argument: `let x =
-5`. For floats, the unary negation is `-.` (with a trailing dot):
`let y = -. 3.14`. This is the only case where you write `-.` as a
*prefix* operator instead of an infix one.

**Absolute value.** `abs` for `int`, `Float.abs` for `float`. The
stdlib used to have `abs_float`; that name is deprecated in
favour of `Float.abs`. Either works in current OCaml.

The two-operators-per-arithmetic rule is the most distinctive
thing about OCaml arithmetic and the source of most beginner type
errors. Internalise: `+` for ints, `+.` for floats; `*` for ints,
`*.` for floats; etc. Module 2 will burn this into your fingers.

`mod` is the integer remainder. There is no `mod.` operator for
floats; if you need float remainder, use `Float.rem a b` from the
standard library.

## Comparison and equality

The comparison operators (`<`, `<=`, `>`, `>=`) and the logical
operators (`&&`, `||`, `not`) were introduced with
[booleans](M02-L01-literals.html#booleans). A quick recap of the
logical side: `&&` and `||` short-circuit, exactly as in C / Java
/ Python, and negation is the standard-library function `not`,
not the symbol `!`.

Equality deserves the fuller treatment we promised back in the
[tour of OCaml](M01-L03-ocaml-tour.html). OCaml has *two* equality
operators, and they answer different questions:

- `=` is **structural** equality: do the two values have the same
  *contents*? It compares recursively (two ints are `=` when they
  are the same number, two strings when they have the same bytes,
  two pairs when their components are correspondingly `=`) and it
  is *polymorphic*: the one operator works on ints, floats,
  strings, pairs, and most other data. Its negation is `<>`.
- `==` is **physical** equality: are the two values the *same
  object in memory*? Its negation is `!=`.

Structural equality is the question everyday code asks (is the
input the string `"quit"`?), so the rule for beginners is simple:
always write `=`. Physical equality only matters in advanced code
that cares about sharing and mutation; when you meet `==` in the
wild, read it as a deliberate, expert-level choice.

The two operators can disagree. A *pair* like `(1, 2)` bundles two
values into one (pairs get a proper introduction later in the
course); here are two pairs built separately, with the same
contents:

```ocaml
let p = (1, 2)
let q = (1, 2)

let _ = p = q    (* = true  : same contents *)
let _ = p == q   (* = false : two distinct objects in memory *)
let _ = p == p   (* = true  : literally the same object *)
```

`p` and `q` are structurally equal but physically distinct: each
`(1, 2)` allocated its own pair. This is the trap for programmers
arriving from C or Java, where `==` *is* the everyday equality
operator: an OCaml `==` test compiles fine and then returns
`false` for values you can plainly see are equal. If an equality
test in your code is mysteriously failing, check the operator
first.

The disagreement needs an *allocated* value to show up. An `int`
is stored directly in the machine word, not behind a pointer, so
two equal ints are the same bits and `==` cannot tell them apart:

```ocaml
let _ = 1 == 1      (* = true : no allocation, no separate identity *)
let _ = 'a' == 'a'  (* = true : chars and booleans work the same way *)
```

This is what makes the trap quiet: tested on ints, `==` appears to
behave as everyday equality, and it stops the moment the data is a
pair, a list, or a string. Always write `=`.

One caveat to file away: structural equality works on *data*, but
it raises a runtime exception (`Invalid_argument "compare:
functional value"`) if the values being compared contain
functions, because there is no general way to decide whether two
functions behave identically.

## String concatenation

Strings concatenate with `^`, not `+`:

```ocaml
let _ = "first" ^ " " ^ "second"  (* = "first second" *)
```

:::slide

## String concatenation

```ocaml
let _ = "first" ^ " " ^ "second"
```

- `^` is **right-associative**.
- Fine for a few; for many, use `String.concat`:

```ocaml
let _ = String.concat ", " ["apple"; "banana"; "cherry"]
```

- `String.concat sep xs`: joins `xs` with `sep` between.
- Faster than chained `^`.

:::

`^` is right-associative: `"a" ^ "b" ^ "c"` parses as `"a" ^ ("b"
^ "c")`. This is mostly invisible (the result is the same either
way), but it matters for performance on long chains: right
association means the leftmost strings are concatenated last, so
each intermediate result keeps growing. For a few strings, fine.
For many, use `String.concat`:

```ocaml
let _ = String.concat ", " ["apple"; "banana"; "cherry"]
(* = "apple, banana, cherry" *)
```

`String.concat sep xs` joins the elements of `xs` with `sep`
between them. It allocates the result string once, of exactly the
right size; it is dramatically faster than `^`-chaining when you
have dozens or hundreds of pieces.

For formatted output, `Printf.sprintf` is the standard tool:

```ocaml
let _ = Printf.sprintf "value: %d" 5  (* = "value: 5" *)
```

The format string `"%d"` is the C-style integer specifier. We
will see Printf in more depth later.

## Function application is its own "operator"

Function application in OCaml is *juxtaposition*: just write the
function next to its arguments, separated by spaces. No parentheses
or commas.

```ocaml
let _ = succ 5                  (* = 6 *)
let _ = max 3 7                 (* = 7 *)
let _ = String.length "hello"   (* = 5 *)
```

:::slide

## Function application is its own "operator"

- **Function application is juxtaposition.** No parens.

```ocaml
let _ = succ 5
let _ = max 3 7
let _ = String.length "hello"
```

- Function application is **left-associative**: `f x y` parses as
  `(f x) y`.
- Parens only for **grouping**:

```ocaml
let _ = succ (max 3 7)
```

:::

Function application binds *tighter than any infix operator*, so
`succ 5 + 3` parses as `(succ 5) + 3 = 9`, not `succ (5 + 3) = 9`.
(They give the same answer here by coincidence; in general the
two parses would differ.)

Function application is *left-associative*: `f x y` means `(f x)
y`. So when you nest calls, you need parentheses to group:

```ocaml
let _ = succ (max 3 7)  (* = 8 *)
```

Without the parentheses, OCaml would parse this as `succ max 3 7`,
i.e. `((succ max) 3) 7`: try to apply `succ` to `max`, which the
compiler rejects.

The "no parentheses on function call" rule takes adjusting to if
you came from C-family languages. The reason OCaml does this is
that it makes *partial application* (supplying some but not all
arguments and getting back a function) a natural reading. We will
see [partial application](M03-L03-currying.html#partial-application-the-payoff)
in Module 3.

## Operator precedence

Here is OCaml's operator precedence, tightest at the top, loosest at
the bottom. Levels separated by horizontal lines bind tighter than
levels below.

:::slide

## Operator precedence (tightest to loosest)

<div class="precedence-table">

| Lvl | Operators                                  | Notes              |
|----:|--------------------------------------------|--------------------|
|   1 | `.`                                        | record / module access |
|   2 | $f\ x$                                     | function application |
|   3 | `*`, `/`, `mod`, `*.`, `/.`                | multiplicative     |
|   4 | `+`, `-`, `+.`, `-.`                       | additive           |
|   5 | `^`, `@`                                   | string / list concat |
|   6 | `<`, `=`, `>`, `<=`, `>=`, `<>`            | comparisons        |
|   7 | `&&`                                       | logical and        |
|   8 | <code>&#124;&#124;</code>                  | logical or         |
|   9 | `,`                                        | tuple constructor  |
|  10 | `;`                                        | sequence           |

</div>

- When in doubt, **parenthesize**.

:::

A few observations:

- *Function application* is one of the tightest forms. Tighter than
  any infix operator. This is unusual; in many languages, function
  call has the same precedence as parenthesisation.
- *Arithmetic* follows the school order: `*`, `/`, `mod` tighter
  than `+`, `-`. Same as everywhere.
- *Comparisons* sit below arithmetic, so `1 + 2 < 5` parses as
  `(1 + 2) < 5`, as expected.
- `&&` binds tighter than `||`, same as everywhere.
- The tuple constructor `,` binds *very* loosely, so `1, 2 + 3` is
  `(1, 5)`, not `(1, 2) + 3`.

When in doubt, just parenthesise. Explicit parentheses cost
nothing at runtime and make the parse intent clear to the
reader. Code is read far more often than it is written; spend the
ten extra keystrokes.

`mod` is at the same precedence level as `*` and `/` (and is
left-associative). So `10 mod 3 * 2` is `(10 mod 3) * 2 = 2`, not
`10 mod (3 * 2)`.

## Pitfall 1: `+` instead of `+.`

By far the most common type error in your first week:

```ocaml skip
let area r = 3.14159 * r * r
```

The compiler refuses with:

```
Error: The constant 3.14159 has type float
       but an expression was expected of type int
```

:::slide

## Pitfall 1: `+` instead of `+.`

```ocaml skip
let area r = 3.14159 * r * r
```

OCaml refuses:

```
Error: The constant 3.14159 has type float
       but an expression was expected of type int
```

Fix: `3.14159 *. r *. r`. The operator drives the type.

:::

The fix is `3.14159 *. r *. r` (note the three dots). The error
message is helpful once you can read it: it says "expected `int`"
because `*` is the integer-multiplication operator; it names the
constant `3.14159` and says it has type `float` because that is a
float literal. The mismatch tells you which operator is wrong.

## Pitfall 2: implicit conversion that isn't there

In JavaScript, you can write `"value: " + 5` and the
language coerces the `int` to a string. OCaml does not:

```ocaml skip
let _ = "value: " ^ 5
```

:::slide

## Pitfall 2: implicit conversion that isn't there

```ocaml skip
let _ = "value: " ^ 5
```

```
Error: The constant 5 has type int but an expression was expected
       of type string
```

- JavaScript coerce silently. OCaml does not.

```ocaml
let _ = "value: " ^ string_of_int 5
```

Or `Printf.sprintf` for richer formatting:

```ocaml
let _ = Printf.sprintf "value: %d" 5
```

:::

`^` is string concatenation; both operands must be `string`. To
mix an `int` in, convert explicitly with `string_of_int`. For
richer formatting (decimal precision, padding, hex, scientific
notation), `Printf.sprintf` is the go-to.

The lack of implicit conversion is a feature, not a bug. Languages
that *do* coerce automatically have famously confusing edge cases
(JavaScript's `1 + "1" == "11"` but `1 - "1" == 0`; Python's
"strict but with surprises"). OCaml's "always be explicit" rule
means you read code and know exactly what conversion is happening.

## Pitfall 3: subtraction looks like unary minus

```ocaml skip
let _ = abs -5
```

Looks like "absolute value of negative 5." Actually parses as "abs
minus 5":

:::slide

## Pitfall 3: subtraction syntax

```ocaml skip
let _ = abs -5
```

- Looks like "absolute value of negative 5".
- **Parses as** `abs - 5`: type error.
- Fix: parenthesize the negative.

```ocaml
let _ = abs (-5)
```

- Same trap with `-.` for floats.

:::

`abs -5` is parsed as `abs - 5`: take the function `abs`, subtract
`5` from it. That doesn't type-check (you cannot subtract from a
function), so you get an error. The fix is to parenthesise the
negative literal: `abs (-5)`. Same with floats: `Float.abs (-. 3.14)`.

This catches everyone at least once. When you have a unary minus
in argument position, parenthesise it.

## Pitfall 4: comparison chains are not a thing

In Python, `0 < x < 10` reads as you'd hope: "x is between 0 and
10." Python is unusual in supporting this; OCaml (like most
languages) does not (we bind `x` to `5` so the chain itself is
the only error):

```ocaml skip
let _ = let x = 5 in 0 < x < 10
```

:::slide

## Pitfall 4: comparison chains aren't a thing

```ocaml skip
let _ = let x = 5 in 0 < x < 10
```

- Parses as `(0 < x) < 10`: compares a `bool` to `10`.
- Error: constant `10` has type `int` but expected `bool`.
- Spell it out with `&&`:

```ocaml
let _ = let x = 5 in 0 < x && x < 10  (* = true *)
```

- Python supports chains; OCaml (like most languages) does not.

:::

OCaml parses this as `(0 < x) < 10`: first compare `0 < x`, which
gives `bool`, then compare that `bool` to `10`. The polymorphic
`<` wants both operands at the same type, so the compiler refuses
with *"The constant 10 has type int but an expression was expected
of type bool"*. The fix is to write the bounded check with `&&`:

```ocaml
let _ = let x = 5 in 0 < x && x < 10  (* = true *)
```

This idiom (`a < x && x < b`) is so common that you internalise it
quickly.

## A quick check

:::quiz mcq id=M02-L04-q2
What is the value of this OCaml expression?

```ocaml
let _ = 1 + 2 * 3 = 7 && true
```

- [ ] `false`
- [x] `true`
- [ ] A type error: `int` compared to `bool`.
- [ ] `7`

**Why:** apply precedence. `*` binds tighter than `+`, so `2 * 3 =
6`. Then `+`: `1 + 6 = 7`. Then `=`: `7 = 7` is `true`. Then `&&`:
`true && true` is `true`. Reading the implicit parentheses:
`(((1 + (2 * 3)) = 7) && true)`. The expression has type `bool`
and value `true`.
:::

:::slide

## Activity

How does OCaml parse:

```ocaml
let _ = 1 + 2 * 3 = 7 && true
```

What does it evaluate to? Trace through.

:::

:::slide

## Activity discussion

```ocaml
let _ = 1 + 2 * 3 = 7 && true
```

Parse with precedence:

- `*` tighter than `+`: do `2 * 3` first.
- Then `+`: `1 + 6 = 7`.
- Then `=`: `7 = 7` is `true`.
- Then `&&`: `true && true` is `true`.

Answer: `true`. Implicit: `((1 + (2 * 3)) = 7) && true`.

Any grouping that surprises you: candidate for **explicit parens**.

:::

A code challenge to close out:

:::quiz code id=M02-L04-q1
Write `in_range : int -> int -> int -> bool` that returns `true`
exactly when `x` lies in the closed interval `[lo, hi]`. Use the
`&&`-idiom this lecture introduced. Argument order:
`in_range lo hi x`.

```ocaml
let in_range lo hi x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (in_range 0 10 5     = true)  "interior";
  check (in_range 0 10 0     = true)  "at lower bound";
  check (in_range 0 10 10    = true)  "at upper bound";
  check (in_range 0 10 (-1)  = false) "below";
  check (in_range 0 10 11    = false) "above";
  print_endline "all tests passed"
```
:::

:::solution

`let in_range lo hi x = lo <= x && x <= hi`. The `&&` short-circuits,
so the upper-bound check only runs when the lower-bound check
already passed.

:::

## What's next

[Next lecture](M02-L05-if-expressions.html): `if`/`then`/`else` as
an expression. The big conceptual shift is that `if` returns a
value in OCaml: it is not a statement that controls execution
flow, but an expression that evaluates to one of two values. The
downstream consequence is that you can use `if` anywhere an
expression can go: as a function argument, as the right-hand side
of a `let`, inside another `if`.

:::slide

## What's next

- Lecture 5: `if`/`then`/`else` as an **expression**.
- Turns straight-line code into branching code.
- Worked example of OCaml's expression-oriented design.

:::

## Reading

- **OCaml manual**, *Expressions* (operator section): the
  authoritative precedence table:
  <https://v2.ocaml.org/manual/expr.html>
- **Cornell CS3110**, *Operators*: a friendlier walk-through:
  <https://cs3110.github.io/textbook/chapters/basics/expressions.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
