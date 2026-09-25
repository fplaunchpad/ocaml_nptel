---
title: "Mutable references"
lecture_no: 1
week: 7
youtube_id: i6CqQobVyXo
duration_target_min: 22
concepts: [mutation, ref, !, :=, side effects, when to use mutation]
keywords: [OCaml, ref, mutation, side effects, !, :=]
activity_question: "Write [make_running_total : unit -> (int -> int)] that returns a closure: each call adds its argument to a running total and returns the new total. Two calls to [make_running_total ()] must produce two independent accumulators."
think_about_this: "OCaml is functional-first but supports mutation via [ref]. When you reach for mutation, what property are you giving up? When does the trade pay off?"
reading:
  - title: "Cornell CS3110, References"
    url: https://cs3110.github.io/textbook/chapters/mut/refs.html
---

# Mutable references


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Mutable references</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

For six modules we have written OCaml without using mutation. Every
value has been immutable; whenever we needed a new state, we made a
new value, with [`let` shadowing](M02-L02-let-bindings.html) the
old name or building a fresh list, record, or tuple. This is the
*functional* style and it has real benefits: any expression `f x`
produces the same answer regardless of when in the program you run
it, so reasoning about code reduces to
[substituting values for names](M01-L02-why-fp.html#equational-reasoning),
and the compiler can inline and reorder freely.

:::slide

## Six modules without mutation

- M1-M6: every value immutable. Fresh state = fresh value.
- Functional-style payoff:
  - `f x` gives the same answer wherever you call it;
  - reasoning reduces to [substitution](M01-L02-why-fp.html#equational-reasoning);
  - the compiler can inline and reorder freely.
- But sometimes mutation is the right tool.

:::

But mutation is, sometimes, the right tool. A web server counts
how many requests it has handled across calls. A memoization
table caches results across calls. A long-lived event loop keeps
a connection pool that wakes up, shrinks, and grows. None of these are *impossible* to express
without mutation, but threading the state through every call by
hand makes the code longer and noisier than it needs to be. OCaml,
unlike a purely-functional language such as [Haskell](https://www.haskell.org/),
takes the position that mutation should be available when you want
it but should not be the default. The simplest mechanism the
language offers for opting in is the *mutable reference cell*, or
`ref` for short. This module is about `ref` and the other
mutable building blocks (mutable record fields, arrays), and about
when reaching for them is worth what you give up.

:::slide

## When mutation is the right tool

- A web server: request counter across requests.
- A memoization table: cached results across calls.
- A long-lived event loop: connection pool that grows and shrinks.
- Threading the state through every call by hand is noisier than it needs to be.
- OCaml's stance (unlike Haskell): mutation **available**, not the default.
- Simplest opt-in: the **mutable reference cell**, or `ref`.

:::

Mutation is one of several kinds of *side effect* a program can
have. A side effect is anything an expression does besides return a
value: changing the value stored in some cell, printing to the
screen, raising an exception, looping forever, sending a packet
over the network. This module covers the first three. We focus on
**state** (mutable cells, mutable fields, arrays) this lecture and
the [next](M07-L02-arrays-and-mutation.html); we cover
[**exceptions**](M07-L03-exceptions.html) in their own lecture.
**I/O** has been with us implicitly since `print_endline` in
[the very first programs](M01-L02-why-fp.html); **non-termination** is whatever
recursion you write that does not stop. The general lesson is the
same for all four: they let you do things pure functions cannot,
but they cost you equational reasoning.

:::slide

## Side effects: a map

A *side effect* is anything an expression does besides return a value.

- **State**: mutable cells, mutable record fields, arrays. (This
  lecture and the next.)
- **Exceptions**: control-flow escapes.
  ([Their own lecture](M07-L03-exceptions.html).)
- **I/O**: `print_endline`, file and network access.
- **Non-termination**: a loop that never returns.

Each lets you do things pure functions cannot, and each costs you
equational reasoning. We start with **state**.

:::

What "costs you equational reasoning" means at full scale: on
1 August 2012, the trading firm Knight Capital deployed new code
to seven of its eight servers. The eighth still ran an old code
path guarded by a *reused* feature flag, and the new deployment
flipped that flag on. Stale state plus live flag reactivated
code that had been dead for years, and in 45 minutes the firm
lost about 440 million dollars and nearly ceased to exist. The
[SEC's account](https://www.sec.gov/litigation/admin/2013/34-70694.pdf)
reads like a parable about mutable state: nothing in any one
server's code was wrong; the *combination* of mutations across
machines was. Pure values cannot disagree with each other;
mutable state can, and at scale it eventually does.

## A ref is a mutable box

```ocaml
let counter = ref 0

let () = counter := 1
let () = counter := 2
let _ = !counter  (* = 2 *)
```

Three operators, three roles. `ref x` *creates* a fresh mutable
cell holding the value `x`; the expression evaluates to a reference
to that cell, of type `int ref`. The operator `:=` *writes* a new
value into the cell. The operator `!` *reads* the current value
out: the contents left by the last write.

:::slide

## A `ref` is a mutable box

```ocaml
let counter = ref 0

let () = counter := 1
let () = counter := 2
let _ = !counter  (* = 2 *)
```

- `ref x` creates a mutable cell holding `x`.
- `!cell` reads the current value (dereferencing).
- `cell := y` writes a new value into the cell.
- The cell itself has type `int ref`.
- The contents (`!counter`) have type `int`.

:::

The unusual thing for a programmer arriving from C or Python is
that *creation*, *read*, and *write* each get their own syntax.
In C you write `int counter = 0` to create and `counter = 1` to
update; in Python `counter = 0` does both, with the second `=`
deciding from context that it is an update. OCaml separates the
three because, internally, they really are three different
operations: `ref` allocates a cell on the heap, `:=` mutates a cell
that already exists, and `!` reads from a cell. C makes the same
distinction implicitly with pointers (`malloc` allocates, `*p = 1`
writes, `*p` reads), and OCaml's `ref` is essentially a
heap-allocated single-cell pointer with named operations.

:::slide

## Why three operators?

In C and Python, you'd write `counter = 1` for both creation and
update. OCaml separates them:

- **Creation**: `let counter = ref 0` binds a *name* to a *fresh
  cell* containing 0.
- **Read**: `!counter` reads from the cell.
- **Write**: `counter := 1` writes to the cell.
- C makes this same distinction implicitly with pointers: `malloc`
  creates, `*p = 1` writes, `*p` reads.
- OCaml just makes it explicit at the syntax level.

:::

One small note about syntax: the `!` in `!counter` is the
dereference operator, *not* boolean negation. Boolean negation is
the function `not`, not a symbol. This is the same `!`/`not` split
that ML-family languages have shared since [Standard ML](https://smlfamily.github.io/),
and the choice is deliberate: the dereference is the more common
operation by far on a ref, so it gets the short symbol.

## The cost of mutation: equational reasoning

Here is the price you pay when you reach for a `ref`.

```ocaml
let counter = ref 0
let get_next () = counter := !counter + 1; !counter

let _ = get_next ()  (* = 1 *)
let _ = get_next ()  (* = 2 *)
let _ = get_next ()  (* = 3 *)
```

The same expression
`get_next ()` produces three different answers in succession. There
is no way to predict the answer of a call to `get_next ()` without
knowing how many times it has been called before.

:::slide

## Mutation breaks equational reasoning

```ocaml
let counter = ref 0
let get_next () = counter := !counter + 1; !counter

let _ = get_next ()  (* = 1 *)
let _ = get_next ()  (* = 2 *)
let _ = get_next ()  (* = 3 *)
```

- `get_next ()` is *not* equal to `get_next ()`.
- First call returns 1, second returns 2.
- You can't replace a call by its result without changing behaviour.
- **The cost of mutation**: the
  [equational reasoning](M01-L02-why-fp.html#equational-reasoning)
  we had with pure functions is gone for code that touches a `ref`.

:::

Contrast with a pure function. If `let f x = x + 1`, then `f 3` is
always `4`. You can replace any occurrence of `f 3` in the program
with `4` and nothing changes: the behaviour is the same, the
performance is the same. This
[*equational* property](M01-L02-why-fp.html#equational-reasoning)
is what makes pure code easy to reason about. You think of a function
call as naming a value, the way `pi` names `3.14159`, and you can
substitute freely.

Mutation gives that up. `get_next ()` is not the name of a value;
it is the name of an *action*. The action consults a shared mutable
state, modifies it, and returns the new state. Two textually
identical calls can produce different results. You can no longer
inline a call to `get_next ()` without thinking about whether the
inlining changes how many times the function is called.

This is why OCaml is *functional-first*. The default discipline is
to write pure code, where equational reasoning holds, and to
isolate mutation behind a small surface area when it is needed. We
will come back to "what surface area" at the end of the lecture.

## When ref is the right tool

A non-exhaustive list of cases where reaching for a `ref` is
defensible.

:::slide

## When `ref` is the right tool

- **Imperative-flavoured loops:** counters, accumulators.
- **Caches:** memoization tables across calls.
- **Shared mutable structure:** graphs, doubly-linked lists,
  AST backpatching during compilation.
- **Mutation interop:** callbacks, GUI state.
- Most everyday OCaml uses no `ref`s; reach only when the
  alternative is awkward.

:::

**Counters and accumulators.** When you are stepping through a
sequence and the natural shape of the algorithm is "for each
element, update this variable," a `ref` is fine. We will see in
the next lecture that `for` loops in OCaml usually go hand in hand
with refs and arrays: this is the imperative corner of the
language, and you use it where the algorithm wants it.

**Caches.** A memoization table that maps inputs to previously
computed outputs grows across calls. A [`Hashtbl.t`](https://v2.ocaml.org/api/Hashtbl.html)
is itself mutable; you reach for it directly without wrapping in a
`ref`. A small inline cache, on the other hand, is often a `ref` of
an [option](M04-L04-recursive-types.html#the-option-type) or a list.

**Shared mutable structure.** Building a structure where several
pointers see the same updates: a graph with cycles, a
doubly-linked list, an AST node whose forward reference is filled
in *after* the surrounding tree is built (this last is called
*backpatching* in compiler pipelines). Each of these needs a
`ref` as the shared cell or as the backpatch point. We will not
write one of these in this course, but they are part of what
`ref` makes possible.

**Interop.** Code that talks to GUI toolkits, network callbacks,
or any C library expects to push state into the world rather than
return it from a function. A `ref` (or a mutable record field, or
a hash table) is how OCaml participates in that world.

For most everyday OCaml code, *none* of these apply, and the
function you are writing has no `ref`s at all. Reach for `ref`
when the alternative is awkward, not as a default.

## A small example: a one-shot

Real programs often contain an action that must happen at most
once: print a deprecation warning the first time an old function
is called, initialise a cache on first use, release a resource on
the first cleanup and ignore repeats. The shape behind all of
these is a *one-shot*: a closure that does its work on the first
call and refuses thereafter. Mutation is the cleanest way to
write one.

```ocaml
let make_once () =
  let used = ref false in
  fun () ->
    if !used then None
    else begin
      used := true;
      Some "first call"
    end

let f = make_once ()
let _ = f ()  (* = Some "first call" *)
let _ = f ()  (* = None *)
let _ = f ()  (* = None *)
```

Trace it. `make_once ()` allocates a fresh `used = ref false` and
returns the inner `fun () -> ...`, which captures `used` (this is
the closure capture from
[the functions-as-values lecture](M03-L01-functions-as-values.html#what-is-a-closure),
now capturing a *mutable* cell). On the first `f ()`, `!used` is
`false`, so the `else` branch runs: it flips `used` to `true` and
returns `Some "first call"`. On every later `f ()`, `!used` is
`true`, and the answer is `None`. The `begin ... end` is
parentheses around the two-step sequence, as in
[the counting-down example](M03-L02-recursion.html#recursion-on-numbers-counting-down).

The mutable state `used` is hidden inside the
closure: there is no way to reach it from the outside. Each call
to `make_once` produces a fresh, independent one-shot.

:::slide

## A small example: a one-shot

```ocaml
let make_once () =
  let used = ref false in
  fun () ->
    if !used then None
    else begin
      used := true;
      Some "first call"
    end

let f = make_once ()
let _ = f ()  (* = Some "first call" *)
let _ = f ()  (* = None *)
let _ = f ()  (* = None *)
```

- The closure captures `used`; first call sets it, later calls see it.
- **Private mutable state inside a function**: a clean use of `ref`.

:::

The pattern is *private mutable state inside a closure*. The state
is invisible to callers; they can only observe its effects through
the function's behaviour. From the outside, `f ()` looks like a
function that happens to return `None` on the second and later
calls. The fact that it does so via a mutable flag is an
implementation detail.

This same pattern, scaled up, is how many imperative languages
build *objects*: an object is essentially a record of closures
that share some private mutable state. Smalltalk and JavaScript
make the connection explicit; in OCaml, the building blocks are
exposed and you put them together as needed.

## Sequencing side effects with `;`

We met `;` in [the hello-world lecture](M01-L04-hello-world.html) as the way to
sequence two unit-typed expressions: `e1; e2` evaluates `e1`
(which must be `unit`), then `e2`, and returns `e2`'s value. With
refs, `;` becomes the everyday tool for threading several updates
in a row:

```ocaml
let r = ref 0

let () =
  r := 1;
  r := 2;
  r := 3
```

There is no syntactic limit on the chain: `e1; e2; e3; e4`
evaluates each in order and returns the last. As before, every
expression except the last must produce `unit`, or the compiler
warns that you are throwing a value away; wrap the offender in
`ignore` if the discard is intentional.

The `begin ... end` and `(...)` brackets group a sequence into one
expression, which we sometimes need when a sequence appears in the
branch of an `if`. We saw this when writing
[`count_down`](M03-L02-recursion.html).

:::slide

## Sequencing with `;` (refs in a row)

```ocaml
let r = ref 0

let () =
  r := 1;
  r := 2;
  r := 3
```

- `;` sequences side effects (introduced in
  [the hello-world lecture](M01-L04-hello-world.html)).
- Left of each `;` must be `unit`.
- A non-unit expression in sequence triggers a warning; wrap in
  `ignore` to silence.

:::

## incr and decr

A ref of `int` is so common that the standard library gives you two
shortcuts:

```ocaml
let n = ref 0

let () = incr n
let () = incr n
let () = incr n
let _ = !n        (* = 3 *)
let () = decr n
let _ = !n        (* = 2 *)
```

`incr r` is shorthand for `r := !r + 1`; `decr r` is shorthand for
`r := !r - 1`. They are mildly more readable in counter-style code.
Otherwise the difference is cosmetic.

## A quick check

:::quiz mcq id=M07-L01-q3
What is the type of `ref "hello"`?

- [ ] `string`
- [x] `string ref`
- [ ] `string * int`
- [ ] `'a ref`

**Why:** `ref` is a function (well, a constructor) of type `'a ->
'a ref`. Applied to a `string`, it returns a `string ref`. The
contents are `"hello"`; the reference is a fresh cell holding that
string.
:::

:::quiz mcq id=M07-L01-q2
What does this print?

```ocaml
let r = ref 0
let () = r := 5
let () = r := !r + 1
let _ = !r
```

- [ ] `0`
- [ ] `5`
- [x] `6`
- [ ] error

**Why:** create cell holding `0`. Write `5`; cell now holds `5`.
Compute `!r + 1`, which reads `5` and adds `1` to get `6`. Write
`6` back into the cell. Final read returns `6`.
:::

## Aliasing: two names for one cell

Because a `ref` is a heap-allocated cell, you can have two names
that refer to *the same* cell. Mutating through one name mutates
what the other name sees.

```ocaml
let x = ref 42
let y = x
let () = x := 99
let _ = !x  (* = 99 *)
let _ = !y  (* = 99 *)
```

The `let y = x` did not copy the
cell; it bound a new name to the same cell. Both names refer to
the same place in memory, so the write through `x` is visible
through `y`.

If you actually want two independent cells with the same initial
value, you have to create two cells:

```ocaml
let x = ref 42
let y = ref 42
let () = x := 99
let _ = !x  (* = 99 *)
let _ = !y  (* = 42 *)
```

Each `ref 42` evaluation is a fresh allocation, so the write
through `x` leaves `y`'s cell untouched.

This *aliasing* is the source of much of the difficulty of
imperative programming. Anywhere a `ref` (or any mutable value)
escapes a function, there is now a question of "who else has a
handle on this cell, and what might they do to it?" In a pure
functional setting, the question does not arise because there is
nothing to share. With mutation, every API has to decide what its
caller is allowed to do with the values it returns.

:::slide

## Aliasing: two names for one cell

```ocaml
let x = ref 42
let y = x          (* alias: same cell *)
let () = x := 99
let _ = !x         (* = 99 *)
let _ = !y         (* = 99, mutation visible through y *)
```

- `let y = x` shares the cell; both names point at the same
  place in memory.
- Mutating through one name is visible through the other.
- For two *independent* cells with the same initial value,
  allocate fresh: `let y = ref 42`.

:::

## Structural and physical equality

Aliasing immediately raises a question: given two refs, how do you
ask whether they are *the same cell* versus *cells that happen to
hold equal contents*? OCaml has two operators for this. `=` is
**structural** equality: it walks the two values comparing them
piece by piece. `==` is **physical** equality: it asks whether the
two operands are the exact same heap-allocated object.

The rule on refs is:

- `r1 = r2` (structural) iff `!r1 = !r2`. Two refs are
  structurally equal exactly when their contents are.
- `r1 == r2` (physical) iff `r1` and `r2` name the same cell,
  i.e., the two are aliases.

So `ref 5 = ref 5` is *true* even though the two `ref 5`s are
separate allocations, but `ref 5 == ref 5` is *false*.

```ocaml
let a = ref 5
let b = ref 5      (* fresh allocation, same contents *)
let c = a          (* alias: same cell *)
let _ = a =  b     (* = true:  contents match *)
let _ = a == b     (* = false: different cells *)
let _ = a == c     (* = true:  same cell *)
```

:::slide

## `=` walks into the cell; `==` checks identity

```ocaml
let a = ref 5
let b = ref 5      (* fresh allocation *)
let c = a          (* alias *)
let _ = a =  b     (* = true  *)
let _ = a == b     (* = false *)
let _ = a == c     (* = true  *)
```

- `r1 = r2` (structural) iff `!r1 = !r2`.
- `r1 == r2` (physical) iff they name the same cell.
- Two `ref 5`s compare *structurally equal* but are *not*
  aliases.

:::

A richer worked example that exercises both axes (aliasing of
refs *and* sharing of list contents) at once:

```ocaml
let l1 = [1; 2; 3]
let l2 = l1            (* alias: same list *)
let l3 = [1; 2; 3]     (* fresh allocation, equal contents *)
let r1 = ref l1
let r2 = r1            (* alias: same ref cell *)
let r3 = ref l3        (* fresh ref cell *)
```

The heap layout that results:

<figure class="diagram">
  <img src="/assets/m07/figures/equality-heap.svg"
       alt="r1 and r2 both point to a ref cell that holds the list [1;2;3]; l1 and l2 also point at that same list. r3 points to a separate ref cell that holds a different list [1;2;3]; l3 also points at that second list."
       style="max-height: 360px;">
</figure>

With this picture in mind:

- `l1 = l2` and `l1 = l3` are both *true*: structural equality
  walks the contents, and all three lists are `[1; 2; 3]`.
- `l1 == l2` is *true* (same allocation) but `l1 == l3` is *false*
  (two separate allocations with equal contents).
- `r1 = r2` and `r1 = r3` are both *true*: structural equality on
  refs compares contents, and both cells hold an equal list.
- `r1 == r2` is *true* (aliased to the same cell) but `r1 == r3`
  is *false* (two different cells).

The structural check `=` says "the contents match." The physical
check `==` says "they are the *same* cell." Aliasing is exactly
the property `==` detects.

A useful rule of thumb: `==` is rarely what you want. Most code
asks "do these values represent the same thing?", which is
structural equality (`=`). Reach for `==` when you genuinely need
to know "are these two names for the *same* mutable cell?", which
happens in aliasing-aware code (caches keyed by identity, cycle
detection, breaking circular print). For everything else, use `=`.

:::slide

## `=` is structural; `==` is physical

:::cols

:::col 55%

```ocaml
let l1 = [1; 2; 3]
let l2 = l1
let l3 = [1; 2; 3]
let r1 = ref l1
let r2 = r1
let r3 = ref l3
```

:::

:::col 45%

<img src="/assets/m07/figures/equality-heap.svg"
     alt="r1 and r2 share a ref cell that holds l1 (= l2 = [1;2;3]); r3 has its own ref cell holding l3 (a separate [1;2;3]).">

:::

:::

- `l1 = l2 = l3` (structural); `l1 == l2` but `l1 != l3`.
- `r1 = r2 = r3` (structural); `r1 == r2` but `r1 != r3`.
- `==` detects aliasing; `=` ignores it.

:::

:::notes

In-browser caveat: js_of_ocaml represents OCaml strings and floats
as JavaScript primitives, so two fresh strings with the same
characters (or two fresh floats with the same value) compare
*equal* under `==` in the browser even though they would compare
unequal under the bytecode or native runtime. Boxed values (refs,
lists, tuples, records, `Some _` payloads) behave identically. The
examples above all use refs and lists, so they give the same
answer in `x-ocaml` cells as on the command line.

:::

:::quiz mcq id=M07-L01-q4
Given:

```ocaml
let a = ref 5
let b = ref 5
let c = a
```

which of the following are true?

- [x] `a = b` and `a = c`
- [ ] `a == b` and `a == c`
- [ ] `a = b` but not `a = c`
- [ ] none of them

**Why:** structural equality `=` ignores identity, so `a = b` and
`a = c` are both true (all three refs hold `5`). Physical
equality `==` requires the *same* allocation: `a == c` is true
because `let c = a` aliases the cell, but `a == b` is false
because `ref 5` was evaluated twice and allocated two distinct
cells.
:::

## Value restriction: a subtle interaction with polymorphism

Mutation and [polymorphism](M06-L01-functions-revisited.html) do
not quite get on. Consider:

```ocaml
let r = ref []
```

The toplevel reports `'_weak1 list ref`, not `'a list ref`. The
underscore in `'_weak1` marks this as a *weakly* polymorphic type:
`r` may be used at *one* element type, not many, and OCaml will
infer which one from the first use.

```ocaml
let r = ref []
let () = r := [1]
let _ = !r          (* = [1]; r is now int list ref *)
```

After `r := [1]`, the type of `r` is locked to `int list ref`. A
subsequent attempt to push a string in would be rejected at
compile time. This rule is called the **value restriction**, and
it exists to plug a hole in type safety.

The hole, if there were no value restriction: a single cell could
be used at two different types at once, and the type system would
let you read out an `int` as a `string`.

```ocaml skip
(* hypothetical: this would compile if there were no
   value restriction, and crash at runtime *)
let r : 'a list ref = ref [] in
let r_int : int list ref = r in
let r_str : string list ref = r in
r_int := [1];
print_endline (List.hd !r_str)
```

`r_int` and `r_str` are aliases for the same cell. Writing an `int
list` through one alias and reading a `string list` through the
other would print arbitrary bytes as a string, or segfault. The
value restriction is the type system's way of refusing to compile
the program in the first place: by demoting `'a` to `'_weak1` when
a polymorphic type is created by something other than a value, it
forces every use of `r` to agree on one element type.

:::slide

## Value restriction

```ocaml
let r = ref []
```

- `r : '_weak1 list ref` (note the underscore).
- *Weakly* polymorphic: usable at **one** element type, not many.
- First use of `r` fixes the type for good.

:::

:::slide

## Why the restriction exists

Without it, this would compile:

```ocaml skip
let r : 'a list ref = ref [] in
let r_int : int list ref = r in
let r_str : string list ref = r in
r_int := [1];
print_endline (List.hd !r_str)   (* read int as string! *)
```

- `r_int` and `r_str` would be aliases for the *same* cell.
- Writing an `int` and reading a `string` would crash or print
  arbitrary bytes.
- Value restriction is the type system's refusal to compile
  this program at all.

:::

The restriction can occasionally bite when it does not need to. A
common case is a partial application that *would* be safely
polymorphic, but the syntactic check that implements the rule does
not see that. For example:

```ocaml
let map_id = List.map (fun x -> x)
(* val map_id : '_weak1 list -> '_weak1 list = <fun> *)
```

`map_id` is morally `fun xs -> List.map (fun x -> x) xs`, which
*would* be safely polymorphic. But the RHS of the `let` is a
function *application* (`List.map applied_to_one_arg`), not a
syntactic function *value*, so the restriction kicks in and `'a`
collapses to `'_weak1`.

The standard workaround is to add an explicit parameter, restoring
the right-hand side to the form of a function value:

```ocaml
let map_id xs = List.map (fun x -> x) xs
(* val map_id : 'a list -> 'a list = <fun> *)
```

Now the RHS *is* a function value (`let f x = e` desugars to
`let f = fun x -> e`), and `map_id` gets its full polymorphism
back. Lifting an argument out like this is called *eta-expansion*.
We will not need it again in this course; it is enough to recognise
`'_weak1` and know what it means.

:::slide

## Eta-expansion: when the restriction bites

```ocaml
(* might infer a weak type *)
let map_id = List.map (fun x -> x)
(* val map_id : '_weak1 list -> '_weak1 list = <fun> *)

(* fully polymorphic via eta-expansion *)
let map_id xs = List.map (fun x -> x) xs
(* val map_id : 'a list -> 'a list = <fun> *)
```

- The syntactic check refuses to generalise `map_id` in the first
  form because the RHS is a function *application*, not a function
  *value*.
- Adding an explicit `xs` parameter makes the RHS a function value.
- Lifting an argument out is called *eta-expansion*.
- Recognise `'_weak1` in toplevel output and reach for this fix.

:::

## Where you put `let ref` matters

A small bug whose shape recurs constantly in larger code.

Suppose we want a ticket dispenser: a zero-argument function whose
first call returns `1`, second returns `2`, and so on. A first
attempt:

```ocaml
let dispense_broken () =
  let n = ref 0 in
  incr n;
  !n

let _ = dispense_broken ()  (* = 1 *)
let _ = dispense_broken ()  (* = 1 *)
let _ = dispense_broken ()  (* = 1 *)
```

Expected: `1`, `2`, `3`. Actual: `1` every time.

Trace through one call. The body runs as a fresh evaluation: `let
n = ref 0` allocates a new `ref` cell with value `0`; `incr n`
bumps that cell to `1`; `!n` reads `1` back. The cell was *local*
to this call, so it has nothing to do with any cell from a previous
call. Each call starts over from zero.

The fix is to hoist the `let n = ref 0` *out* of the function so
that the cell is allocated once, when the function is defined, and
the function value closes over it:

```ocaml
let dispense =
  let n = ref 0 in
  fun () ->
    incr n;
    !n

let _ = dispense ()  (* = 1 *)
let _ = dispense ()  (* = 2 *)
let _ = dispense ()  (* = 3 *)
```

Now there is one cell, allocated at definition time, captured by
the closure. Successive calls hit the same cell.

The lesson generalises: a `let` *inside* a function body runs on
every call; a `let` outside, captured by closure, runs once. With
immutable bindings the distinction rarely matters; with `ref` it
decides whether your state survives between calls.

:::slide

## Where you put `let ref` matters: a ticket dispenser

```ocaml
let dispense_broken () =
  let n = ref 0 in        (* fresh cell every call *)
  incr n;
  !n

let _ = dispense_broken ()  (* = 1 *)
let _ = dispense_broken ()  (* = 1 *)
let _ = dispense_broken ()  (* = 1 *)
```

Expected `1; 2; 3`. Actual: `1; 1; 1`.

:::

:::slide

## Hoist the `let ref` out: closure captures one cell

```ocaml
let dispense =
  let n = ref 0 in        (* allocated once, at definition *)
  fun () -> incr n; !n

let _ = dispense ()  (* = 1 *)
let _ = dispense ()  (* = 2 *)
let _ = dispense ()  (* = 3 *)
```

- `let` *inside* the body runs on every call: fresh cell.
- `let` *outside*, captured by closure: one cell, lives across
  calls.
- The distinction is invisible for immutable bindings, decisive
  for `ref`.

:::

## Activity

:::slide

## Activity

Write `make_running_total : unit -> (int -> int)` that returns a
closure. Each call to the closure adds its argument to a running
total and returns the new total. Two calls to
`make_running_total ()` must produce two independent
accumulators.

```text
let add = make_running_total ()
add 5    (* = 5  *)
add 3    (* = 8  *)
add 10   (* = 18 *)
```

:::

:::quiz code id=M07-L01-q1
Write `make_running_total : unit -> (int -> int)` so that each
call adds its argument to a running total and returns the new
total.

```ocaml
let make_running_total () =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let add = make_running_total () in
  check (add 5  = 5)  "first add";
  check (add 3  = 8)  "second add";
  check (add 10 = 18) "third add";
  let other = make_running_total () in
  check (other 1 = 1) "fresh total starts at 0";
  check (add 0  = 18) "original total unaffected";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let make_running_total () =
  let total = ref 0 in
  fun x -> total := !total + x; !total

let add = make_running_total ()
let _ = add 5    (* = 5  *)
let _ = add 3    (* = 8  *)
let _ = add 10   (* = 18 *)
```

- The closure captures `total`; each call updates it and reads
  the new value.
- Same shape as `dispense` earlier, but the closure now takes an
  input each call and folds it into the cell.

:::

:::

:::slide

## Two accumulators have independent state

```ocaml
let a = make_running_total ()
let b = make_running_total ()
let _ = a 1    (* = 1  *)
let _ = a 2    (* = 3  *)
let _ = a 3    (* = 6  *)
let _ = b 10   (* = 10 *)
let _ = b 20   (* = 30 *)
```

- Each call to `make_running_total ()` allocates a fresh `total`,
  captured by a fresh closure.
- `a` and `b` don't share state.

:::

Each call to `make_running_total ()` is a fresh allocation of
`total`, captured by a fresh closure. The two accumulators `a` and
`b` are *independent*: `a`'s `total` and `b`'s `total` are
different cells. This is the same
[closure machinery from functions-as-values](M03-L01-functions-as-values.html),
with the captured value happening to be a mutable cell rather than
an integer.

## What's next

The [next lecture](M07-L02-arrays-and-mutation.html) extends the
mutation toolkit: mutable record fields (the general form `ref`
is the one-field special case of) and *arrays*, the fixed-size
random-access mutable sequence.
[Lecture 3](M07-L03-exceptions.html) covers exceptions, the other
major form of "side effect" in OCaml. Together these three (refs,
arrays, exceptions) give you the imperative subset of the
language. Lectures [4](M07-L04-streams-and-laziness.html) and
[5](M07-L05-memoization.html) take a small detour: *streams*
(infinite data, built lazily) and *memoization* (caching
function results for speed), two techniques that build on the
ref / exception machinery. Lectures
[6](M07-L06-module-basics.html) through
[8](M07-L08-functors.html) then turn to *modules*, the unit of
program structure: how OCaml organizes code at scale, hides
representation, and writes generic data structures via functors.
[Lecture 9](M07-L09-tutorial.html) is the tutorial.

:::slide

## What's next

Lecture 2: **mutable records and arrays**.

- General mutable record fields; `ref` is the one-field special
  case.
- Fixed-size mutable arrays.
- Both are for code that genuinely needs in-place updates.

:::

## Reading

- **Cornell CS3110**, *References*:
  <https://cs3110.github.io/textbook/chapters/mut/refs.html>
- **Real World OCaml**, *Imperative Programming*:
  <https://dev.realworldocaml.org/imperative-programming.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
