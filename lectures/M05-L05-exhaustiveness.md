---
title: "Exhaustiveness checking"
lecture_no: 5
week: 5
duration_target_min: 22
concepts: [exhaustiveness, partial match, redundant clauses, refactor with the compiler]
keywords: [OCaml, exhaustiveness, pattern matching, warning 8, warning 11]
activity_question: "What does the compiler do when you add a new constructor to a variant type that is matched in 12 places? Why is that the strongest argument for using variants instead of strings or ints to encode kinds?"
think_about_this: "Exhaustiveness checking is a *warning*, not an error, by default. Why? Should it be an error in your projects? What's the practical trade-off?"
reading:
  - title: "Cornell CS3110, Exhaustiveness"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
---

# Exhaustiveness checking


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Exhaustiveness checking</h2>
<p class="title-slide-label">Module 5 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Of all the static checks the OCaml compiler performs, the one
you will come to value most is *exhaustiveness*. The compiler
looks at every `match` you write and asks: "do these clauses
cover every possible value of the matched type?" If the answer
is no, it warns you, and it tells you which case you missed. If
the answer is yes, it stays quiet.

This sounds like a small convenience. It is in fact the most
important property your type system can give you, and it is the
single biggest reason to prefer [variants](M04-L03-variants.html)
over ad-hoc encodings (strings, integers, "magic numbers") for
finite kinds. Once you have used it in anger on a real codebase
(adding a new constructor to a variant and watching the compiler
enumerate every place that needs updating), you will not want to
write production code without it.

This lecture covers what exhaustiveness checking is, how to read
the warnings, the dual check for redundant clauses, and the
practical advice on turning warnings into errors for serious
projects.

:::slide

## This lecture: exhaustiveness

- *Exhaustiveness*: do my clauses cover every value of the type?
- The compiler answers, every time. If not, it names the missing case.
- The single biggest reason to prefer variants over strings or
  magic numbers for finite kinds.
- Add a constructor: the compiler enumerates every place that
  needs updating.
- Today: reading the warnings, redundant-clause check, turning
  warnings into errors for serious projects.

:::

## A non-exhaustive match

Take the traffic-light example from
[the variants lecture](M04-L03-variants.html#declaring-a-variant-the-enum-case):

```ocaml
type traffic_light = Red | Yellow | Green

let action = function
  | Red -> "stop"
  | Green -> "go"
```
```mdx-error
Lines 3-5, characters 16-20:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  Here is an example of a case that is not matched: Yellow
```

We forgot `Yellow`. The compiler tells us:

```
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched: Yellow
```

:::slide

## A non-exhaustive match

```ocaml
type traffic_light = Red | Yellow | Green

let action = function
  | Red -> "stop"
  | Green -> "go"
```
```mdx-error
Lines 3-5, characters 16-20:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  Here is an example of a case that is not matched: Yellow
```

OCaml warns:

```
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched: Yellow
```

- Compiler tells you **which** case is missing, by example.
- Fix: add a clause or a wildcard.

:::

The warning is friendly: it does not just say "this is
incomplete." It tells you *which value* breaks the match. For a
small variant, this is the missing constructor by name. For a
larger type, the compiler synthesises a sample value that no
clause covers, showing you the shape of the gap.

The fix is straightforward: add the missing clause.

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | Green -> "go"
```

Warning gone. The match now handles every possible
`traffic_light`. Crucially, the compiler has *proved* that this
function is total: it will never raise `Match_failure` at
runtime, no matter what value of `traffic_light` you pass it.

## How the check works

The exhaustiveness checker takes the type of the matched value
and computes the set of *value shapes* that type admits. For a
variant, that is the set of constructors (with their payload
patterns). For a tuple, the cross product of each component's
shapes. For a record, the set of all field combinations.

It then takes your clauses and subtracts the shapes they cover.
If the remainder is non-empty, the match is non-exhaustive, and
the compiler reports a witness from the remainder.

This is a *purely structural* check. It does not reason about
arithmetic, strings, or arbitrary computation. So on `int`, the
compiler treats every literal pattern as covering one specific
value and warns unless you have a wildcard or a variable pattern
that catches everything else. On `string`, the same: literals
cover only themselves; you need a catch-all.

```ocaml
let small = function
  | 0 -> "zero"
  | 1 -> "one"
  | 2 -> "two"
```
```mdx-error
Lines 1-4, characters 13-17:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  Here is an example of a case that is not matched: 3
```

Warns: there are infinitely many integers, and you have covered
exactly three. The fix is `| _ -> "many"`, exactly as we did in
[Lecture 1](M05-L01-basic-patterns.html#the-catch-all-wildcard).

## Why this matters

In most mainstream languages, a "switch on a kind" can silently
fall through when you add a new kind:

:::slide

## Why this matters

- The compiler **proves** no `traffic_light` falls through at runtime.
- Without exhaustiveness checking, missing case becomes a runtime crash:
  - **C** (switch + enum): missing case falls through; depends on what's next.
  - **Java** (switch): same, unless a separate linter (Error Prone) is enabled.
  - **Python**: no static checking; runtime `KeyError`/`AttributeError`.
- OCaml flags the problem **before** the program runs.

:::

In C, a `switch` on an `enum` that misses a case compiles fine
and executes whatever code follows the missing case (or nothing,
if there is no `default`). In Java, the same; modern linters
like Error Prone can catch this, but it is not built into the
compiler. In Python, there is no static check at all; a missing
case becomes a runtime `KeyError`, `AttributeError`, or
silently wrong output.

OCaml builds the check into the compiler. It is the *default*
behaviour; you do not opt in, you opt out (if you must, with a
catch-all wildcard). This single feature shifts a whole class of
bugs (the "forgot a case" bug) from runtime to compile time.

The stakes are not hypothetical. On 15 January 1990, a software
update containing one misplaced `break` inside a C `switch`
brought down AT&T's long-distance network: a single switching
centre's recovery message crashed its neighbours, which crashed
*their* neighbours, and for about nine hours half of the
long-distance calls in the United States (tens of millions of
them) could not connect. The
[post-mortem](https://users.csc.calpoly.edu/~jdalbey/SWE/Papers/att_collapse.html)
became a standard case study because the faulty branch structure
compiled cleanly and had passed testing.

The compiler's twin warning, for *unreachable* cases, has its
own famous incident. In February 2014 Apple shipped the
`goto fail` bug
([CVE-2014-1266](https://nvd.nist.gov/vuln/detail/CVE-2014-1266)):
a duplicated `goto fail;` line in the TLS code made the final
certificate-verification step unreachable, so for well over a
year a network attacker could impersonate any secure server to
any Apple device. C compiled the dead code without a murmur.
OCaml flags a match case that can never be reached (warning 11)
the moment you write it; the same class of mistake announces
itself at compile time.

## The big payoff: refactoring with the compiler

The reason exhaustiveness pays for itself many times over is
*refactoring*. Suppose you have a variant in a real codebase:

```ocaml
type traffic_light = Red | Yellow | Green
```

and twelve different functions that pattern-match on it. Now a
new requirement comes in: add a fourth state, `FlashingRed`.

```ocaml
type traffic_light = Red | Yellow | Green | FlashingRed
```

What happens? Every single `match` on `traffic_light` that did
not have a wildcard now emits warning 8. The compiler prints,
for each one, the location and the missing case. Your job is to
visit every flagged site and decide what to do for `FlashingRed`.

:::slide

## Refactor with the compiler

```ocaml
type traffic_light = Red | Yellow | Green | FlashingRed
```

- Every `match` on `traffic_light` warns about the new case.
- Compiler prints a punch-list: file + line for each match.
- Refactoring goes from "grep and pray" to "compile and fix the warnings".

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | Green -> "go"
  | FlashingRed -> "stop, then proceed with caution"
```

:::

This is what "refactor with the compiler" means. In a
dynamically-typed language, you have to *find* every site that
might need updating. You grep for `traffic_light`. You hope
nothing dynamic constructs the value (e.g., from a string).
You write more tests. You ship and find out at 2am that you
missed a branch.

In OCaml with variants and pattern matching, the compiler does
the finding for you. Adding a new constructor is mechanical:
introduce it in the type, then walk through the compiler's
punch list, fixing each warned site. When the warnings are gone,
you have changed every place that needed changing.

This is the property that *justifies* using variants for finite
kinds, even when a string or an integer would feel easier. With
strings (`light = "red"`, `light = "yellow"`), the compiler has no
idea what set of strings is valid; adding a new value to that
set is invisible to the type checker. With a variant, every
match is automatically a coverage check.

Once you internalise this, you will start to look at any code
that branches on a string and ask: *should this be a variant?*
The answer is almost always yes.

## The wildcard tax: `_` forfeits the punch list

There is one way to lose this benefit by accident: a `_`
catch-all on a variant. The catch-all tells the compiler "I have
covered everything," so the match is exhaustive *as written*,
and the compiler stops checking. Adding a new constructor is
then silent at this site: the new value flows into whatever the
`_` clause returns.

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | _ -> "go"

let _ = action FlashingRed  (* = "go", silently! *)
```

`action FlashingRed` returns `"go"`. No warning. No error. The
program ships, and the bug is found in production: a flashing
red light is treated like green.

:::slide

## Caveat: `_` forfeits the punch list

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | _ -> "go"

let _ = action FlashingRed  (* = "go", silently! *)
```

- `_` makes the match exhaustive *as written*; compiler stops checking.
- Adding `FlashingRed` triggers **no warning** at this site.
- `action FlashingRed` returns `"go"`, almost certainly wrong.
- **Prefer to avoid `_` on a variant** so the compiler keeps helping.

:::

This is the price of a wildcard on a variant. We come back to
this rule, with the recommended alternatives, in
[the wildcard discussion below](#prefer-to-avoid-catch-all-on-variants).

## The dual: redundant clauses

Exhaustiveness has a sibling check: **redundancy**. The
exhaustiveness check (warning 8) finds clauses that *should*
exist but don't: a value of the matched type could arrive that
no clause covers. The redundancy check (warning 11) finds
clauses that *do* exist but will never fire: an earlier clause
already covers every value the later one would. The two
warnings are different in direction (missing vs unreachable)
but related in spirit: both compare the set of values a type
admits against the set the clauses cover.

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | Green -> "go"
  | FlashingRed -> "stop, then proceed with caution"
  | Red -> "redundant"

let _ = action Red  (* = "stop" *)
```
```mdx-error
Line 6, characters 7-10:
Warning 11 [redundant-case]: this match case is unused.
```

:::slide

## Redundant clauses (warning 11)

```ocaml
let action = function
  | Red -> "stop"
  | Yellow -> "slow down"
  | Green -> "go"
  | FlashingRed -> "stop, then proceed with caution"
  | Red -> "redundant"
```
```mdx-error
Line 6, characters 7-10:
Warning 11 [redundant-case]: this match case is unused.
```

- Second `Red` is **dead**.
- Same warning as the "variable-before-literal" case from Lecture 1.

:::

Warning 11 fires when a clause is *shadowed* by an earlier one.
The duplicate `Red` clause can never run, because the first
`Red` clause matches every red light. We saw the same warning
in [Lecture 1](M05-L01-basic-patterns.html#why-pattern-order-matters)
when a variable pattern appeared before a literal:

```ocaml
let label = function
  | n -> "got " ^ string_of_int n
  | 0 -> "zero"
```
```mdx-error
Line 3, characters 7-8:
Warning 11 [redundant-case]: this match case is unused.
```

Again, the variable `n` matches everything, so the literal `0`
is dead. Warning 11 tells you so, and the fix is to swap them.

The two warnings (8 for missing, 11 for redundant) together give
the compiler complete coverage of your match: every gap is
flagged, and every dead branch is flagged.

## Exhaustiveness on combined shapes

The checker handles nested patterns too. Take a pair of booleans:

```ocaml
let category = function
  | (true, true)  -> "both"
  | (true, false) -> "only first"
  | (false, true) -> "only second"

let _ = category (false, false)  (* raises Match_failure *)
```
```mdx-error
Lines 1-4, characters 16-37:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  Here is an example of a case that is not matched: (false, false)

Exception: Match_failure ("//toplevel//", 1, 16).
```

:::slide

## Exhaustiveness on nested patterns

```ocaml
let category = function
  | (true, true)  -> "both"
  | (true, false) -> "only first"
  | (false, true) -> "only second"
```
```mdx-error
Lines 1-4, characters 16-37:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  Here is an example of a case that is not matched: (false, false)
```

```
Warning 8: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched: (false, false)
```

- Compiler enumerates **all combinations** of nested shapes.
- Sees the gap and reports it.
- Fix: add `(false, false) -> "neither"`, or a wildcard.

:::

The compiler enumerated the 2x2 grid of boolean pairs, subtracted
the three covered combinations, and produced `(false, false)` as
the missing one. Same idea applies to a tuple of variants, a
record of variants, or a tree of constructors.

This is also how you can see that the check is *not* about types
alone but about *constructors*. The boolean type has two
constructors (`true`, `false`); a pair of booleans has four
constructor combinations; the check enumerates them.

The same principle applied to a tuple of two `traffic_light`s
would enumerate `3 * 3 = 9` combinations.

## Exhaustiveness and guards: one more reminder

We saw in [Lecture 4](M05-L04-guards.html#exhaustiveness-with-guards-is-conservative)
that guards suppress exhaustiveness. The
compiler treats a guarded clause as "may fail," so the cases
covered by a guarded pattern are not considered part of the
total. The fix is to add an unguarded catch-all:

```ocaml
let classify = function
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"
```

Without the wildcard, the compiler warns. Even though the two
guards logically partition the integers between them, the
compiler cannot prove that, and so it warns.

The lesson: when you write a guarded clause, *always* finish the
match with at least one unguarded clause, even if it seems
redundant to you.

## Why is it a warning, not an error?

You may have noticed that warning 8 is a *warning*, not an
*error*: the code still compiles and runs. This is a deliberate
choice in OCaml's defaults, and reasonable people disagree about
it.

The argument for a warning:

- During exploration and prototyping, the programmer often
  knows the input will be limited and a complete match is
  overkill.
- Sometimes the missing case is "impossible by invariant" and
  the programmer prefers a runtime `Match_failure` to
  cluttering the code with `assert false`.
- OCaml's defaults favour quick iteration; warnings let you
  proceed.

The argument against:

- A `Match_failure` at runtime is a worse user experience than a
  compile error.
- In production code, the cost of one missed case at runtime
  greatly exceeds the cost of writing the catch-all clause.
- The whole point of exhaustiveness is to shift the bug to
  compile time; tolerating it at compile time defeats the
  purpose.

In practice, every serious OCaml project I have worked on
treats warning 8 as an error. The default dune toolchain makes
this easy.

:::slide

## Treating warnings as errors

In real projects, treat partial-match warnings as errors:

```
(executable
 (name foo)
 (flags (:standard -w +a-3-49 -warn-error +a)))
```

- Or workspace-wide:
  ```
  (env (_ (flags (:standard -w +a-3-49 -warn-error +a))))
  ```
- `-w +a` *enables* all warnings; `-3-49` switches off a few benign ones.
- `-warn-error +a` is what *promotes* the enabled warnings to errors.
- [Module 7](M07-L06-module-basics.html) covers modules; dune is the build tool you use to wire them together.

:::

The flag `-w +a` *enables* every warning, and the suffix `-3-49`
disables warnings 3 and 49 (about deprecated features and missing
`cmi` files in some cases), which most projects find acceptable to
ignore. Enabling a warning does not stop the build by itself; the
separate flag `-warn-error +a` is what promotes the enabled
warnings to errors. (A shorthand exists: `-w @a-3-49` both enables
and errors in one flag.) Warning 8 (exhaustiveness) and warning 11
(redundancy) are *not* among the disabled ones, so they become
errors.

If you write OCaml seriously, set this in your dune files from
day one. The few minutes you spend appeasing the compiler in
each function will save you hours of debugging in production.

## Prefer to avoid catch-all on variants

We saw above that a `_` on a variant
[silently swallows new constructors](#the-wildcard-tax-forfeits-the-punch-list).
The general recommendation follows: **on variant types, prefer
to avoid the catch-all pattern.** Enumerate every constructor,
or group them with an or-pattern; either way, the compiler stays
on your side when the type grows.

Concretely, instead of

```ocaml
type traffic_light = Red | Yellow | Green

let is_red = function
  | Red -> true
  | _ -> false
```

prefer an or-pattern that names every other constructor:

```ocaml
let is_red = function
  | Red -> true
  | Yellow | Green -> false
```

Now if you add `FlashingRed`, the compiler warns and you make a
conscious choice about which side of the split it belongs on.
The first version (with `_`) would silently treat `FlashingRed`
as not-red; the second version makes that decision a deliberate
edit.

The rule: *on variant types, enumerate the cases explicitly*.
Save the wildcard for `int`, `string`, and other types where
enumeration is impossible.

## Two checks

:::quiz mcq id=M05-L05-q3
Which of the following is the **strongest** reason to use a
variant type instead of a string when representing the set
`{"red", "yellow", "green"}`?

- [ ] Variants are faster.
- [ ] Variants use less memory.
- [x] The compiler checks that every constructor is handled.
- [ ] Constructor spelling is checked at compile time, unlike string contents.

**Why:** all four answers have a grain of truth (variants are
typically a little faster than strings, can be more compact, and
constructor names are checked by the compiler), but the
*strongest* argument is exhaustiveness. The compiler turns "did
I cover every case?" from a manual question into an automatic
check, and surfaces every place that needs updating when the
type grows.
:::

:::quiz mcq id=M05-L05-q2
After adding `FlashingRed` to the type below, what does the
compiler do for an existing function

```text
let is_red = function | Red -> true | _ -> false
```

that uses a wildcard?

- [ ] Warns about non-exhaustiveness.
- [ ] Warns about a redundant case.
- [x] Stays silent; the wildcard catches `FlashingRed`.
- [ ] Refuses to compile.

**Why:** the wildcard `_` covers any constructor not listed
above, including new ones. The compiler treats the match as
already total and does not warn. This is why a wildcard on a
variant type silently disables one of the most useful refactoring
aids.
:::

A code task:

:::quiz code id=M05-L05-q1
Write `is_weekend : day -> bool` exhaustively, over the
seven-constructor `day` type the starter declares. Return `true`
for `Sat` and `Sun`, `false` for the rest. Use an or-pattern to
group, and **do not** use a wildcard.

```ocaml
type day = Mon | Tue | Wed | Thu | Fri | Sat | Sun

let is_weekend d =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (is_weekend Sat) "sat";
  check (is_weekend Sun) "sun";
  check (not (is_weekend Mon)) "mon";
  check (not (is_weekend Wed)) "wed";
  check (not (is_weekend Fri)) "fri";
  print_endline "all tests passed"
```
:::

:::solution

The shape: `function | Sat | Sun -> true | Mon | Tue | Wed | Thu
| Fri -> false`. Listing all five weekday constructors explicitly
keeps the compiler in the loop: if anyone later adds `Holiday`
to the `day` type, every match on `day` (including this one) will
warn. With a wildcard `| _ -> false`, the warning would not
appear, and `Holiday` would silently be treated as a weekday.

:::

## Common pitfalls

**Pitfall 1: silencing warnings with a wildcard.** A wildcard
defeats exhaustiveness. Use it on `int` and `string` where you
must; avoid it on variants.

**Pitfall 2: not enabling warnings-as-errors.** The default is
"warning only," which is fine for exploration. For production
code, promote to error in your dune flags. Make the compiler
your safety net.

**Pitfall 3: ignoring the witness.** The compiler tells you
*which* value the match misses. Read the witness. If it surprises
you, your mental model of the type is off, and the warning is
doing real work.

**Pitfall 4: assuming guards are checked.** They are not. Always
end a match that uses guards with an unguarded clause.

## Activity

:::slide

## Activity

Suppose you have a variant type `color = Red | Green | Blue`
that is matched in twelve places across a codebase. You want to
add a fourth case, `Yellow`. How does the OCaml compiler help,
and what does it *not* help with?

:::

Think about both halves before reading on.

:::slide

## Activity discussion

`type color = Red | Green | Blue` matched in twelve places; add
`Yellow`.

The compiler:

- Issues warning 8 at *every* match on `color` that misses `Yellow`.
- Tells you the missing case (`Yellow`) by example, with location.
- Does **not** tell you *what behaviour* `Yellow` should produce; that's a design decision.

:::

:::slide

## Takeaways

- Structural completeness: mechanically checked.
- Semantic correctness: up to you.
- The compiler answers "where?"; you answer "what?".
- Strongest practical reason to use **variants** for finite kinds.
- Strings can't give this guarantee.

:::

The compiler does the mechanical work for you: it finds every
site that pattern-matches on `color` and does not handle
`Yellow`, and it tells you both *where* (file and line) and
*what is missing* (the constructor name).

It does *not* know what `Yellow` should do at each site. That is
a design decision. Maybe `Yellow` should behave like `Red` in
some contexts and like `Green` in others. Maybe `Yellow` should
trigger an error. The compiler hands you the punch list; you
decide each item.

This division of labour is exactly the right one. The boring
part (finding all the sites) is mechanical; the compiler does
it. The interesting part (deciding what each site should do) is
yours. Without exhaustiveness, you would do both, badly.

## What's next

We have now covered the static analysis. [Lecture 6](M05-L06-tutorial.html)
is the module tutorial: a small interpreter for the
[OCaml AST](M04-L05-tutorial.html). It exercises every pattern
form from this module, plus the exhaustiveness check we just
covered, on a single recursive ADT.

:::slide

## What's next

- Lecture 6: **the tutorial**, an interpreter for the OCaml AST.
- Every pattern form from this module, on a single recursive ADT.
- Exhaustiveness does real work: forgetting a constructor in
  the interpreter is a compile-time warning, not a runtime crash.

:::

## Reading

- **Cornell CS3110**, *Exhaustiveness*:
  <https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html>
- **Real World OCaml**, *Lists and patterns* (the
  pattern-matching efficiency and exhaustiveness sections):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
