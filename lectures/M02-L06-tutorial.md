---
title: "Tutorial: small expressions, end to end"
lecture_no: 6
week: 2
duration_target_min: 28
concepts: [expression composition, reading type errors, writing small programs]
keywords: [OCaml, tutorial, expressions, type errors, beginner exercises]
activity_question: "Write [sign : int -> int] returning -1, 0, or 1 for negative, zero, positive inputs. Then write [sign_f : float -> float] doing the same for floats. What changes between the two?"
think_about_this: "If you wrote [sign] without using [if], could you do it with arithmetic alone? What would that program look like, and is it clearer?"
reading:
  - title: "Cornell CS3110, Basics chapter (revisit anything that felt thin)"
    url: https://cs3110.github.io/textbook/chapters/basics/index.html
---

# Tutorial for Module 2


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: small expressions, end to end</h2>
<p class="title-slide-label">Module 2 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

This is the tutorial video for Module 2. We will work through five
small programs that exercise everything in the module:
[literals](M02-L01-literals.html), [`let` bindings](M02-L02-let-bindings.html),
[type inference](M02-L03-types-and-inference.html),
[operators](M02-L04-operators.html), and
[`if`-expressions](M02-L05-if-expressions.html). After the worked
problems, we will dwell on the three type errors you will see most
often in your first programs, and close with an activity for you
to try.

The point of the tutorial is to *type code* and meet the type
errors when they show up. Every cell is editable. Make
deliberate mistakes; see what the compiler says; fix them. The
five-minute frustration of "why won't this compile" is the
fastest path to fluency.

## Problem 1: classify a response time

A function that returns a label for an HTTP response time in
milliseconds. The classification: under 50ms is "instant", under
200ms is "fast", under 1000ms is "noticeable", anything else is
"slow".

```ocaml
let response_class ms =
  if ms < 50.0 then "instant"
  else if ms < 200.0 then "fast"
  else if ms < 1000.0 then "noticeable"
  else "slow"

let _ = response_class 180.0  (* = "fast" *)
```

:::slide

## Problem 1: classify a response time

- Return a label for an HTTP response in milliseconds.
- Labels: "instant", "fast", "noticeable", "slow".

```ocaml
let response_class ms =
  if ms < 50.0 then "instant"
  else if ms < 200.0 then "fast"
  else if ms < 1000.0 then "noticeable"
  else "slow"

let _ = response_class 180.0
```

- Result: `string = "fast"`.
- Try `5.0`, `500.0`, `3000.0`.
- Boundary: `50.0` is "fast"; `<` is **strict**.

:::

Result for `180.0`: `string = "fast"`. Try the boundaries:
`response_class 50.0` returns `"fast"` (because `<` is strict; 50
is not less than 50); `response_class 200.0` returns
`"noticeable"`. The choice of `<` vs `<=` at thresholds is a
judgement call. Both are right; this version treats 50 ms as
"fast" and 200 ms as "noticeable". If you would rather it be the
other way (treat 50 ms as "instant"), swap `<` for `<=`. The
point is to be deliberate.

This is also a good example of a function that has type `float
-> string`: the operator drives inference. The comparisons are
against `float` literals (`50.0`, `200.0`, etc.), so `ms` is
`float`; the branches return string literals, so the body has
type `string`; the function is `float -> string`.

## Problem 2: leap year

A year is a leap year if it is divisible by 4, *unless* divisible
by 100, *unless again* divisible by 400. So 2000 is a leap year
(divisible by 400), 1900 is not (divisible by 100 but not by 400),
2024 is (divisible by 4, not by 100), 2025 is not (not divisible
by 4).

```ocaml
let is_leap y =
  (y mod 4 = 0 && y mod 100 <> 0) || y mod 400 = 0

let _ = is_leap 2024  (* = true *)
let _ = is_leap 2025  (* = false *)
let _ = is_leap 1900  (* = false *)
let _ = is_leap 2000  (* = true *)
```

:::slide

## Problem 2: a leap year predicate

- Leap year: divisible by 4, *unless* by 100, *unless again* by 400.

```ocaml
let is_leap y =
  (y mod 4 = 0 && y mod 100 <> 0) || y mod 400 = 0

let _ = is_leap 2024
let _ = is_leap 2025
let _ = is_leap 1900
let _ = is_leap 2000
```

- Expected: `true, false, false, true`.
- Parens around `&&` not strictly needed; they make the rule **readable**.

:::

Expected: `true, false, false, true`. The parentheses around the
first `&&` are not strictly needed (`&&` binds tighter than `||`,
so the parse is the same either way), but they make the rule
readable. The expression "either (divisible by 4 and not by 100)
or (divisible by 400)" reads off the code with the parens; without
them you have to mentally insert them. Explicit parens cost
nothing at runtime; spend them.

This is a useful place to notice that `mod` produces an `int`,
which we then compare with `=`. The comparisons are all
`int = int`, so they all type-check; the `&&` and `||` glue them
into one `bool`-typed expression.

## Problem 3: shipping cost label

A two-function problem: a shipping table that computes cost from
a package's weight (kg), and a labeller that categorises the cost
as "cheap", "standard", or "premium". Here is the solution:

```ocaml
let shipping_cost weight =
  if weight < 1.0 then 5.0
  else if weight < 5.0 then 10.0
  else if weight < 20.0 then 25.0
  else 100.0

let shipping_label weight =
  let cost = shipping_cost weight in 
  if cost < 10.0 then "cheap"
  else if cost < 25.0 then "standard"
  else "premium"

let _ = shipping_label 2.5  (* = "standard" *)
```

:::slide

## Problem 3: shipping cost label

- `shipping_cost weight` returns the cost in currency units:
  - under 1 kg → 5
  - under 5 kg → 10
  - under 20 kg → 25
  - else → 100
- `shipping_label weight` categorises that cost as
  "cheap" / "standard" / "premium".

:::

:::slide

## Problem 3: shipping cost label, solution

```ocaml
let shipping_cost weight =
  if weight < 1.0 then 5.0
  else if weight < 5.0 then 10.0
  else if weight < 20.0 then 25.0
  else 100.0

let shipping_label weight =
  let cost = shipping_cost weight in
  if cost < 10.0 then "cheap"
  else if cost < 25.0 then "standard"
  else "premium"

let _ = shipping_label 2.5
```

- Result: `string = "standard"`.
- `let cost = shipping_cost weight in`: compute **once**,
  then branch.

:::

Result for `2.5`: `string = "standard"` (weight `2.5` falls in the
`< 5.0` band, so `cost = 10.0`, which is `< 25.0`, so the label
is "standard"). The pattern `let cost =
shipping_cost weight in if cost < ... else ...` is idiomatic:
when you need to inspect the same value at several thresholds,
name it once and compare repeatedly. Without the `let ... in`, you would
compute `shipping_cost weight` three times in the if-chain (once
for each threshold), which is wasteful and clutters the code.

The function `shipping_label` is built by composing two smaller
functions, `shipping_cost` and an if-chain. This is the rhythm
of functional programming: small, focused functions, combined
into larger behaviours. [Module 6](M06-L05-pipelines.html#function-composition)
will give us tools to make this composition explicit; here it is
just `let` + function call.

## Problem 4: clamp

Constrain a value to a given range. If the value is below the
lower bound, return the lower bound; if above the upper bound,
return the upper bound; otherwise return the value as-is.

```ocaml
let clamp lo hi x =
  if x < lo then lo
  else if x > hi then hi
  else x

let _ = clamp 0 10 7     (* = 7 *)
let _ = clamp 0 10 (-3)  (* = 0 *)
let _ = clamp 0 10 25    (* = 10 *)
```

:::slide

## Problem 4: clamp

Constrain a number to a range:

```ocaml
let clamp lo hi x =
  if x < lo then lo
  else if x > hi then hi
  else x

let _ = clamp 0 10 7
let _ = clamp 0 10 (-3)
let _ = clamp 0 10 25
```

- Results: `7, 0, 10`.
- Type: `int -> int -> int -> int`.
- Argument order: `lo`, `hi`, `x`.

:::

Results: `7`, `0`, `10`. The function's type is `int -> int -> int
-> int`. Note the argument order: `lo`, `hi`, `x`. There is no one
right argument order; this one mirrors the conceptual reading
("clamp into the range lo..hi, the value x"). Another defensible
order is `x lo hi`; both are fine, just be consistent.

The parenthesisation `(-3)` is the
[unary-minus pitfall from the operators lecture](M02-L04-operators.html#pitfall-3-subtraction-looks-like-unary-minus)
(without parens it would parse as subtraction). Worth remembering.

## Problem 5: tying it together

A small utility function for "divide safely":

```ocaml
let safe_divide a b =
  if b = 0.0 then 0.0
  else a /. b

let scaled value scale offset =
  safe_divide (value +. offset) scale

let _ = scaled 100.0 4.0 5.0  (* = 26.25 *)
let _ = scaled 100.0 0.0 5.0  (* = 0. *)
```

:::slide

## Problem 5: tying it together

```ocaml
let safe_divide a b =
  if b = 0.0 then 0.0
  else a /. b

let scaled value scale offset =
  safe_divide (value +. offset) scale

let _ = scaled 100.0 4.0 5.0
let _ = scaled 100.0 0.0 5.0
```

- Results: `26.25` and `0.0`.
- Second call avoids divide-by-zero via the `b = 0.0` guard.
- Sentinel `0.0` is a **design choice**, not always right.
- Alternatives: raise an exception, return a `result`. See Module 4.

:::

Results: `26.25` (which is `(100 + 5) / 4`) and `0.0`. The second
call would have been a divide-by-zero in `a /. b`, but `safe_divide`
intercepts it and returns `0.0` instead.

A short aside: replacing a bad case with a "sentinel" value
(returning `0.0` for divide-by-zero) is a *design decision*, and
not always the right one. The sentinel can hide real bugs: if your
caller didn't notice that you returned `0.0`, they might
incorporate it into a subsequent computation and silently produce
nonsense. The alternatives are:

- **[Raise an exception](M07-L03-exceptions.html)** (we cover
  exceptions in Module 7) so the caller has to handle the case
  explicitly.
- **Return an [`option`](M04-L04-recursive-types.html#the-option-type)
  or [`result`](M04-L04-recursive-types.html#the-result-type)
  type** (Module 4) that encodes "this might be a valid number, or
  it might be 'no answer'". Forces the caller to check.

For a tutorial example, the sentinel is fine. In production code,
either of the two alternatives is usually better. Mention this
to set up Modules 4 and 7.

## Reading type errors

Type errors are noisy at first. The cure is *repetition*: write
some code, read the message, fix, repeat. One error worth a
fresh slide here; two more were covered earlier in the module.

:::slide

## Reading a type error: int / float confusion

```ocaml skip
let bad r = 3.14 * r * r
```

```
Error: The constant 3.14 has type float
       but an expression was expected of type int
```

- Compiler points at `3.14`: type `float`, expected `int`.
- "Expected" is **driven by the operator**: `*` is integer mul.
- Fix: switch to `*.`.

:::

The int/float operator mix-up: you wrote `*` when you meant `*.`.
The compiler points at the `float` literal as the offender, says
it expected an `int` (because `*` is integer multiplication), and
tells you the actual type is `float`. The fix: change the
operator to `*.`.

The trick to reading the error: *the operator drives the expected
type*. If you see "expected int", look for an `int` operator
nearby; that's where the constraint came from.

Two more error shapes you have already seen elsewhere in the
module are worth re-skimming when you hit them:

- [The operators lecture, Pitfall 2](M02-L04-operators.html#pitfall-2-implicit-conversion-that-isnt-there):
  `"value: " ^ 5` fails because OCaml does not silently coerce
  `int` to `string`. Convert with `string_of_int` or use
  `Printf.sprintf`.
- [The `if` lecture, mismatched branches](M02-L05-if-expressions.html#why-the-branches-must-agree):
  `if ... then "positive" else 0` fails because the two branches
  must share a type. Decide which type you want and rewrite the
  other branch.

Together these three shapes (operator mismatch, missing
conversion, mismatched branches) account for the bulk of first-week
type errors. After enough repetition the muscle memory takes over.

## Activity

:::slide

## Activity

Re-implement
[`sign` from the `if` lecture](M02-L05-if-expressions.html#nested-ifs),
then write the float twin:

- `sign : int -> int` returning `-1`, `0`, `1`.
- `sign_f : float -> float` returning `-1.0`, `0.0`, `1.0`.

Compare what changed between the two.

:::

Try this one yourself before reading on.

:::quiz code id=M02-L06-q2
Write `sign : int -> int` that returns `-1` for negative inputs,
`0` for zero, and `1` for positive inputs.

```ocaml
let sign x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sign 5    =  1) "sign 5";
  check (sign (-3) = -1) "sign -3";
  check (sign 0    =  0) "sign 0";
  check (sign 100  =  1) "sign 100";
  print_endline "all tests passed"
```
:::

:::quiz code id=M02-L06-q1
Now write the float version: `sign_f : float -> float`
returning `-1.0`, `0.0`, `1.0`.

```ocaml
let sign_f x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sign_f 5.0    =  1.0) "sign_f 5.0";
  check (sign_f (-3.7) = -1.0) "sign_f -3.7";
  check (sign_f 0.0    =  0.0) "sign_f 0.0";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let sign x =
  if x < 0 then -1
  else if x > 0 then 1
  else 0
```

```ocaml
let sign_f x =
  if x < 0.0 then -1.0
  else if x > 0.0 then 1.0
  else 0.0
```

What changed:

- Literals: `0` to `0.0`; `-1, 0, 1` to `-1.0, 0.0, 1.0`.
- Type: `int -> int` to `float -> float`.

**Structure is identical.** OCaml made you spell out the type choice.

:::

:::

Compare the two versions. The *logic* (negative? zero? positive?)
is identical. What changed is the *literals*: `0` becomes `0.0`,
`-1` becomes `-1.0`, etc. OCaml made you write out the type choice;
the algorithm itself didn't change. This is the cost of the no-implicit-conversion
rule. The benefit is that anyone reading either function knows
unambiguously what types are involved.

A small philosophical aside, since the *think about this* prompt
invites it. Could you replace the three-way `if` in `sign` with
arithmetic? Almost; one `if` survives, to guard the zero case:

```ocaml
let sign_arith x =
  if x = 0 then 0 else x / abs x

let _ = sign_arith 5     (* = 1 *)
let _ = sign_arith (-3)  (* = -1 *)
let _ = sign_arith 0     (* = 0 *)
```

This works: `x / abs x` is `1` for positive and `-1` for negative,
and we handle the `0` case separately to avoid division by zero.
It is more compact than the three-branch `if`, but arguably
less clear: a reader has to think to convince themselves that
the formula gives the right answer. The three-branch version
*reads* like the specification.

This is a general theme: *cleverness* and *clarity* are different
virtues, and clarity usually wins. We will see this again with
recursion versus [higher-order functions](M06-L01-functions-revisited.html)
(Module 6).

## What you should be able to do now

By the end of Module 2 you should be comfortable doing the
following without checking references:

:::slide

## What you should be able to do now

After Module 2 you can:

- Write `int`, `float`, `bool`, `string` literals.
- Use `let` and `let ... in`.
- Read the type the toplevel reports.
- Recognise the common type errors.
- Write multi-branch `if` expressions.
- Compose small functions like `shipping_cost`, `clamp`, `sign`.

**Next, Module 3:** functions as values, currying, recursion.

:::

If any of these still feel shaky, the right move is to go back to
the relevant lecture and re-attempt the quizzes.
[Module 3](M03-L01-functions-as-values.html) will assume Module 2
is solid: we will start treating functions as values you can pass
around, store, and return from other functions. That's where OCaml
starts to feel like a different language from C or
Python, and you'll want the expression-level mechanics from Module
2 to be automatic.

## Reading

- **Cornell CS3110**, *Basics chapter*: a denser version of the
  same material if anything felt thin:
  <https://cs3110.github.io/textbook/chapters/basics/index.html>
- **Real World OCaml**, *A Guided Tour*: another angle:
  <https://dev.realworldocaml.org/guided-tour.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
