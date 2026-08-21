---
title: "Local functions and mutual recursion"
lecture_no: 5
week: 3
duration_target_min: 22
concepts: [local let-bindings of functions, helper functions, mutual recursion, `and` keyword]
keywords: [OCaml, local functions, mutual recursion, and, helper, let rec ... and]
activity_question: "Define [mod3_eq_0], [mod3_eq_1], [mod3_eq_2 : int -> bool] for non-negative [n], using mutual recursion with three functions tied by [and]. The only arithmetic allowed is subtracting 1 and comparing to 0. Why does this need three functions in the same [let rec ... and ... and ...] declaration?"
think_about_this: "When is a helper function better as a local [let ... in] inside another function vs. a top-level definition? What changes when you make it top-level?"
reading:
  - title: "Cornell CS3110, Helper functions"
    url: https://cs3110.github.io/textbook/chapters/basics/functions.html
---

# Local functions and mutual recursion


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Local functions and mutual recursion</h2>
<p class="title-slide-label">Module 3 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: local helpers and mutual recursion

- Two related topics, both ordinary features of day-to-day OCaml.
- *Local* function definitions: helpers inside another function with `let ... in`.
  - Scoped only to the outer function; keeps the top level clean.
- *Mutual recursion*: two or more functions that call each other.
  - Glued with the `and` keyword; one `let rec ... and ... and ...`.
- Neither topic is conceptually deep.
- The point is the *conventions*: when local vs. top-level, and what `and` is for.

:::

Two related topics in this lecture. The first is *local* function
definitions: helpers defined inside another function with
`let ... in`, scoped only to that outer function. The second is
*mutual recursion*: two or more functions that call each other,
glued together with the `and` keyword. Both are ordinary features
of day-to-day OCaml; you have already seen the first in passing
(every tail-recursive function in
[the tail-recursion lecture](M03-L04-tail-recursion.html#the-accumulator-pattern)
used a local helper), and the second turns up the moment you
write a parser, a tree walker, or the classic `is_even` /
`is_odd` example.

Neither topic is conceptually deep. The point of the lecture is to
give you the conventions: when to make a helper local vs.
top-level, and what the `and` keyword does and why it has to exist.

## Local helpers: definitions inside `let ... in`

We saw `let rec go ... in ...` in every tail-recursive rewrite in
[the tail-recursion lecture](M03-L04-tail-recursion.html#the-accumulator-pattern).
The keyword combination defines `go` only inside the body of the
outer function:

```ocaml
let factorial n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc * n) (n - 1)
  in
  go 1 n
```

The shape: an outer function `factorial` with the API you want
callers to see, an inner helper `go` doing the real work, and a
call `go 1 n` to start the recursion. The name `go` is *not* visible
outside `factorial`; you cannot call `go 1 5` from somewhere else
in the file.

:::slide

## Local helpers with `let ... in`

You've already seen this in tail-recursive rewrites:

```ocaml
let factorial n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc * n) (n - 1)
  in
  go 1 n
```

- `go` defined *inside* `factorial` with `let rec ... in`.
- In scope only for the rest of that expression.
- Right place for an implementation-detail helper.

:::

The encapsulation matters more than it might first appear. Once a
name is part of a file's top-level scope, anyone reading the file
sees it. It autocompletes. It shows up in error messages. It might
get exported in an `.mli` (interface file), to be discussed in
[Module 7](M07-L07-signatures.html). If the helper is genuinely an
implementation detail of one function, all of that is noise. Local
definitions keep the top-level surface clean.

The local helper pattern is core to readable OCaml. Any time you
have a function that needs an accumulator, or a different argument
order from what the caller expects, define the helper locally and
shape the outer function to be the API you want callers to see.
The caller sees `factorial : int -> int`; they never have to know
about `go` or about the starting accumulator `1`.

## Why not just top-level?

You can, of course, write the same thing with a top-level helper:

```ocaml
let rec factorial_go acc n =
  if n = 0 then acc
  else factorial_go (acc * n) (n - 1)

let factorial n = factorial_go 1 n
```

It works. The factorial function behaves exactly the same. But the
helper `factorial_go` is now a public name. Anyone reading the file
or using IDE autocomplete will see it. They might call
`factorial_go 0 5` and get `0` (because the accumulator starts at
zero, and `0 * anything` is zero). That is a wrong answer the
`factorial` API would have prevented.

:::slide

## Why not just top-level?

```ocaml
let rec factorial_go acc n =
  if n = 0 then acc
  else factorial_go (acc * n) (n - 1)

let factorial n = factorial_go 1 n
```

- This works.
- Downside: `factorial_go` is a public name.
- Callers could pass `factorial_go 0 5` and silently get `0`.
- A local `let rec ... in` hides the helper.
- Encapsulation: the default choice.

:::

This is the same argument as for `private` methods in object-oriented
languages, or `static` functions in C: by default, hide
implementation details. Expose only the API. In OCaml the
hiding-mechanism for functions inside another function is `let ...
in`; the hiding-mechanism for functions inside a module is the
[`.mli` file](M07-L07-signatures.html#signatures-in-mli-files).
Both exist for the same reason: smaller surface, fewer ways for
callers to misuse the code.

## When to make a helper top-level

The other end of the trade-off: sometimes the "helper" is genuinely
useful on its own. The classic pair is `gcd` and `lcm`: the
greatest common divisor stands on its own (number theory uses it
constantly), and the least common multiple is defined in terms of
it. You do not want `gcd` hidden inside `lcm`; you want it
top-level so anyone can reuse it.

```ocaml
let rec gcd m n =
  if n = 0 then m
  else gcd n (m mod n)

let lcm m n =
  m * n / gcd m n
```

:::slide

## When to make a helper top-level

Sometimes the "helper" is useful on its own:

```ocaml
let rec gcd m n =
  if n = 0 then m
  else gcd n (m mod n)

let lcm m n =
  m * n / gcd m n
```

- `gcd` stands on its own; `lcm` reuses it.
- Both top-level, both public.

Rule of thumb:

- Reusable name other callers might want: top-level.
- Tactical helper for one function: local.

:::

The rule of thumb:

- *Top-level* if the helper has a meaningful, reusable name that
  other callers might want. `gcd`, `factorial`, `power`. The
  function stands on its own.
- *Local* if the helper is a tactical aid for one outer function:
  an accumulator-passing version, an unfolded base case, a
  renamed-and-reordered variant. `go`, `aux`, `loop`. Nobody
  outside the outer function would want to call it.

You will get a feel for this with practice. The bias in idiomatic
OCaml is toward locals: if in doubt, hide it. You can always promote
a local helper to top-level if a second caller materialises. Going
the other way (making a top-level function local) is harder, because
you do not know who is already using it.

## A code check: hide the helper

:::quiz code id=M03-L05-q1
Write `bit_count : int -> int` that returns the number of `1`s
in the binary representation of a non-negative integer. Use a
**local** tail-recursive helper inside `bit_count`; the helper
must not be visible at the top level.

```ocaml
let bit_count n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (bit_count 0   = 0) "zero";
  check (bit_count 1   = 1) "one";
  check (bit_count 2   = 1) "two (binary 10)";
  check (bit_count 3   = 2) "three (binary 11)";
  check (bit_count 7   = 3) "seven (binary 111)";
  check (bit_count 10  = 2) "ten (binary 1010)";
  check (bit_count 255 = 8) "255 (binary 11111111)";
  print_endline "all tests passed"
```
:::

:::solution

`n mod 2` is the lowest bit; `n / 2` drops it. A local
tail-recursive helper threads the running count:

```text
let bit_count n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc + (n mod 2)) (n / 2)
  in
  go 0 n
```

`go` is the standard local-helper-with-accumulator shape we saw
in [Tail recursion](M03-L04-tail-recursion.html). Hiding it
inside `bit_count` keeps the accumulator out of the top-level
namespace.

:::

## Mutual recursion: two functions calling each other

Sometimes the natural shape of a problem is not "one function calls
itself" but "two functions call each other." The classic, slightly
contrived example is parity by recursion:

```ocaml
let rec is_even n =
  if n = 0 then true
  else is_odd (n - 1)
and is_odd n =
  if n = 0 then false
  else is_even (n - 1)
```

`is_even 10` is `true`. `is_odd 10` is `false`. Each function calls
the other, not itself: `is_even`'s recursive case calls `is_odd`,
and vice versa. The recursion alternates between the two functions
until one of them hits the base case.

:::slide

## Mutual recursion

Two functions can call each other:

```ocaml
let rec is_even n =
  if n = 0 then true
  else is_odd (n - 1)
and is_odd n =
  if n = 0 then false
  else is_even (n - 1)

let _ = is_even 10  (* = true *)
let _ = is_odd 10   (* = false *)
```

- Each function calls the other.
- Tied together by `and`.
- Both names in scope simultaneously inside both bodies.

:::

The new piece of syntax is the `and` keyword joining the two
definitions. The combined declaration is one big `let rec`:
`let rec is_even ... and is_odd ...`. Both names are introduced
together, and both names are in scope inside *both* bodies. That is
exactly what mutual recursion needs.

## Why `and` has to exist

Suppose you tried to write the two functions as separate `let rec`s:

```text
let rec is_even n = if n = 0 then true  else is_odd  (n - 1)
let rec is_odd  n = if n = 0 then false else is_even (n - 1)
```

OCaml rejects the first line: `Unbound value is_odd`. The reason
is the same one we saw for `let rec` vs. plain `let` in
[the recursion lecture](M03-L02-recursion.html#why-let-rec-and-not-just-let):
a `let rec` brings the name being defined into scope inside its
own body, but not *other* names that have not been defined yet.
When the compiler processes the first `let rec is_even`, the name
`is_odd` does not exist yet, so the reference to `is_odd` in
`is_even`'s body fails.

:::slide

## Why `and`, not `let` twice?

```text
let rec is_even n = if n = 0 then true  else is_odd  (n - 1)
let rec is_odd  n = if n = 0 then false else is_even (n - 1)
```

- OCaml rejects the first line: `Unbound value is_odd`.
- When `let rec is_even` is processed, `is_odd` doesn't exist yet.
- `and` threads multiple definitions through one name-resolution step:

```text
let rec X = ... and Y = ... and Z = ...
```

- All names in scope inside each body.

:::

The `and` keyword joins multiple recursive definitions into a single
declaration. All the names introduced by the joined declaration are
visible inside *all* the bodies. There is no limit to how many
functions can be joined: `let rec f = ... and g = ... and h = ...
and ...`. Two is by far the most common; three or four show up in
parsers and tree walkers; more than that is unusual.

A subtle property worth noting: `and` does *not* mean "evaluate
sequentially." All the bodies are processed by the type checker
together, with all the names already in scope. There is no left-to-right
dependency. You can write the definitions in any order; the
compiler will figure out which calls which.

The two-function ping-pong is not as artificial as `is_even` /
`is_odd` suggests. The shape shows up the moment you write a
recursive-descent parser (each grammar rule is a function, the
rules call each other), a tree walker over a language with
expressions *and* statements (`eval_expr` calls `eval_stmt` and
vice versa), or any state machine with two or more states. We
will see those examples in
[Module 4](M04-L04-recursive-types.html) (recursive data types)
and [Module 5](M05-L01-basic-patterns.html) (pattern matching),
once we have the data shapes to support them.

## Mutual recursion can be local too

Just as a single recursive function can be local with `let rec ... in`,
a set of mutually recursive functions can be local with
`let rec ... and ... in`:

```ocaml
let demo () =
  let rec ping n =
    if n = 0 then "done"
    else pong (n - 1)
  and pong n = ping n
  in
  ping 5

let _ = demo ()  (* = "done" *)
```

:::slide

## Mutual recursion can also be local

```ocaml
let demo () =
  let rec ping n =
    if n = 0 then "done"
    else pong (n - 1)
  and pong n = ping n
  in
  ping 5

let _ = demo ()  (* = "done" *)
```

- `let rec ... and ...` works inside `let ... in` too.
- Both names local; neither leaks outside `demo`.

:::

The syntax is exactly the same: `let rec X = ... and Y = ... in
body`. Both `X` and `Y` are local to the surrounding expression.
Outside `demo ()`, neither `ping` nor `pong` exists.

For a single (not mutual) local recursive helper, the same `let
rec ... in` shape works without `and`. The Collatz sequence is a
classic small example: take a positive integer; halve it if even,
triple-and-add-one if odd; stop at 1. The conjecture is that the
sequence reaches 1 for every positive starting value. Unproven,
but a tidy demonstration of `let rec ... in`:

```ocaml
let collatz n =
  let rec step n =
    print_endline (string_of_int n);
    if n = 1 then ()
    else if n mod 2 = 0 then step (n / 2)
    else step (3 * n + 1)
  in
  step n
```

## A quick check

:::quiz mcq id=M03-L05-q2
What happens when the toplevel reaches the last line?

```ocaml skip
let outer x =
  let inner y = y + 1 in
  inner x

let _ = outer 4
let _ = inner 5
```

- [ ] Both lines return `5`.
- [ ] `outer 4` returns `5`; `inner 5` returns `6`.
- [x] `outer 4` returns `5`; `inner` is out of scope.
- [ ] Both expressions evaluate to `5` because `inner` is global.

**Why:** `inner` is introduced by a `let ... in` *inside*
`outer`'s body, so it is in scope only inside that body. Outside
`outer`, the name `inner` has never been bound, and the compiler
rejects the reference. Hiding a helper inside a top-level
function is exactly the point of the local-helper pattern.
:::

:::quiz mcq id=M03-L05-q3
The compiler rejects this code. Where, and why?

```ocaml skip
let rec is_even n =
  if n = 0 then true  else is_odd  (n - 1)
let rec is_odd n =
  if n = 0 then false else is_even (n - 1)
```

- [ ] At `is_odd`'s definition: the body refers to `is_even`, which has type `int -> bool`; the recursive case is fine.
- [x] At `is_even`'s definition: the body refers to `is_odd`, which is not yet in scope.
- [ ] At the call site: `is_even` and `is_odd` have different types.
- [ ] The code is accepted; both functions work.

**Why:** `let rec` brings *only the name being defined* into
scope inside its own body. When the compiler processes the first
`let rec is_even`, `is_odd` has not yet been introduced, so the
recursive case fails with `Unbound value is_odd`. The fix is one
combined `let rec ... and ...` so both names are introduced
together and in scope inside both bodies.
:::


## Activity: mod-3 by three-way mutual recursion

:::slide

## Activity

`and` is not limited to two definitions. Define `mod3_eq_0`,
`mod3_eq_1`, `mod3_eq_2 : int -> bool` for non-negative `n`,
using **only** "subtract 1, compare to 0" (no `mod`, no `if`-on-
arithmetic). The three functions must call each other:

```text
let rec mod3_eq_0 n = ???
and mod3_eq_1 n = ???
and mod3_eq_2 n = ???
```

:::

Try it before reading the solution. Each function's base case is
fixed by definition (`mod3_eq_0 0` is `true`; the other two are
`false` on `0`). The recursive case has to hand off in a cycle:
subtracting 1 from `n` shifts the residue by 1, so
`mod3_eq_0 n = mod3_eq_2 (n - 1)`, `mod3_eq_1 n = mod3_eq_0 (n -
1)`, `mod3_eq_2 n = mod3_eq_1 (n - 1)`. Three functions, three
bases, three tail calls in a cycle.

:::solution

:::slide

## Activity solution

```ocaml
let rec mod3_eq_0 n =
  if n = 0 then true
  else mod3_eq_2 (n - 1)
and mod3_eq_1 n =
  if n = 0 then false
  else mod3_eq_0 (n - 1)
and mod3_eq_2 n =
  if n = 0 then false
  else mod3_eq_1 (n - 1)

let _ = mod3_eq_0 9   (* = true:  9 mod 3 = 0 *)
let _ = mod3_eq_1 10  (* = true: 10 mod 3 = 1 *)
let _ = mod3_eq_2 11  (* = true: 11 mod 3 = 2 *)
```

- Three bodies, all in scope inside all bodies.
- Recursive calls hand off in a cycle: 0 to 2, 2 to 1, 1 to 0.
- All three calls are in tail position; TCO works across all of them.

:::

:::

To watch the hand-off happen, shadow the three definitions with
instrumented copies (a print at the top of each body) and run one
on a small argument:

```ocaml
let rec mod3_eq_0 n =
  print_endline ("mod3_eq_0 " ^ string_of_int n);
  if n = 0 then true else mod3_eq_2 (n - 1)
and mod3_eq_1 n =
  print_endline ("mod3_eq_1 " ^ string_of_int n);
  if n = 0 then false else mod3_eq_0 (n - 1)
and mod3_eq_2 n =
  print_endline ("mod3_eq_2 " ^ string_of_int n);
  if n = 0 then false else mod3_eq_1 (n - 1)

let _ = mod3_eq_0 4  (* = false: 4 mod 3 = 1 *)
```

The printed lines are the call sequence: `mod3_eq_0 4`,
`mod3_eq_2 3`, `mod3_eq_1 2`, `mod3_eq_0 1`, `mod3_eq_2 0`. Each
line is one hand-off around the 0 to 2 to 1 cycle, one subtraction
per step, until a base case answers.

One important property of this example: every recursive call is
in tail position. OCaml's tail-call optimisation handles tail
calls *between* mutually recursive functions, not just self-calls.
So `mod3_eq_0 1_000_000` runs in constant stack space. The function
cycles through three frames as it descends, but none of them ever
stays around; each recursive tail call reuses the current frame for
the next call.

In real code you would write `n mod 3 = 0`, of course. The
mutual-recursion version is here as a clean illustration of the
pattern: a cycle of bodies tied together by `and`, every name in
scope inside every body.

## What's next

:::slide

## What's next

Lecture 6: the **tutorial** for Module 3.

- Work through `fib`, a power-of-two test, fast `power`, and
  digit counting.
- Trade-offs: naive vs tail recursion.

:::

The next lecture, [M03-L06](M03-L06-tutorial.html), is the
tutorial for Module 3. We will work through several classic small
problems: Fibonacci (naive and linear-time), testing whether a
number is a power of two, fast integer power by
square-and-multiply, and digit counting. The
goal is to consolidate the techniques (recursion, accumulators,
local helpers) on problems you have probably seen in some form
before, and to discuss when each approach is the right choice.

## Reading

- **Cornell CS3110**, *Helper functions* and *Mutual recursion*:
  <https://cs3110.github.io/textbook/chapters/basics/functions.html>
  
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
