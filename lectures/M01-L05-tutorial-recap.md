---
title: "Tutorial: temperature conversions and small expressions"
lecture_no: 5
week: 1
duration_target_min: 25
concepts: [walkthrough, problem solving, debugging type errors, build-and-run loop]
keywords: [OCaml, tutorial, temperature, conversion, type error, beginner OCaml]
activity_question: "Write a function [bmi : float -> float -> float] that takes a mass in kilograms and a height in metres, and returns the body mass index (mass divided by height squared). Test it with [bmi 70.0 1.75]."
think_about_this: "When OCaml gives you a type error, the error message names the file, line, and *actual vs. expected* types. Why does it usually name the offending sub-expression explicitly (e.g., 'The constant 273.15') rather than just pointing at the whole line?"
reading:
  - title: "Cornell CS3110, Basics chapter (revisit if anything in Module 1 felt thin)"
    url: https://cs3110.github.io/textbook/chapters/basics/index.html
---

# Tutorial: small expressions, end to end


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: temperature conversions and small expressions</h2>
<p class="title-slide-label">Module 1 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Module 1 has been mostly explanatory: we surveyed values, types, and
the shape of an OCaml program, but we have not yet sat down and
*worked* through problems in the way you will in the weekly
assignments. This lecture is the tutorial. We will solve a small
sequence of problems start to finish, with pauses to look at type
errors, and end with one for you to attempt on your own.

Every cell on this page is editable. The cells are the point: change
the numbers, mistype an operator on purpose, see what the compiler
says. You will read more OCaml type errors in your first week than
you will in any other week of the course, simply because the type
system is unfamiliar at first. Getting comfortable reading error
messages is the single biggest accelerator from "fighting OCaml" to
"writing OCaml."

The tutorial format from here on (every module's last lecture is a
tutorial) mirrors the structure of the weekly assignments: short
problems, building from a simple statement of what's wanted to a
working solution. If you find yourself getting stuck on the
assignments later in the course, work through that week's tutorial
again. It is the closest analogue to the assignment problems.

## Problem 1: Celsius to Kelvin

The conversion is one line of arithmetic: Kelvin equals Celsius plus
273.15. Let's write the function.

```ocaml
let kelvin_of_celsius c = c +. 273.15
```

Run it. The toplevel reports `val kelvin_of_celsius : float -> float
= <fun>`: a function from `float` to `float`. The function name is
descriptive: `kelvin_of_celsius` reads as "Kelvin from Celsius."
This is the OCaml community's naming convention for unit
conversions: `target_of_source`. We will see it again with
`int_of_float`, `float_of_int`, `string_of_int`, and so on.

:::slide

## Problem 1: Celsius to Kelvin

Write a function that converts a temperature in degrees Celsius to
Kelvin (add 273.15).

```ocaml
let kelvin_of_celsius c = c +. 273.15
```

Try it:

```ocaml
let _ = kelvin_of_celsius 100.0
```

The toplevel reports `float = 373.15`. Boiling point of water,
in Kelvin.

:::

```ocaml
let _ = kelvin_of_celsius 100.0  (* = 373.15 *)
```

That is the boiling point of water in Kelvin. The `let _
= ...` is a binding that throws the name away (we just want the
toplevel to print the value).

## Why is the type `float -> float`?

Look at the function definition and ask: where did OCaml learn the
types? There were no annotations. The answer is the operator:
`+.` is float addition. It constrains both operands to be `float`,
so `c` is forced to be `float`. The result of `+.` is `float`,
so the function returns `float`. The full type is `float -> float`.

:::slide

## Problem 1: type-check

What is the type of `kelvin_of_celsius`?

```ocaml
let kelvin_of_celsius c = c +. 273.15
```

* `float -> float`. The `+.` operator forces `c` to be `float`, and the
result of `+.` is `float`, so the function is `float -> float`.
* If you had accidentally written `c + 273.15`, OCaml would have
complained: `+` is integer addition, and `273.15` is not an integer.
* The error would have read:

```text
The constant 273.15 has type float but an expression was expected of type int
```

:::

If you had typed `c + 273.15` (with the wrong, integer operator),
the compiler would have refused with:

```text
The constant 273.15 has type float but an expression was expected of type int
```

The error names *what was found* (`float` at `273.15`) and *what
was expected* (`int`). The actual type is the type of the
offending sub-expression: `273.15` is a `float`. The expected type
comes from context: `+` is integer addition, so it expects `int`
arguments. Reading errors this way (actual vs expected, with the
offending sub-expression named) is the key habit. We will come
back to it.

## Problem 2: round-trip

A reasonable sanity check: convert a temperature to Kelvin and back,
and verify you get the same number.

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15

let original = 36.6
let there_and_back = celsius_of_kelvin (kelvin_of_celsius original)
```

Run it. The toplevel reports `there_and_back : float =
36.6000000000000227`. Not the `36.6` we started with. Read on.

:::slide

## Problem 2: round-trip

* Convert Celsius to Kelvin and back.
* Verify you get the same number.

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15

let original = 36.6
let there_and_back = celsius_of_kelvin (kelvin_of_celsius original)
```

* Run it. Toplevel reports `there_and_back = 36.6000000000000227`.
  * Not exactly `36.6` (see next slide).

:::

The composition pattern `celsius_of_kelvin (kelvin_of_celsius
original)` reads naturally: first convert to Kelvin, then back to
Celsius. The parentheses are needed because function application is
left-associative; without them, OCaml would try to apply
`celsius_of_kelvin` to `kelvin_of_celsius` (a function), then to
`original`, which is not what you wanted.

This call-of-call pattern is fine for two functions but gets ugly
fast. In [Module 6](M06-L05-pipelines.html#the-pipeline-operator)
we will see the pipeline operator `|>` that lets you write
`original |> kelvin_of_celsius |> celsius_of_kelvin`, which reads
left-to-right like a Unix pipe. For now, parentheses will do.

## A float precision aside

As we just saw, `there_and_back` is *not* exactly `36.6`. Floats
are stored with finite precision, and the round-trip `+. 273.15
-. 273.15` introduces a tiny rounding error in the last digits.
Try this:

```ocaml
let _ = 0.1 +. 0.2  (* = 0.300000000000000044 *)
```

You get `0.300000000000000044`, not `0.3`. This is true in
every language that uses IEEE 754 floats: Python, JavaScript, Java,
C, OCaml. The standard binary representation of `0.1` is not
exact (`0.1` has a non-terminating binary expansion, like `1/3` has
a non-terminating decimal expansion). The rounding error per
operation is bounded by *machine epsilon*: for double-precision
floats this is 2<sup>-52</sup> ≈ 2.2 × 10<sup>-16</sup> (relative
error). It is tiny in isolation but can compound over long
computations. Goldberg's classic [*What Every Computer Scientist
Should Know About Floating-Point
Arithmetic*](https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html)
is the standard reference if you want the details.

:::slide

## Float precision aside

* `there_and_back` is not *exactly* `36.6`.
* Floats are finite-precision; `+. 273.15 -. 273.15` drifts in
  the last digits.

```ocaml
let _ = 0.1 +. 0.2
```

* Result: `float = 0.300000000000000044`, not `0.3`.
* True in every IEEE 754 language (Python, JavaScript, Java, C).

:::

:::slide

## Comparing floats: use a tolerance

* Error per op bounded by *machine epsilon*, ≈ 2.2 × 10<sup>-16</sup>
  for double-precision floats.
  * Small, but it can compound.
* Don't compare floats with `=`.
  * Compare with a tolerance:

```ocaml
let close a b = abs_float (a -. b) < 1e-9
```

* `1e-9` is arbitrary; tighten or loosen for the computation at hand.

:::

The practical takeaway: do not compare floats with `=` when the
floats come from arithmetic. Compare them with a tolerance:

```ocaml
let close a b = abs_float (a -. b) < 1e-9
```

`abs_float` is the standard library's absolute value for floats.
The function `close` returns `true` if `a` and `b` differ by less
than 10^(-9). The threshold is somewhat arbitrary; the right
threshold depends on the magnitudes involved. For physical
temperatures (between -300 and a few thousand), `1e-9` is fine.

This precision issue is one of those things you can spend hours on
in numerical code. We will not. For this course, just know that
exact-equality on floats is usually a bug, and use a tolerance
check when you need to compare.

## Problem 3: a more useful predicate

A *predicate* is a function returning `bool`. They are how you ask
"is this thing in some category?" Here is a small one: is a Celsius
temperature in the comfortable range, somewhere between 15 and 30?

```ocaml
let is_comfortable c = c >= 15.0 && c <= 30.0
```

```ocaml
let _ = is_comfortable 22.0  (* = true *)
```

```ocaml
let _ = is_comfortable 38.0  (* = false *)
```

The first call gives `true`, the second `false`. The inferred type
is `float -> bool`. The `&&` operator (boolean conjunction) forces
both sides to be `bool`; the `>=` and `<=` comparisons against
float literals force `c` to be `float`.

:::slide

## Problem 3: a more useful predicate

* A "healthy" daytime temperature is between 15 and 30 °C.
* Write a function that decides if a Celsius value is in range.

```ocaml
let is_comfortable c = c >= 15.0 && c <= 30.0
```

```ocaml
let _ = is_comfortable 22.0
```

```ocaml
let _ = is_comfortable 38.0
```

* Returns `true` and `false` respectively.
* Inferred type: `float -> bool`.

:::

This is a single-line predicate, but the shape repeats: a `bool`
expression composed from comparisons and the `&&`/`||` operators.
You will write hundreds of these. The naming convention is `is_X`
for "this returns `true` iff the thing is X" predicates; `has_X`
for "this returns `true` iff the thing has property X."

## Problem 4: combining functions

Now we compose what we have. Suppose temperatures come in from a
sensor in Kelvin (because the sensor outputs Kelvin), and you want
to apply the comfort check (which is defined in Celsius). One way
is to define a new function that bridges the two:

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15
let is_comfortable c = c >= 15.0 && c <= 30.0

let is_comfortable_kelvin k =
  is_comfortable (celsius_of_kelvin k)

let _ = is_comfortable_kelvin 295.15  (* 22 °C; = true *)
```

The point of this problem is that
`is_comfortable_kelvin` introduces *no new logic*. It is built by
*applying* `is_comfortable` to the *result* of `celsius_of_kelvin`.
This is what people mean by "function composition": building larger
functions from smaller ones by feeding outputs to inputs.

:::slide

## Problem 4: combining functions

* Temperatures from a sensor arrive in Kelvin.
  * The comfort check we have is defined in Celsius.
  * Compose: feed the Kelvin → Celsius result into the comfort check.

:::fragment

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15
let is_comfortable c = c >= 15.0 && c <= 30.0

let is_comfortable_kelvin k =
  is_comfortable (celsius_of_kelvin k)

let r = is_comfortable_kelvin 295.15
```

* Result: `true`.
* No new logic; just `is_comfortable` applied to the result of
  `celsius_of_kelvin`.

:::

:::

This is the rhythm of functional programming. Small, focused
functions, each doing one well-named thing, composed into larger
behaviours. [Module 6](M06-L05-pipelines.html#function-composition)
will give us tools to make this composition explicit; for now, just
notice the pattern.

## Reading a type error

Type errors are noisy at first. Let's write one deliberately so we
can read the message together.

```ocaml skip
let bad c = c + 273.15
```

The toplevel refuses with something like:

```
Error: The constant 273.15 has type float but an expression was
       expected of type int
```

There are three pieces of information in there. Each piece earns
its keep:

- **The offending sub-expression.** "The constant `273.15`." The
  message does not just point at the whole line; it names the
  specific sub-expression whose type was wrong. Useful when the
  line has several sub-expressions.
- **The actual type.** `273.15` has type `float`. The compiler
  computed this from the syntactic form (any literal with a
  decimal point is `float`).
- **The expected type.** `int`. The compiler computed this from
  context: the operator `+` expects two `int` arguments, so the
  thing in the second slot was expected to be `int`. You have to
  recover the "why" yourself by looking at the surrounding code,
  but in practice the cursor position and the named sub-expression
  make this quick.

:::slide

## Reading a type error

* Type errors are noisy at first; write one deliberately.

```ocaml skip
let bad c = c + 273.15
```

The toplevel says:

```text
Error: The constant 273.15 has type float but an expression was
       expected of type int
```

:::

:::slide

## Three pieces in a type error

* The **offending sub-expression** (named: "the constant `273.15`").
* The **actual type** (`float`).
* The **expected type** (`int`, forced here by the integer `+`).

Fix: use `+.` instead of `+`.

:::

The fix in this case: change `+` to `+.`. Done.

Notice the shape of the sentence: *named sub-expression*, *actual
type*, "but expected", *expected type*. The actual type comes from
the thing you wrote (and the message points right at it); the
expected type comes from context (the operator, the function
signature, the surrounding `let`). When you read an OCaml type
error, lock on to those three pieces first, then look at the code
to see *why* the expected type is what it is. Almost every type
error you will read in this course follows this shape.

## Activity: BMI

Try this one yourself. Write a function `bmi` that takes a mass in
kilograms and a height in metres, and returns the body mass index:
mass divided by height squared.

:::slide

## Activity

* Write `bmi mass height`.
* Mass in kilograms, height in metres.
* Returns mass divided by height squared.

```text
(* fill in *)
let bmi mass height = ???
```

* Test it: `bmi 70.0 1.75` should be about `22.86`.

:::

:::quiz code id=M01-L05-q2
Write `bmi : float -> float -> float` that returns mass divided by
height squared.

```ocaml
let bmi mass height =
  failwith "not implemented"
```

```ocaml skip
let close a b = abs_float (a -. b) < 1e-6
let check b m = if not b then failwith m
let () =
  check (close (bmi 70.0 1.75) 22.8571428571428577) "bmi 70 1.75";
  check (close (bmi 80.0 1.80) 24.691358024691358) "bmi 80 1.8";
  check (close (bmi 60.0 1.65) 22.03856749311295)  "bmi 60 1.65";
  print_endline "all tests passed"
```
:::

The expected answer for `bmi 70.0 1.75` is about `22.86`, in the
"healthy weight" band by WHO classification. If your function
type-checked and returned a sensible number, well done. If you got
a type error, the most likely cause is using `/` (integer
division) instead of `/.` (float division), or `*` instead of `*.`.

:::solution

:::slide

## Activity solution

```ocaml
let bmi mass height = mass /. (height *. height)
```

```ocaml
let _ = bmi 70.0 1.75
```

* Toplevel reports `float = 22.8571428571428577`.
* Close to the expected `22.86`; trailing digits are float
  precision noise.
* Inferred type: `float -> float -> float`. Two floats in, one
  float out.

:::

:::

The reference solution: `let bmi mass height = mass /. (height *.
height)`. The parentheses around `height *. height` are necessary:
`*.` and `/.` have *equal* precedence and associate to the left,
so without them OCaml parses `mass /. height *. height` as
`(mass /. height) *. height`, which is *wrong* (it multiplies by
the height instead of dividing by it). This is a small but real
gotcha: operator precedence in OCaml matches the familiar
conventions for `+`, `-`, `*`, `/`, but you still have to think
about it when you have several operators in a row.

## What you should be able to do now

By the end of Module 1, you should be comfortable doing the
following without checking a reference:

:::slide

## What you should be able to do now

- Write a small function in OCaml and run it.
- Read the type the toplevel reports.
- Recognise when a type error is asking for `+.` rather than `+`.
- Compose two functions by feeding one's result into the next.

That's the foundation.

- **Next:** Module 2 dives into expressions, `let` bindings,
  operators, `if`/`then`/`else`.
- We start writing real (small) programs.

:::

If any of these still feels shaky, this is the moment to go back to
the earlier lectures or the reference materials and shore it up.
Module 2 will assume all of this and build on it. If you can write
and read short OCaml functions involving `int`, `float`, `string`,
and `bool`, and you can interpret a type error well enough to fix
it, you are ready.

:::quiz mcq id=M01-L05-q1
You write `let twice n = n + n` and the toplevel reports the type as
`int -> int`. You then try `twice 3.5`. What does OCaml do?

- [x] Reject with a type error at compile time.
- [ ] Implicitly convert `3.5` to `3` and return `6`.
- [ ] Return `7.0`, lifting `+` to floats.
- [ ] Return `6.5`, doing mixed-type addition.

**Why:** OCaml has no implicit numeric conversion. The function is
`int -> int`; calling it with a `float` is a type error caught at
compile time, before the program runs. To pass a `float`, you would
convert it explicitly with `int_of_float`, but note that this
truncates (`int_of_float 3.5 = 3`), so the call `twice
(int_of_float 3.5)` would be `twice 3 = 6`. If you wanted float
doubling, define a separate `twice_f x = x +. x` of type `float ->
float`.
:::

## What's next

Module 2 picks up where this lecture ends.
[Lecture 1 of Module 2](M02-L01-literals.html) will go deep on
literals (we touched them lightly here),
[Lecture 2](M02-L02-let-bindings.html) on `let` bindings (we have
used them but not explored shadowing and scope rules in depth),
[Lectures 3](M02-L03-types-and-inference.html)-[4](M02-L04-operators.html)
on type inference and operators,
[Lecture 5](M02-L05-if-expressions.html) on `if`/`then`/`else` as
an expression (the first really new concept), and
[Lecture 6](M02-L06-tutorial.html) is the tutorial for Module 2.
The pace picks up but the shape (lectures plus a tutorial) is what
every week looks like.

## Reading

- **Cornell CS3110, Basics chapter** revisit if anything in Module 1
  felt thin: <https://cs3110.github.io/textbook/chapters/basics/intro.html>
- **Real World OCaml, A Guided Tour** for an alternative angle on
  the same material:
  <https://dev.realworldocaml.org/guided-tour.html>
- **Goldberg (1991), *What Every Computer Scientist Should Know
  About Floating-Point Arithmetic*** for the precise story behind
  the float-precision aside:
  <https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
