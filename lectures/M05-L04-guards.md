---
title: "Guards: when-clauses on patterns"
lecture_no: 4
week: 5
duration_target_min: 20
concepts: [when-guards, conditional pattern matching, exhaustiveness with guards]
keywords: [OCaml, pattern matching, when, guard, conditional pattern]
activity_question: "Write [triangle_kind : int * int * int -> string] that classifies a triangle by its sides as \"equilateral\" (all three sides equal), \"isosceles\" (exactly two equal), or \"scalene\" (all different). Use a tuple pattern and guards that compare the bound names."
think_about_this: "Guards turn pattern matching into pattern+predicate matching. What does the compiler's exhaustiveness checker conservatively assume about a clause guarded by [when]? Why must it?"
reading:
  - title: "Cornell CS3110, Pattern matching guards"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
---

# Guards: when-clauses on patterns


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Guards: when-clauses on patterns</h2>
<p class="title-slide-label">Module 5 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

A pattern by itself matches on *shape*: this constructor, that
literal, a wildcard. Sometimes you want to filter further on a
*computation*: not just "the head of the list is some integer",
but "the head of the list is a *positive* integer." Pure
patterns cannot express this. They cannot compare two bound
names. They cannot ask "is this string longer than 5
characters?" The pattern language is deliberately restricted
because the restriction is what lets the compiler check
exhaustiveness and compile the dispatch efficiently.

The escape hatch is the **guard**: a `when`-clause attached to a
pattern. A guard is a boolean expression evaluated after the
pattern matches. If the pattern matches *and* the guard is true,
the clause fires. If either fails, the matcher moves on to the
next clause.

Guards extend what you can express in a `match`, but they come at
a cost: they suppress exhaustiveness checking for the guarded
clause. We will see why and what to do about it in this lecture,
and revisit the trade-off in [Lecture 5](M05-L05-exhaustiveness.html#exhaustiveness-and-guards-one-more-reminder).

:::slide

## This lecture: guards

- A pattern matches on *shape* (this constructor, that literal).
- A guard matches on a *computation*: positive `int`, long string.
- Syntax: `| pat when <bool-expr> -> rhs`.
- The clause fires only if the pattern matches *and* the guard is true.
- Patterns are restricted to *shape* (not arbitrary computation):
  that is what makes exhaustiveness decidable.
- Cost: the checker treats `when EXPR` opaquely, so guarded
  clauses opt out of the exhaustiveness check. We come back to
  this later in the lecture.

:::

## A first example

```ocaml
let sign = function
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"

let _ = sign 5     (* = "positive" *)
let _ = sign (-3)  (* = "negative" *)
let _ = sign 0     (* = "zero" *)
```

:::slide

## A guard adds a predicate to a clause

```ocaml
let sign = function
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"

let _ = sign 5     (* = "positive" *)
let _ = sign (-3)  (* = "negative" *)
let _ = sign 0     (* = "zero" *)
```

- Each clause has a pattern (`n` or `_`) and **optionally** a guard.
- Pattern matches **and** guard is `true`: clause fires.
- Otherwise: skip to the next clause.

:::

Read the first clause: "match the value against `n` (which
matches anything and binds it to `n`), *and* check that `n > 0`."
If both hold, return `"positive"`. If the pattern matched but the
guard was false, this clause does not fire and the matcher
proceeds to the next clause.

Three things to notice. First, the same name `n` is bound in
each of the first two clauses. Each binding is local to its
clause: the `n` in clause 1 is unrelated to the `n` in clause 2.
Second, the order matters: positive is checked before negative,
and the wildcard catches everything else (i.e., zero). Third,
the guard is an arbitrary OCaml expression of type `bool`, not a
new mini-language. You can call functions, do arithmetic,
compare strings, anything that returns a `bool`.

Without guards, you would write `sign` with nested `if`:

```ocaml
let sign n =
  if n > 0 then "positive"
  else if n < 0 then "negative"
  else "zero"
```

The two versions compute the same thing. The guarded `match`
version is preferred when:

- You are already pattern matching for other reasons (the
  function dispatches on a variant, say, and you also need a
  numerical predicate).
- You want the cases lined up vertically, with pattern and
  predicate side by side.

If the entire body is just a chain of threshold comparisons (as
in `sign`), nested `if`s are fine. Reach for guards when the
pattern part is doing real work too.

## Guards on more interesting patterns

The pattern can do *most* of the work, with the guard filtering
the rest:

```ocaml
let report = function
  | (x, y) when x = y    -> "diagonal"
  | (x, _) when x = 0    -> "on the y-axis"
  | (_, y) when y = 0    -> "on the x-axis"
  | _                    -> "elsewhere"

let _ = report (1, 1)  (* = "diagonal" *)
let _ = report (0, 5)  (* = "on the y-axis" *)
let _ = report (3, 0)  (* = "on the x-axis" *)
let _ = report (2, 4)  (* = "elsewhere" *)
```

:::slide

## Guards on structured patterns

```ocaml
let report = function
  | (x, y) when x = y -> "diagonal"
  | (x, _) when x = 0 -> "on the y-axis"
  | (_, y) when y = 0 -> "on the x-axis"
  | _                 -> "elsewhere"

let _ = report (1, 1)  (* = "diagonal" *)
let _ = report (0, 5)  (* = "on the y-axis" *)
let _ = report (3, 0)  (* = "on the x-axis" *)
let _ = report (2, 4)  (* = "elsewhere" *)
```

- Pattern destructures the pair; guard filters further.
- First clause: needs both names because we compare them.
- Pure patterns cannot express `x = y`.

:::

The first clause has a guard `x = y` that compares the two
components of the pair. *This is the kind of test pure patterns
cannot express.* A pattern can say "the first component is the
literal `0`", but it cannot say "the first component equals the
second", because the pattern language has no way to refer to
another binding from itself. The guard solves this with a clean
escape hatch: bind both pieces with the pattern, then compare
them in the guard.

Notice the second clause does *not* compare the first component
to the second; it compares the first component to the literal
`0`. We could equivalently write `| (0, _) -> "on the y-axis"`
with a pure literal pattern. The guarded version generalises:
swap `x = 0` for `x < 0` or `x mod 2 = 0` and you have a
predicate-on-a-bound-value that pure patterns can not write.

## Guards see what the pattern bound

A guard can use any name that the pattern in the *same clause*
introduces. It cannot peek at bindings from other clauses, and
it cannot use names that have not been bound yet.

```ocaml
let starts_negative = function
  | [] -> false
  | x :: _ when x < 0 -> true
  | _ -> false

let _ = starts_negative [-3; 5; 7]  (* = true *)
let _ = starts_negative [1; 2; 3]   (* = false *)
let _ = starts_negative []          (* = false *)
```

:::slide

## Guards reference what the pattern bound

```ocaml
let starts_negative = function
  | [] -> false
  | x :: _ when x < 0 -> true
  | _ -> false

let _ = starts_negative [-3; 5; 7]  (* = true *)
let _ = starts_negative [1; 2; 3]   (* = false *)
let _ = starts_negative []          (* = false *)
```

- Guard `when x < 0` uses `x`, bound by the pattern `x :: _`.
- Guards see names from the **same clause's** pattern only.

:::

In the second clause, the pattern `x :: _` binds `x` to the head
of the list. The guard `x < 0` references that binding. If the
list is empty, the pattern fails and we never get to the guard.
If the list is non-empty but the head is non-negative, the
pattern matches but the guard fails, and the matcher moves on.

If the matcher reaches the third clause (wildcard), then either
the input was empty (caught by clause 1) or it was non-empty
with a non-negative head (clause 2 pattern matched, guard
failed). Either way, we return `false`. Clause 1 returns
`false` for empty too, so the final wildcard is only ever
reached when the head was non-negative.

A subtle point: when a guard fails, the matcher continues to the
next clause; it does *not* re-attempt the same pattern with
different bindings. So `x :: _ when x < 0` either fires (if both
match) or moves on; there is no backtracking.

## Exhaustiveness with guards is conservative

Here is the rub. Consider this match, where the two guards
together *logically* cover every integer:

```ocaml
let classify n =
  match n with
  | n when n > 0  -> "positive"
  | n when n <= 0 -> "non-positive"
```
```mdx-error
Lines 2-4, characters 5-38:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  All clauses in this pattern-matching are guarded.
```

The guards `n > 0` and `n <= 0` between them handle every `n`.
We can see that. The compiler cannot, and it still warns
(warning 8).

The exhaustiveness checker reasons about *patterns*, not about
arbitrary boolean expressions. A guard might call a function,
read from a file, depend on state; from the compiler's point of
view every guard is a black box that "might fail at runtime." So
even though we know the two guards partition the integers, the
checker treats both clauses as "might be skipped" and flags the
whole match: "All clauses in this pattern-matching are guarded."
Note that it names no witness value; with guards in play it
cannot point at a concrete uncovered input.

:::slide

## Exhaustiveness with guards is conservative

```ocaml
let classify n =
  match n with
  | n when n > 0  -> "positive"
  | n when n <= 0 -> "non-positive"
```
```mdx-error
Lines 2-4, characters 5-38:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  All clauses in this pattern-matching are guarded.
```

- Guards together cover every integer; **the compiler does not know**.
- Exhaustiveness reasons about patterns, not about boolean expressions.
- The checker treats every guard as "might fail at runtime."
- Add an unguarded clause (or wildcard) to close the match.

:::

When the gap is real, the compiler is right; when the guards
happen to be total, the compiler errs on the side of warning
anyway. Both produce the same warning text, and from the
warning alone you cannot tell which case you are in. Compare a
version with a genuine gap:

```ocaml
let classify n =
  match n with
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
```
```mdx-error
Lines 2-4, characters 5-33:
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
  All clauses in this pattern-matching are guarded.
```

Here zero really is uncovered: at runtime `classify 0` raises
`Match_failure`. Same warning, real bug. The fix in both cases
is the same: add an unguarded clause that covers the rest.

```ocaml
let classify = function
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"

let _ = classify 5     (* = "positive" *)
let _ = classify (-3)  (* = "negative" *)
let _ = classify 0     (* = "zero" *)
```

:::slide

## Fix: close the match with an unguarded clause

```ocaml
let classify = function
  | n when n > 0 -> "positive"
  | n when n < 0 -> "negative"
  | _ -> "zero"

let _ = classify 5     (* = "positive" *)
let _ = classify (-3)  (* = "negative" *)
let _ = classify 0     (* = "zero" *)
```

- `| _ -> "zero"` is unguarded; the checker can lean on it.
- Warning 8 goes away.
- Same fix whether the gap is real (`n > 0` / `n < 0`) or
  conservative (`n > 0` / `n <= 0`).

:::

The cost of allowing arbitrary computation in guards is that the
checker has to be conservative. It proves what it can prove
(which constructors and shapes the patterns cover); the rest is
up to you.

So the rule for guards is: **add an unguarded catch-all to close
the match**, unless you are certain the guarded clauses are
total (and you do not mind the warning).

## Don't reach for guards when a pattern would do

Guards extend what you can express, but they are not free. Each
guard suppresses some compiler help. So a useful discipline: do
not reach for a guard when a pure pattern would express the same
thing.

```ocaml
let is_origin = function
  | (x, y) when x = 0.0 && y = 0.0 -> true
  | _ -> false
```

This works, but it is unnecessarily heavy. The pattern can do
the comparison directly:

```ocaml
let is_origin = function
  | (0.0, 0.0) -> true
  | _ -> false
```

:::slide

## Prefer patterns when they suffice

```ocaml
(* heavy *)
let is_origin = function
  | (x, y) when x = 0.0 && y = 0.0 -> true
  | _ -> false

(* clean *)
let is_origin = function
  | (0.0, 0.0) -> true
  | _ -> false

let _ = is_origin (0.0, 0.0)  (* = true *)
let _ = is_origin (1.0, 2.0)  (* = false *)
```

- Same behaviour; no guard needed.
- Pure pattern preserves exhaustiveness checking.
- Use `when` only when a pure pattern cannot express the predicate.

:::

The pure-pattern version is shorter, more obviously correct, and
keeps exhaustiveness checking intact. Reach for `when` only when
the pattern language is not enough:

- Numeric inequalities: `n > 0`, `n <= max_size`.
- String predicates: `String.length s > 5`,
  `String.starts_with ~prefix:"foo" s`.
- Relationships between two bound names: `x = y`, `a < b`.
- Calls to external predicates: `is_valid_id name`.

These are things the pattern language cannot encode. For
anything else, prefer the pattern.

## Guards and side effects

A guard is just an expression, and an expression can have side
effects. Resist the urge.

```ocaml
let sign = function
  | n when (Printf.printf "checking n > 0\n"; n > 0) -> "positive"
  | n when (Printf.printf "checking n < 0\n"; n < 0) -> "negative"
  | _ -> "zero"

let _ = sign 0  (* = "zero", after both prints *)
```

The toplevel prints `checking n > 0`, then `checking n < 0`,
*then* returns `"zero"`. For input `0` the matcher tries the
first clause's guard, finds it false, tries the second clause's
guard, finds it false, and only then takes the wildcard. Two
guard evaluations for a single call.

If the guards had been pure boolean tests, that re-evaluation
would be invisible. With prints in them, the order and count of
calls become an observable mess that depends on the value, the
clause ordering, and the compiler's matrix decomposition.
Debugging is a small nightmare.

The discipline: guards should be *pure*, i.e., return a `bool`
without observable side effects. If you need a side effect,
sequence it before the `match` or inside the right-hand side.

:::slide

## Guards and side effects

```ocaml
let sign = function
  | n when (Printf.printf "n > 0?\n"; n > 0) -> "positive"
  | n when (Printf.printf "n < 0?\n"; n < 0) -> "negative"
  | _ -> "zero"

let _ = sign 0  (* = "zero", after both prints *)
```

Prints `n > 0?`, then `n < 0?`, then returns `"zero"`. Two guard
evaluations for one call.

- Guards are arbitrary `bool` expressions; side effects are
  **allowed**, just rarely a good idea.
- Each guard fires as the matcher tries that clause; one call can
  evaluate several guards.
- Keep guards **pure**: return a `bool`, no observable effects.
- If you need a side effect, do it before the `match` or in the
  right-hand side.

:::

## Compound guards and short-circuiting

A guard is just `bool`, so you can combine multiple conditions
with `&&` and `||`:

```ocaml
let in_range n = function
  | (low, high) when low <= n && n <= high -> true
  | _ -> false
```

The Boolean operators short-circuit, so this is well-behaved:
`low <= n` is evaluated first, and `n <= high` only if the first
was true. Standard rules apply.

For complex guards, you can also call a named predicate:

```ocaml
let valid_pair = function
  | (a, b) when a < b -> true
  | _ -> false
```

If the predicate gets large, lift it to a named function and
call it from the guard. Keeps the `match` readable.

## Two checks

:::quiz mcq id=M05-L04-q3
What does this evaluate to?

```ocaml
let classify = function
  | n when n > 0 -> "positive"
  | _ -> "non-positive"

let result = classify 0
```

- [ ] `"positive"`
- [x] `"non-positive"`
- [ ] Compile error
- [ ] `Match_failure`

**Why:** the first clause's guard `n > 0` is false when `n = 0`, so
the clause does not fire. The wildcard catches everything else
and returns `"non-positive"`.
:::

:::quiz mcq id=M05-L04-q2
Why does the compiler warn about this match as non-exhaustive?

```text
let classify = function
  | n when n >= 0 -> "non-negative"
  | n when n < 0 -> "negative"
```

- [ ] The patterns `n` and `n` clash.
- [ ] The wildcard is missing.
- [x] The compiler does not reason about arbitrary boolean guards; it cannot prove the two guards together are total.
- [ ] Order is wrong.

**Why:** every guarded clause is treated as "may fail" by the
exhaustiveness checker. Even though `n >= 0` and `n < 0` cover
all integers between them, the compiler will not check arithmetic
facts. The fix is an unguarded `| _ -> ...` to close the match.
:::

A code task:

:::quiz code id=M05-L04-q1
A football scoreline is a pair `(ours, theirs)` of goal counts.
Write `match_result : int * int -> string` that returns:

- `"win"` when we scored more than they did,
- `"loss"` when they scored more than we did,
- `"draw"` otherwise.

Use a tuple pattern with `when`-guards that compare the two bound
names. Make sure the match is exhaustive (no warning 8).

```ocaml
let match_result score =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (match_result (3, 1) = "win") "win";
  check (match_result (0, 2) = "loss") "loss";
  check (match_result (2, 2) = "draw") "draw";
  check (match_result (0, 0) = "draw") "goalless draw";
  print_endline "all tests passed"
```
:::

:::solution

The shape: tuple pattern binds the two counts, guards compare the
bindings (`ours > theirs`, then `ours < theirs`), and an unguarded
wildcard returns `"draw"` so the checker sees the match is closed.

:::

## Common pitfalls

**Pitfall 1: omitting the catch-all after guards.** The compiler
warns; do not silence the warning, add a wildcard or unguarded
clause. Otherwise, an input that no guard covers raises
`Match_failure` at runtime.

**Pitfall 2: using a guard where a pattern would do.** Pure
patterns preserve exhaustiveness; guards do not. Save guards for
predicates the pattern language cannot express.

**Pitfall 3: side effects in guards.** A guard may be evaluated
zero, one, or more times depending on the matcher. Keep guards
pure: return a `bool`, do nothing else.

**Pitfall 4: assuming the matcher backtracks.** It does not. If
a pattern matches but its guard fails, the matcher moves to the
next clause; it does not retry the same pattern with different
bindings.

## Activity

:::slide

## Activity

Write `triangle_kind : int * int * int -> string` that classifies
a triangle by its sides:

- `"equilateral"` when all three are equal,
- `"isosceles"` when *exactly* two are equal,
- `"scalene"` when all three differ.

Use a tuple pattern with `when`-guards comparing the bound names;
no `if`/`else`.

:::

Try it before reading on.

:::solution

:::slide

## Activity solution

```ocaml
let triangle_kind = function
  | (a, b, c) when a = b && b = c -> "equilateral"
  | (a, b, c) when a = b || b = c || a = c -> "isosceles"
  | _ -> "scalene"

let _ = triangle_kind (3, 3, 3)  (* = "equilateral" *)
let _ = triangle_kind (5, 5, 8)  (* = "isosceles"  *)
let _ = triangle_kind (3, 4, 5)  (* = "scalene"    *)
```

- Tuple pattern binds three names; guards compare the bindings.
- Equilateral first (most specific); the second clause then
  catches "any two equal" (with all-three-equal already ruled
  out, that is *exactly* two); wildcard catches the rest.

:::

:::

The first guard catches the all-three-equal case. The second
catches "any pair equal," which the previous clause having
already ruled out the equilateral case makes into "exactly two
equal." The wildcard catches everything else, i.e., all three
different. Without the wildcard, the compiler warns that triples
like `(1, 2, 3)` are unmatched, and the call would crash with
`Match_failure`
at runtime.

## What's next

We have now seen four pattern forms (literal, variable,
wildcard, structured) and one extension (`when` guards).
[Lecture 5](M05-L05-exhaustiveness.html) zooms in on the static
check that has been hovering in the background: exhaustiveness. Why
it matters, how the compiler proves it, what to do when it warns,
and why it is the single biggest argument for using
[variants](M04-L03-variants.html) in your designs.

:::slide

## What's next

- Lecture 5: **exhaustiveness checking** in depth.
- We've seen warning 8 in passing. Now we look at how it works.
- The strongest argument for variants over strings or ints.

:::

## Reading

- **Cornell CS3110**, *Pattern matching guards*:
  <https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html>
- **Real World OCaml**, *Lists and patterns* (guards):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
