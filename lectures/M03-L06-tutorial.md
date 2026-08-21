---
title: "Tutorial: Fibonacci, powers of two, fast power, digits"
lecture_no: 6
week: 3
duration_target_min: 28
concepts: [worked recursive examples, tail vs naive recursion, memoization preview]
keywords: [OCaml, tutorial, fibonacci, power of two, power, digits, recursion, tail recursion]
activity_question: "Write [sum_digits : int -> int] that returns the sum of the base-10 digits of a non-negative integer. [sum_digits 12345 = 15]. Same shape as [count_digits]; what changes in the recursive case?"
think_about_this: "When a function does not terminate on certain inputs (like negative arguments to factorial), should it crash, return a sentinel, or return an [option] / [result]? What does each choice cost the caller?"
reading:
  - title: "Cornell CS3110, Recursion examples"
    url: https://cs3110.github.io/textbook/chapters/basics/functions.html
---

# Tutorial for Module 3


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: Fibonacci, powers of two, fast power, digits</h2>
<p class="title-slide-label">Module 3 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: the Module 3 tutorial

- Four small problems: Fibonacci, power-of-two test, fast power,
  digit counting.
- Goal: consolidate recursion, accumulators, local helpers.
- Recurring choice: *naive* vs *tail-recursive* form.
  - Rule of thumb: write the clear naive version first.
  - Convert with an accumulator when inputs get large.

:::

This tutorial works through four small problems: Fibonacci (naive
and linear-time), testing whether a number is a power of two,
fast integer power (by square-and-multiply), and digit-counting.
None are individually
hard; the point is to consolidate the techniques from Module 3
([recursion](M03-L02-recursion.html),
[tail calls and accumulators](M03-L04-tail-recursion.html),
[local helpers](M03-L05-local-and-mutual.html)) and to make
explicit the choice between *naive recursive* and *tail-recursive*
implementations.

The general rule of thumb: write the naive recursive form first.
It is almost always the clearest expression of the algorithm and
it is what you should reach for in a sketch or a small script. If
the function will be called on large inputs (long lists, large
numbers, in hot paths), convert to tail-recursive form using the
[accumulator pattern](M03-L04-tail-recursion.html#the-accumulator-pattern)
from the tail-recursion lecture. Most code never needs the
conversion; practitioners
get a feel for which functions are likely to be called on big data
and rewrite those preemptively.

## Problem 1: Fibonacci, naively

The Fibonacci numbers are defined by `F(0) = 0`, `F(1) = 1`, and
`F(n) = F(n-1) + F(n-2)` for `n >= 2`. The natural recursive
translation:

```ocaml
let rec fib n =
  if n < 2 then n
  else fib (n - 1) + fib (n - 2)

let _ = fib 20  (* = 6765 *)
```

:::slide

## Problem 1: Fibonacci, naively

```ocaml
let rec fib n =
  if n < 2 then n
  else fib (n - 1) + fib (n - 2)

let _ = fib 20  (* = 6765 *)
```

- Two recursive calls per step; call tree branches.
- Total calls: exponential in `n`.
- `fib 30`: slow. `fib 40`: slower. `fib 50`: impractical.

:::

The function is correct and the code reads exactly like the
mathematical definition.

The trouble is performance. Each call to `fib n` (for `n >= 2`)
makes *two* recursive calls. So the work to compute `fib n` is
proportional to the number of nodes in a binary call tree of depth
`n`, which is exponential. Specifically, the number of function
calls to compute `fib n` is roughly `phi^n` where `phi = 1.618...`
is the golden ratio. So `fib 30` does about a million calls (takes
under a second), `fib 40` does about 150 million calls (takes
several seconds), `fib 50` does about 20 billion calls (takes
minutes). The naive `fib` is unusable for any `n` past 40 or so.

## Why is naive Fibonacci so slow?

The cause is *overlapping subproblems*. When `fib 5` computes
`fib 4 + fib 3`, the call to `fib 4` itself computes
`fib 3 + fib 2`. So
`fib 3` is computed *twice* (once directly, once inside `fib 4`).
`fib 2` is computed three times, `fib 1` five times, `fib 0` three
times. The deeper the recursion, the more redundant work.

The fix is to compute each value only once and feed it forward. The
cleanest way in a pure-functional style is to carry the last *two*
values as an accumulator pair and update them as you go:

```ocaml
let fib n =
  let rec go a b k =
    if k = n then a
    else go b (a + b) (k + 1)
  in
  go 0 1 0

let _ = fib 46  (* = 1836311903 *)
```

:::slide

## Why is naive Fibonacci so slow?

- `fib 4` recomputes the `fib 3` that `fib 5` already needed.
- Overlapping sub-problems blow up the work.
- Faster: carry a pair `(a, b) = (fib (k-2), fib (k-1))`:

```ocaml
let fib n =
  let rec go a b k =
    if k = n then a
    else go b (a + b) (k + 1)
  in
  go 0 1 0

let _ = fib 46  (* = 1836311903 *)
```

- Linear in `n`; one recursive call per step.

:::

`fib 46` now returns `1836311903` immediately. (We use 46 rather
than 50 because the in-browser `int` is 32-bit and `fib 47`
already overflows it; `fib 46` is the largest Fibonacci that fits.
On a native 64-bit OCaml, `fib 50 = 12_586_269_025` fits fine.)
The trick: the
accumulator holds *two* values rather than one. At each step, `a`
is `fib k` and `b` is `fib (k+1)`. The recursive call advances both:
the new `a` is `b` (the previous `fib (k+1)`), the new `b` is `a +
b` (the next Fibonacci number, by the recurrence).

The two-accumulator trick is the canonical way to make Fibonacci
fast. It works for any recurrence that depends on the last *k*
values: keep a window of those values as the accumulator. Many
common sequences (Lucas numbers, Padovan numbers, etc.) yield to
the same shape. The general technique of caching intermediate
results is called *memoisation*; we will see it more thoroughly
when we get to mutable state in
[Module 7](M07-L01-references.html).

This `fib` is also tail-recursive (the recursive `go` call is the
last thing in the else-branch), so it runs in constant stack space.
You can call `fib 1_000_000` without blowing the stack, although the
result is a number with hundreds of thousands of digits and would
overflow OCaml's native `int` long before that.

## Problem 2: is it a power of two?

A positive integer is a power of two (`1`, `2`, `4`, `8`, ...)
exactly when repeatedly halving it lands on `1` without ever
passing through an odd number bigger than `1`. The recursion: `1`
is a power of two (`2^0`); an even number is a power of two iff
its half is; everything else (zero, negatives, odd numbers above
`1`) is not.

```ocaml
let rec is_power_of_two n =
  if n = 1 then true
  else if n <= 0 || n mod 2 = 1 then false
  else is_power_of_two (n / 2)

let _ = is_power_of_two 64  (* = true *)
let _ = is_power_of_two 96  (* = false *)
```

:::slide

## Problem 2: is it a power of two?

```ocaml
let rec is_power_of_two n =
  if n = 1 then true
  else if n <= 0 || n mod 2 = 1 then false
  else is_power_of_two (n / 2)

let _ = is_power_of_two 64  (* = true *)
let _ = is_power_of_two 96  (* = false *)
```

- Base cases first: `1` succeeds; zero, negatives, odds fail.
- Recursive case: halve and ask again.
- Termination: `n / 2 < n` for `n >= 2`; strictly decreasing.
- Already tail-recursive.

:::

Trace the two calls: `is_power_of_two 64` -> `32` -> `16` -> `8`
-> `4` -> `2` -> `1` -> `true`; `is_power_of_two 96` -> `48` ->
`24` -> `12` -> `6` -> `3`, and `3` is odd -> `false`.

Three things to notice. First, the function is already
tail-recursive without any rewriting. The recursive call is the
final expression of its branch; there is no work after it. No
accumulator is needed because the answer needs no combining on
the way back up; the base case *is* the answer.

Second, termination: `n / 2 < n` whenever `n >= 2`, and the only
inputs that reach the recursive call satisfy `n >= 2` (the two
base tests have already filtered out everything below `2` and the
odds). The argument strictly decreases toward the base cases, and
the recursion is at most `log2 n` deep.

Third, the *order* of the tests matters. `1` is odd, so if the
`n mod 2 = 1` test ran first, the function would return `false`
on `1`; and since every successful chain of halvings bottoms out
at `1`, it would then return `false` on every input. When base
cases overlap with a catch-the-rest test, the base cases must
come first.

## Problem 3: fast integer power

The naive `power` we wrote in the recursion lecture takes `n`
recursive calls to compute `x^n`:

```ocaml
let rec power x n =
  if n = 0 then 1
  else x * power x (n - 1)
```

For `n = 1_000_000`, that is a million calls. We can do much
better by *halving* the exponent at each step instead of
decrementing. Two cases on the parity of `n`:

- `n` even: `x^n = (x^(n/2))^2`. One recursive call.
- `n` odd: `x^n = x * x^(n-1)`. One recursive call, but the new
  exponent `n - 1` is even.

```ocaml
let rec fast_power x n =
  if n = 0 then 1
  else if n mod 2 = 0 then
    let half = fast_power x (n / 2) in
    half * half
  else x * fast_power x (n - 1)

let _ = fast_power 2 30  (* = 1073741824 *)
```

:::slide

## Problem 3: fast integer power

```ocaml
let rec fast_power x n =
  if n = 0 then 1
  else if n mod 2 = 0 then
    let half = fast_power x (n / 2) in
    half * half
  else x * fast_power x (n - 1)

let _ = fast_power 2 30  (* = 1073741824 *)
```

- Even `n`: one squaring of `x^(n/2)`.
- Odd `n`: multiply by `x`, then the new exponent is even.
- Calls: about `2 * log2(n)` (`~10` for `n = 30`, vs `30` for naive).

:::

The recursion depth is *logarithmic* in `n`, not linear. For `n = 1_000_000`, the naive `power` makes a million
recursive calls; `fast_power` makes about forty. The transformation
is purely algorithmic: same answer, far fewer calls. The trick
("decompose by parity") is the same one that underlies fast matrix
exponentiation, modular exponentiation in cryptography, and many
related algorithms.

A nuance worth flagging: `fast_power` is *not* tail-recursive. The
even case has `half * half` running *after* the recursive call, and
the odd case has `x *` running after. The accumulator pattern
from the tail-recursion lecture does not unfold cleanly here: the
running result depends
on values you do not know yet. For typical exponents (`n` up to a
few thousand), the logarithmic depth is comfortably small (under
20 frames for `n` up to a million), so non-tail recursion is fine.

## When naive recursion is fine

A pragmatic note: not every recursive function needs to be
tail-recursive. If the input is bounded (you know `n` is at most a
few thousand, or the list has at most a few hundred elements), the
naive recursive form runs in plenty of stack and reads cleaner. The
extra clarity of `let rec sum xs = match xs with | [] -> 0 | x ::
rest -> x + sum rest` over the accumulator form is real, and worth
the constant-factor stack use when stack use is not a problem.

Tail recursion matters when:

- The input might be very large: lists with millions of elements,
  numeric arguments in the millions, recursion that walks deep
  trees.
- The function is called frequently and you want it cheap on any
  input.
- You are writing library code others will call with unknown-sized
  inputs.

For one-off computations on small data, write the natural recursive
form and move on. You can rewrite to tail-recursive later if a
profiler or a stack overflow tells you to.

## Problem 4: counting digits

The number of digits in a non-negative integer is the number of
times you can divide it by 10 before reaching zero. The natural
recursion:

```ocaml
let rec count_digits n =
  if n < 10 then 1
  else 1 + count_digits (n / 10)

let _ = count_digits 12345  (* = 5 *)
```

:::slide

## Problem 4: counting digits

```ocaml
let rec count_digits n =
  if n < 10 then 1
  else 1 + count_digits (n / 10)

let _ = count_digits 12345  (* = 5 *)
```

- Strips one digit at a time; base case is single-digit.
- Each step: `n / 10` shifts right by one place.

:::

:::slide

## `count_digits`: negative inputs misbehave

```ocaml
let _ = count_digits (-12345)  (* = 1, wrong! *)
```

- Wrong: `(-12345)` has five digits, not one.
- `n < 10` is true for *all* negatives.
- The recursion stops at the very first call.

:::

:::slide

## `count_digits`: fix with a wrapper

```ocaml
let count_digits n =
  let rec go n =
    if n < 10 then 1
    else 1 + go (n / 10)
  in
  go (abs n)

let _ = count_digits (-12345)  (* = 5 *)
```

- Outer wrapper strips the sign with `abs`.
- Local `go` only ever sees `n >= 0`; the base case behaves.

:::

The recursion strips one digit per step. The base case
is "a single-digit number" (`n < 10`), which catches both `0`
through `9` and recursive calls when the remaining `n` is below 10.

A subtle bug: negative inputs do not terminate cleanly. OCaml's `/`
truncates toward zero, so `(-12345) / 10` is `-1234` (not `-1235`).
The base test `n < 10` is true for all negatives, so the recursion
returns immediately with `1`, which is wrong. Even worse, with a
different base test like `n = 0`, you would get an infinite
recursion. The defensive version uses `abs`:

```ocaml
let count_digits n =
  let rec go n =
    if n < 10 then 1
    else 1 + go (n / 10)
  in
  go (abs n)
```

This strips the sign at the outermost call; the helper `go` only
ever sees non-negative inputs. The pattern (a defensive outer
function plus a local helper that handles only the well-behaved
case) is one we will see again. The helper is local because nobody
outside `count_digits` needs it; the outer function is the API.

Note that `count_digits 0` returns `1`, which matches the convention
that the integer `0` has one digit (the digit `0`). If you wanted a
different convention you would adjust the base case.

## A quick check

:::quiz mcq id=M03-L06-q2
In `is_power_of_two`, why must the `n = 1` test come *before*
the `n mod 2 = 1` test?

- [ ] It makes the function tail-recursive.
- [x] Otherwise it would classify `1` as even.
- [ ] `n = 1` is cheaper to evaluate than `n mod 2 = 1`.
- [ ] No reason; the two tests can be swapped freely.

**Why:** `1 = 2^0` is a power of two, but `1` is also odd. If
the oddness test ran first, the function would return `false` on
`1`, and since every successful chain of halvings bottoms out at
`1`, it would return `false` on *every* input. When a base case
overlaps with a catch-the-rest test, the base case must be
checked first. Tail-recursion is unaffected by the test order.
:::

:::quiz mcq id=M03-L06-q3
What does `fast_power 2 10` evaluate to?

```ocaml
let rec fast_power x n =
  if n = 0 then 1
  else if n mod 2 = 0 then
    let half = fast_power x (n / 2) in
    half * half
  else x * fast_power x (n - 1)
```

- [ ] `20`
- [ ] `100`
- [x] `1024`
- [ ] `2048`

**Why:** `fast_power 2 10` computes `2^10`. The recursion
halves the exponent on each even step: `2^10 = (2^5)^2`, `2^5
= 2 * 2^4`, `2^4 = (2^2)^2`, `2^2 = (2^1)^2`, `2^1 = 2 * 2^0
= 2`. Folding back up: `2^2 = 4`, `2^4 = 16`, `2^5 = 32`, `2^10
= 32 * 32 = 1024`. About `2 * log2(10)` recursive calls, not
ten.
:::

## Activity: sum of digits

:::slide

## Activity

Write `sum_digits : int -> int` that returns the sum of the
base-10 digits of a non-negative integer. Examples:

- `sum_digits 0 = 0`.
- `sum_digits 9 = 9`.
- `sum_digits 12345 = 15`.

Same shape as `count_digits` above, with the per-step contribution
changed.

:::

Try this before reading the solution. The shape mirrors
`count_digits`: strip one digit per step. The base case is `n =
0`: an empty number has digit sum `0`. The recursive case takes
the last digit (`n mod 10`) and adds it to the digit sum of the
rest (`n / 10`).

:::solution

:::slide

## Activity solution

```ocaml
let rec sum_digits n =
  if n = 0 then 0
  else (n mod 10) + sum_digits (n / 10)

let _ = sum_digits 12345  (* = 15 *)
```

- Base case `n = 0`: empty number, digit sum `0`.
- Recursive case: last digit + digit sum of the rest.
- Same shape as `count_digits`; different per-step contribution.

:::

:::

The recursion uses two integer operations students have already
seen: `n mod 10` peels off the last digit, `n / 10` shifts the
number one place right. After enough steps `n` reaches `0` and the
recursion ends. As with `count_digits`, the function misbehaves on
negative inputs because of OCaml's truncate-toward-zero division;
wrap with `abs` if you want the convention `sum_digits (-12) =
3`.

## A small code challenge

:::quiz code id=M03-L06-q1
Write `is_prime : int -> bool` by trial division. Returns `true`
if `n` is prime, `false` otherwise. Edge cases: `is_prime 0` and
`is_prime 1` are `false`; `is_prime 2` is `true`. Use a *local*
helper that tries divisors `k = 2, 3, 4, ...` and stops at
`k * k > n` (no need to look past the square root).

```ocaml
let is_prime n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (is_prime 0   = false) "0";
  check (is_prime 1   = false) "1";
  check (is_prime 2   = true)  "2";
  check (is_prime 9   = false) "9 = 3*3";
  check (is_prime 17  = true)  "17";
  check (is_prime 100 = false) "100 = 4*25";
  check (is_prime 101 = true)  "101";
  print_endline "all tests passed"
```
:::

:::solution

Outer function handles the `n < 2` edge case and calls a local
`try_divisor` helper that walks `k = 2, 3, 4, ...` upward,
returning `true` if no divisor was found by the time `k * k > n`:

```text
let is_prime n =
  if n < 2 then false
  else
    let rec try_divisor k =
      if k * k > n then true
      else if n mod k = 0 then false
      else try_divisor (k + 1)
    in
    try_divisor 2
```

`try_divisor` is tail-recursive (the recursive call is the final
expression of its branch). The outer wrapper hides the helper from
callers; the API is just `is_prime : int -> bool`. The
square-root cap halves the work compared to trying all `k < n`.

:::

## What you should be able to do now

:::slide

## What you should be able to do now

After Module 3 you can:

- Define functions, including anonymous functions with `fun`.
- Use partial application (`add 5`).
- Write recursive functions with base and recursive cases.
- Convert to tail-recursive with an accumulator.
- Use local helpers and mutual recursion.

Module 4: **data types** (tuples, records, variants, recursive).

:::

By the end of Module 3 you can:

- Define a function with `let`, anonymous-function form `fun x ->
  ...`, or the curried multi-argument form `let f x y z = ...`.
- Read function types: `int -> int -> int` is right-associative,
  meaning `int -> (int -> int)`. A multi-argument function is
  really a function of one argument returning a function.
- Partially apply a curried function: `add 5` is a function value.
- Write recursive functions with `let rec`, in their natural
  inductive form (base case plus recursive case that reduces
  toward it).
- Convert a non-tail-recursive function to tail-recursive using an
  accumulator parameter.
- Use local helpers via `let rec go ... in ...` and write mutually
  recursive functions with `let rec ... and ... = ...`.

[Module 4](M04-L01-tuples.html) turns to *data types*: tuples,
records, and variants (the algebraic data types that distinguish
ML-family languages from mainstream OOP). Pattern matching, which
we have previewed all through Module 3, takes centre stage in
[Module 5](M05-L01-basic-patterns.html).

## Reading

- **Cornell CS3110**, *Recursion examples*: the textbook's worked
  examples, with more variations on the patterns above:
  <https://cs3110.github.io/textbook/chapters/basics/functions.html>
- **Real World OCaml**, *Lists and Patterns*: the corresponding
  chapter, with a heavy emphasis on the list-recursion idioms:
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
