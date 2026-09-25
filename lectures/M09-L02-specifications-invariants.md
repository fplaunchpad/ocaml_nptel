---
title: "Specifications and invariants"
lecture_no: 2
week: 9
youtube_id: BAzQSXUPoZw
duration_target_min: 25
concepts: [specification, precondition, postcondition, raises clause, examples clause, abstraction function, representation invariant, rep_ok]
keywords: [OCaml, specification, contract, precondition, postcondition, requires, returns, raises, abstraction function, representation invariant, rep_ok, data abstraction]
activity_question: "An interval type stores a record [{ lo : int; hi : int }] with the representation invariant [lo <= hi]. Write [rep_ok : interval -> interval] that returns its argument when the invariant holds and raises [Failure] otherwise."
think_about_this: "Checking [rep_ok] on every operation can turn an O(1) operation into an O(n) one. Where would you keep the checks, and where would you turn them off? What does your answer assume about where bugs come from?"
reading:
  - title: "Cornell CS3110, Specifications"
    url: https://cs3110.github.io/textbook/chapters/correctness/specifications.html
  - title: "Cornell CS3110, Function Documentation"
    url: https://cs3110.github.io/textbook/chapters/correctness/function_docs.html
  - title: "Cornell CS3110, Module Documentation"
    url: https://cs3110.github.io/textbook/chapters/correctness/module_docs.html
---

# Specifications and invariants


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Specifications and invariants</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous lecture ended on a claim that sounds obvious until
you try to act on it: a test checks code against what the code is
*supposed to do*. The `sort` that returned its input unchanged was
wrong, not because of anything in the code itself, but because of
a sentence that exists outside the code: "`sort xs` is `xs`
arranged in ascending order." The compiler never saw that
sentence. The test `assert (sort [3; 1; 2] = [1; 2; 3])` is that
sentence, translated into something executable.

So before this module reaches for any testing tool, we should ask:
where is "supposed to" written down? What does it look like when
it is written down well? That written-down intent is called a
*specification*, and this lecture is about writing them: first for
functions, where a specification is a contract about inputs and
outputs, and then for data abstractions, where the interesting
intent is *internal*, an invariant the client never sees but every
operation must preserve.

None of this requires a new library. Everything in this lecture is
comments and ordinary OCaml. But it is the load-bearing layer
under everything else in the module: the next lecture derives
*test cases* from specifications, and the property-based testing
lectures turn specification clauses into executable *properties*.

:::slide

## What this lecture covers

- Specifications: the contract between a function and its caller.
- The clauses: *returns*, *requires*, *raises*, *examples*.
- The specification game: how specs fail, and how to tighten them.
- Data abstractions: the **abstraction function** and the
  **representation invariant**.
- `rep_ok`: turning the invariant into checkable code.

:::

## A contract between two parties

A specification is a contract between the *client* of a piece of
code and its *implementer*. The client is whoever calls the
function; the implementer is whoever wrote it. Often both are you,
two weeks apart, which does not make the contract less useful: the
you of today remembers what the function promises, and the you of
two weeks from now will not.

The contract states two kinds of obligation. What the client must
guarantee about the inputs: these are *preconditions*. And what
the implementer must guarantee about the outputs, assuming the
preconditions held: these are *postconditions*.

The payoff of writing the contract down is *blame assignment*.
When something goes wrong, the contract tells you whose bug it is.
If the client passed an input that violates the precondition, the
client is at fault, and no change to the implementation is needed.
If the precondition held and the output still violates the
postcondition, the implementation is at fault. Without a contract,
every bug report starts a negotiation; with one, it starts a
lookup.

In OCaml, specifications conventionally live in documentation
comments, `(** ... *)`, attached to declarations in a module
signature. The client reads the signature; the signature carries
the contract. You saw the mechanics of signatures in the modules
material; this lecture is about what the comments should *say*.

:::slide

## A specification is a contract

- Two parties: the **client** (caller) and the **implementer**.
- **Preconditions**: what the client must guarantee about inputs.
- **Postconditions**: what the implementer must guarantee about
  outputs.
- The payoff is **blame assignment**:
  - precondition violated: the client's bug.
  - precondition held, postcondition violated: the
    implementer's bug.
- Lives in `(** ... *)` comments on the signature.

:::

## The returns clause

The first sentence of a good function spec says what the result
*is*. Not how it is computed, what it *is*. The OCaml convention
is to write the function applied to named arguments, in square
brackets, and then state the result:

```text
(** [index_of x xs] is the position of the first occurrence of
    [x] in [xs], counting from zero. *)
val index_of : 'a -> 'a list -> int
```

This is called the *returns clause*, and it is a postcondition:
given the inputs, it pins down the output. Notice the word "is".
A returns clause is *definitional*: it defines the result in terms
of the inputs. Compare a version you will see in real codebases:

```text
(** Walks down the list, comparing each element against [x],
    incrementing a counter, until it finds a match. *)
```

That is an *operational* description: it narrates the
implementation. It tells the client nothing the implementation
does not already say, it goes stale the moment the implementation
changes, and it does not actually promise anything about the
result. Definitional, not operational, is the single biggest
upgrade you can make to your documentation habits.

A returns clause is often clearer with a concrete example
attached. The *examples clause* costs one line and saves the
client a careful read:

```text
(** [index_of x xs] is the position of the first occurrence of
    [x] in [xs], counting from zero.
    Example: [index_of "b" ["a"; "b"; "c"] = 1]. *)
```

:::slide

## The returns clause

```text
(** [index_of x xs] is the position of the first occurrence
    of [x] in [xs], counting from zero.
    Example: [index_of "b" ["a"; "b"; "c"] = 1]. *)
val index_of : 'a -> 'a list -> int
```

- States what the result **is**, not how it is computed.
  - *Definitional*, not *operational*.
- Operational specs narrate the implementation
  - they promise nothing and go stale.
- An **examples clause** costs one line
  - and disambiguates faster than prose.

:::

## The requires clause

The `index_of` spec above has a hole, and it is exactly the kind
of hole specifications exist to close: what if `x` does not occur
in `xs` at all? The function as specified is *partial*: it is
only meaningful on part of its input space. Every partial
function forces the spec writer to make a decision, and there are
three honest options.

The first option is to *restrict the domain*. Add a *requires
clause*, a precondition, declaring those inputs out of bounds:

```text
(** [index_of x xs] is the position of the first occurrence of
    [x] in [xs], counting from zero.
    Requires: [x] occurs in [xs]. *)
```

Now the contract says: if you call this with an `x` not in `xs`,
anything may happen. An exception, a wrong answer, an infinite
loop; all of it is the *client's* fault, by contract. The
implementer gains freedom and speed (no checking); the client
gains an obligation. This is a reasonable trade exactly when the
client can establish the precondition cheaply.

:::slide

## The requires clause

```text
(** [index_of x xs] is the position of the first occurrence
    of [x] in [xs], counting from zero.
    Requires: [x] occurs in [xs]. *)
```

- A **precondition**: declares some inputs out of bounds.
- If the client violates it, *anything* may happen
  - and it is the client's fault, by contract.
- Implementer gains freedom and speed
  - no defensive checks needed.
- Honest only if the client can actually establish it.

:::

## Raises, or change the type

The second option is to make the function *total* by raising: it
now has defined behaviour on every input, and the spec must say
which exception and when. That is the *raises clause*:

```text
(** [index_of x xs] is the position of the first occurrence of
    [x] in [xs], counting from zero.
    Raises: [Not_found] if [x] does not occur in [xs]. *)
```

Note the obligation this places on the *implementer*: the check
for "not found" must actually happen, in every build, because some
client may rely on catching `Not_found`. A raises clause is a
promise, not a warning.

The third option is the most OCaml-flavoured one, and you have
been using it since the module on data types: *change the type*
so the partiality shows up in the signature itself.

```text
(** [index_of_opt x xs] is [Some i] where [i] is the position of
    the first occurrence of [x] in [xs], or [None] if [x] does
    not occur. *)
val index_of_opt : 'a -> 'a list -> int option
```

Now the "missing" case is not a comment; it is a constructor. The
client cannot forget it, because pattern-match exhaustiveness
will not let them. This is the standard library's own resolution:
`List.find` raises, `List.find_opt` returns an option, and the
pair of them is the raises-versus-types decision offered as a
menu. The spec comment does not disappear (you still must say
*which* occurrence and *what* counting convention), but one
clause of it has migrated into the type checker's jurisdiction.

:::slide

## Three ways to handle a partial function

1. **Requires clause**: declare bad inputs out of bounds.
   - Fast, free to implement, burdens the client.
2. **Raises clause**: total function, documented exception.
   - `Raises: [Not_found] if [x] does not occur in [xs].`
   - The check must really happen; clients may rely on it.
3. **Change the type**: return an `option`.
   - The missing case becomes a constructor.
   - Exhaustiveness checking enforces what a comment cannot.
- The stdlib offers the menu: `List.find` vs `List.find_opt`.

:::

## The specification game

How do you know whether a spec you wrote is any good? CS3110
teaches a game for this, played between a *specifier* and a
*devious implementer*. The implementer's goal is to satisfy the
letter of the spec while being as unhelpful as possible. Every
move the implementer makes exposes a hole; the specifier patches
the hole; repeat. Recall the deduplication function from the
previous lecture's activity, and watch the game run.

**Round 1.** The specifier writes:

```text
(** [dedup xs] returns a list. *)
val dedup : 'a list -> 'a list
```

The devious implementer answers `let dedup _ = []`. It returns a
list. Contract satisfied; client betrayed.

**Round 2.** The specifier patches:

```text
(** [dedup xs] returns a list containing no duplicates. *)
```

The implementer does not even need to change anything: `[]`
contains no duplicates. (Vacuously, like every property of the
elements of an empty list.)

**Round 3.** The specifier patches again:

```text
(** [dedup xs] returns a list containing exactly the distinct
    elements of [xs], each exactly once. *)
```

Now `[]` is ruled out, as is the identity function (when `xs`
has duplicates). The devious implementer has one move left:
return the right elements in a strange *order*, say reversed, or
sorted. Is that a bug? The spec does not say. And here the game
teaches its subtlest lesson: this is a *choice*, not
automatically a hole. If the specifier does not care about
order, leaving it open is good practice; it keeps the spec
*sufficiently general* and lets the implementer pick the fastest
strategy (sorting, hashing). If the client needs first-occurrence
order, the specifier must say so:

```text
(** [dedup xs] is the list of distinct elements of [xs], in
    order of first occurrence.
    Example: [dedup [2; 1; 2; 3] = [2; 1; 3]]. *)
```

A good specification balances two pressures: *sufficiently
restrictive*, so useless implementations are ruled out, and
*sufficiently general*, so useful ones are not. The game finds
the first kind of failure; only thinking about real clients finds
the second.

:::slide

## The specification game

- A **specifier** writes the spec; a **devious implementer**
  satisfies its letter while betraying its intent.

| Spec | Devious move |
| --- | --- |
| "returns a list" | `let dedup _ = []` |
| "... with no duplicates" | `[]` still qualifies |
| "... exactly the distinct elements of `xs`" | reversed order |

- Final: "distinct elements of `xs`, in order of first
  occurrence. Example: `dedup [2; 1; 2; 3] = [2; 1; 3]`."

:::

:::slide

## What the game teaches

- Every devious move is a **hole in the spec**, found before a
  real bug finds it.
- But not every freedom is a hole:
  - unspecified order can be a *deliberate* generality,
  - it lets the implementer pick the fastest strategy.
- Good specs balance two pressures:
  - **sufficiently restrictive**: useless implementations are
    ruled out.
  - **sufficiently general**: useful ones are not.

:::

## Data abstractions: where the contract gets interesting

For a single function, the contract talks about inputs and
outputs, and that is the whole story. For a *data abstraction*, a
module exporting an abstract type and operations on it, there is
more to say, because the most important facts are ones the client
*cannot see*.

Recall the shape from the modules material: a signature declares
`type t` without a definition, and the structure picks a concrete
representation the client never learns. Here is the running
example for the rest of this lecture, an abstraction for rational
numbers:

:::slide

## A data abstraction: rationals

```ocaml
module type RATIONAL = sig
  type t
  (** [make p q] is p/q.
      Raises [Invalid_argument] if [q = 0]. *)
  val make : int -> int -> t

  (** [add r1 r2] is r1 + r2. *)
  val add : t -> t -> t

  (** [div r1 r2] is r1 / r2.
      Raises [Failure] if [r2] is zero. *)
  val div : t -> t -> t

  (** [equal r1 r2] is whether r1 equals r2. *)
  val equal : t -> t -> bool

  (** [to_string r] is r rendered as ["p/q"]. *)
  val to_string : t -> string
end
```

- `type t` is abstract: the client sees the contract, never the
  representation.

:::

The obvious representation is a pair of integers, the numerator
and the denominator. Here is a first implementation:

:::slide

## A first implementation

```ocaml
module Rational : RATIONAL = struct
  (* AF: (p, q) represents the rational p/q.
     RI: q <> 0. *)
  type t = int * int
  let make p q =
    if q = 0 then invalid_arg "make" else (p, q)
  let add (p1, q1) (p2, q2) =
    ((p1 * q2) + (p2 * q1), q1 * q2)
  let div (p1, q1) (p2, q2) = (p1 * q2, q1 * p2)
  let equal (p1, q1) (p2, q2) = p1 * q2 = p2 * q1
  let to_string (p, q) =
    string_of_int p ^ "/" ^ string_of_int q
end
```

- The two comment lines at the top, `AF` and `RI`, are the
  subject of the rest of this lecture.

:::

It behaves the way the contract promises:

```ocaml
let half = Rational.make 1 2
let third = Rational.make 1 3
let _ = Rational.to_string (Rational.add half third)  (* = "5/6" *)
```

The representation is `int * int`. But the moment we pick it, two
questions appear that the function-spec vocabulary cannot answer.

First: *what does a concrete value mean?* The pair `(1, 2)` is
just two integers; we intend it as the rational one-half. Is
`(2, 4)` also one-half? Is `(3, 0)` anything at all?

Second: *which concrete values are legal?* If `(3, 0)` is
nonsense (there is no rational 3/0), then every operation in the
module must avoid ever *creating* it, and may *assume* it never
receives it. That assumption is invisible in the types: the type
of the representation is `int * int`, and `(3, 0)` inhabits it
happily.

These two questions have names, and writing down their answers is
the module-level analogue of writing a function spec.

## The abstraction function

The *abstraction function* (AF) answers the first question: it
maps each concrete representation value to the abstract value it
stands for. It is written as a comment on the representation
type, because it is for the implementer and maintainer, not the
client. In `Rational` it reads: "(p, q) represents the rational
number p/q."

Two properties of the abstraction function deserve attention,
because both have consequences you can observe from the client
side.

The AF is *many-to-one*. The pairs `(1, 2)`, `(2, 4)`, and
`(3, 6)` all represent one-half. That is why the signature
insists on an `equal` operation: the built-in `=` on the
representation would call `(1, 2)` and `(2, 4)` different, but
as rationals they are the same value, and `equal` (by
cross-multiplication: `p1 * q2 = p2 * q1`) agrees:

```ocaml
let _ = Rational.equal half (Rational.make 2 4)  (* = true *)
```

The AF is *partial*. The pair `(3, 0)` maps to nothing; there is
no such rational. Which brings us to the second question.

:::slide

## The abstraction function

```text
concrete (int * int)            abstract (rationals)

(1, 2)   (2, 4)   (3, 6)   ──▶   1/2
(0, 1)   (0, 7)            ──▶   0
(1, 0)   (3, 0)            ──▶   nothing (no such rational)
```

- AF maps each representation to the value it *means*.
- **Many-to-one**: several representations, one abstract value.
  - So `=` on the representation is wrong; the module must
    provide `equal`.
- **Partial**: some representations mean nothing at all.
  - Those are outlawed by the *representation invariant*.

:::

## The representation invariant

The *representation invariant* (RI) answers the second question:
it is the predicate that separates legal representations from
illegal ones. For `Rational`, the RI is one clause: `q <> 0`.

The RI is a contract too, but an *internal* one, among the
operations of the module. Every operation may **assume** the RI
holds of any `t` it receives, and must **guarantee** the RI
holds of any `t` it creates. If both halves hold for every
operation, then no client, composing operations from outside,
can ever get their hands on an illegal value. The proof is an
induction over the client's program, but the intuition is
enough: legal values in, legal values out, forever.

The assume half is what makes the RI *useful*: `add` does not
check its arguments for zero denominators, and it does not need
to, because no legal `t` has one. The guarantee half is what
makes the RI *true*: `make` rejects `q = 0` at the boundary, and
each operation must produce only legal pairs.

This is also why the type being *abstract* matters so much. If
the signature exposed `type t = int * int`, a client could write
`(3, 0)` directly, no operation would ever have rejected it, and
every function in the module would now be wrong through no fault
of its own. Abstraction is what gives the module a boundary at
which the invariant can be enforced. You met this idea as
"encapsulation" in the modules material; the RI is the precise
statement of *what* the encapsulation is protecting.

:::slide

## The representation invariant

- The predicate separating **legal** representations from
  illegal ones.
  - For `Rational`: `q <> 0`.
- An internal contract among the module's operations:
  - **assume**: every `t` received satisfies the RI.
  - **guarantee**: every `t` created satisfies the RI.
- Both halves hold ⇒ clients can never reach an illegal value.
- Abstraction is the enforcement boundary:
  - expose `type t = int * int` and the RI is unenforceable.

:::

## `rep_ok`: the invariant as code

An invariant in a comment is a promise; an invariant in code is a
check. The convention, taken from CS3110, is a function `rep_ok`
that returns its argument unchanged if the RI holds and raises
otherwise. Here is `Rational` again with the check threaded
through every operation that creates a representation value:

:::slide

## `rep_ok`: the invariant as code

```ocaml
module Rational : RATIONAL = struct
  type t = int * int
  let rep_ok ((_, q) as r) =
    if q = 0 then failwith "RI violated" else r
  let make p q =
    if q = 0 then invalid_arg "make" else rep_ok (p, q)
  let add (p1, q1) (p2, q2) =
    rep_ok ((p1 * q2) + (p2 * q1), q1 * q2)
  let div (p1, q1) (p2, q2) = rep_ok (p1 * q2, q1 * p2)
  let equal (p1, q1) (p2, q2) = p1 * q2 = p2 * q1
  let to_string (p, q) = Printf.sprintf "%d/%d" p q
end
```

- `rep_ok` wraps every spot where a representation is **born**.

:::

The shape is worth memorising: identity function, applied at
every point where a new representation value is born. It costs
one line per operation and it converts a silent corruption into
a loud failure *at the moment of corruption*.

To see what that buys, look closely at `div`. It computes
`(p1 * q2, q1 * p2)`. Perfectly correct, except for one input:
dividing by the rational *zero*. If `r2` is `(0, 5)`, the result
denominator is `q1 * 0 = 0`, an illegal value. The fault is in
`div` (its spec said `Raises: Failure if r2 is zero`, and this
implementation forgot to check). Watch `rep_ok` catch it:

:::slide

## A bug `rep_ok` catches early

```text
let div (p1, q1) (p2, q2) = rep_ok (p1 * q2, q1 * p2)
```

```ocaml skip
let zero = Rational.make 0 5
let half = Rational.make 1 2
let _ = Rational.div half zero  (* Failure "RI violated" *)
```

- The buggy `div` forgot its divide-by-zero check.
  - Without `rep_ok`: silent `(2, 0)`, failure surfaces far
    away, in `to_string` or `equal`.
  - With `rep_ok`: the failure lands in the same stack frame
    as the fault.

:::

Recall the faults-versus-failures vocabulary from the previous
lecture. Without `rep_ok`, the fault stays silent: `div` returns
`(2, 0)`, the client passes it onward, and the *failure* finally
surfaces three calls later, in `to_string` output like `"2/0"`,
or in an `equal` that returns nonsense, far from the fault. With
`rep_ok`, the failure happens inside `div`, in the same stack
frame as the fault. The invariant check is a fault-localisation
device: it cannot fix the bug, but it tells you whose stack
frame it died in.

(The correct `div`, for the record, checks `p2 = 0` and raises
`Failure "div: divide by zero"` as its spec promises. The point
here is what happens on the day you forget.)

## Strengthening the invariant: canonical form

The RI is not handed down; the implementer *chooses* it, and the
choice is a real design decision with observable consequences.
Our `Rational` keeps the weak invariant `q <> 0` and pays for it
elsewhere: `equal` must cross-multiply, and `to_string` happily
prints `"2/4"`, which a client comparing strings might not
expect.

The alternative is to *strengthen* the RI to demand a canonical
form: the fraction is always in lowest terms, and the
denominator is always positive. Two helpers do the work. `norm`
maps a pair with a nonzero denominator to its canonical
representative, provided the intermediate integer calculations fit;
`canon_ok` is this representation's `rep_ok`,
written outside the module so it fits beside `norm` on one
slide:

:::slide

## Canonical form: `norm` does the work

```ocaml
let rec gcd a b = if b = 0 then a else gcd b (a mod b)

let norm (p, q) =
  let s = if q < 0 then -1 else 1 in
  let g = gcd (abs p) (abs q) in
  (s * p / g, s * q / g)

let canon_ok ((p, q) as r) =
  if q > 0 && gcd (abs p) q = 1 then r
  else failwith "RI violated: not canonical"

let _ = norm (2, 4)   (* = (1, 2) *)
let _ = norm (1, -2)  (* = (-1, 2) *)
```

- Lowest terms via `gcd`; the sign migrates to the numerator.
- `canon_ok` is `rep_ok` for the new, stronger invariant.

:::

These teaching implementations use machine `int`s. Their arithmetic
specifications assume all inputs and intermediate calculations fit,
including the absolute values and sign changes in `norm`. For
example, `norm (1, min_int)` overflows when negating the denominator;
it remains negative, and `canon_ok` rejects it. Normalisation cannot
repair overflow. Unrestricted rational arithmetic would require
arbitrary-precision integers.

The module itself then pipes every producer through
`canon_ok (norm ...)`:

:::slide

## Canonical form: normalise at birth

```ocaml
module Rational_canon : RATIONAL = struct
  (* AF: (p, q) is p/q.  RI: q > 0, lowest terms. *)
  type t = int * int
  let make p q =
    if q = 0 then invalid_arg "make"
    else canon_ok (norm (p, q))
  let add (p1, q1) (p2, q2) =
    canon_ok (norm ((p1 * q2) + (p2 * q1), q1 * q2))
  let div (p1, q1) (p2, q2) =
    if p2 = 0 then failwith "div: divide by zero"
    else canon_ok (norm (p1 * q2, q1 * p2))
  let equal (r1 : t) (r2 : t) = r1 = r2
  let to_string (p, q) = Printf.sprintf "%d/%d" p q
end
```

- Every producer pipes its result through `norm`.

:::

```ocaml
let c = Rational_canon.make 2 4
let _ = Rational_canon.to_string c  (* = "1/2" *)
let _ = Rational_canon.equal (Rational_canon.make 1 2) c  (* = true *)
```

A valid representation can still hold the wrong answer. For
example, adding `Rational_canon.make max_int 1` and
`Rational_canon.make 1 1` produces `min_int/1`. It satisfies the RI,
but is mathematically wrong. This call violates our no-overflow
assumption; the invariant check alone cannot detect that violation.

Look at what moved. The work migrated into `norm`, which every
producer now calls; in exchange, `equal` collapsed to the
built-in `=` (each abstract value now has exactly *one*
representation, so structural equality is abstract equality),
and `to_string` prints what a human expects. The AF became
one-to-one. The same external contract, the `RATIONAL`
signature, is satisfied by both modules; the client cannot tell
which one they are using except by performance. That is
abstraction doing its job.

Neither choice is "right". The weak RI does less work per
operation; the strong RI makes observation and comparison
trivial. What is *not* optional is writing the choice down,
because every operation in the module is written against it.

:::slide

## Strengthening the RI: canonical form

- Weak RI (`q <> 0`): cheap ops, but
  - `equal` must cross-multiply,
  - `to_string` prints `"2/4"`.
- Strong RI (`q > 0`, lowest terms): every producer calls
  `norm`, and
  - `equal` is just `=` (one representation per value),
  - `to_string (make 2 4) = "1/2"`.

```ocaml
let c = Rational_canon.make 2 4
let _ = Rational_canon.to_string c  (* = "1/2" *)
```

- Same signature, same client-visible contract, different
  internal deal.
- The RI is a **design choice**; writing it down is not optional.

:::

## Specifications are what tests check

Step back and look at what this lecture actually built, because
the rest of the module stands on it. Every clause of a
specification is an obligation, and every obligation is something
a test can check:

- A *returns clause* plus an *examples clause* hand you concrete
  test cases nearly verbatim: `index_of "b" ["a"; "b"; "c"] = 1`
  wants to be an assertion.
- A *raises clause* is a negative test: call it with the bad
  input, assert that exactly the promised exception comes out.
- A *requires clause* tells you which inputs *not* to waste tests
  on, and warns you that nothing is promised there.
- A *representation invariant* is a property every operation must
  preserve; `rep_ok` is the checking code, and a test suite can
  hammer the module with operations while `rep_ok` stands guard.

The next lecture asks the question this one leaves open: the spec
tells you what to check, but the input space is astronomically
large; *which inputs* do you actually try? And when we reach
property-based testing, the specification returns in executable
form: a QCheck property is a postcondition that a machine checks
on hundreds of random inputs.

:::slide

## Specifications are what tests check

| Spec clause | Test obligation |
| --- | --- |
| Returns + examples | concrete assertions, nearly verbatim |
| Raises | negative tests: bad input, expected exception |
| Requires | inputs *not* to test; nothing promised there |
| Rep invariant | property preserved by every operation; `rep_ok` |

- Next lecture: the input space is astronomical;
  *which inputs do you try?*

:::

## Activity

:::quiz mcq id=M09-L02-q1
A specifier writes: "`[dedup xs]` returns a list containing no
duplicates." Which devious implementation satisfies this
specification while being useless?

- [ ] `let dedup xs = xs`
- [x] `let dedup _ = []`
- [ ] `let dedup xs = List.rev xs`
- [ ] None: the specification already pins down the behaviour.

**Why:** the empty list contains no duplicates, vacuously, so
`let dedup _ = []` satisfies the letter of the spec for every
input. The identity and `List.rev` do *not* satisfy it: when
`xs` contains duplicates, both return a list that still has
them. The spec's hole is that it never requires the result to
contain the elements of `xs`; the patched version reads
"exactly the distinct elements of [xs]", and a fully pinned
version also fixes the order.
:::

:::quiz mcq id=M09-L02-q2
A module represents rationals as `int * int` with this
documented invariant: "RI: the denominator is positive and the
fraction is in lowest terms." Which concrete value *satisfies*
the representation invariant?

- [ ] `(2, 4)`
- [ ] `(1, -2)`
- [x] `(-1, 2)`
- [ ] `(5, 0)`

**Why:** `(-1, 2)` has a positive denominator and
`gcd 1 2 = 1`, so it is in lowest terms; the sign living in the
numerator is exactly what the canonical form prescribes.
`(2, 4)` is not in lowest terms (`gcd 2 4 = 2`); `(1, -2)` has
a negative denominator; `(5, 0)` is not a rational at all. Note
what the exercise demonstrates: checking the RI requires *only*
the value and the documented invariant, never the operations.
That is why `rep_ok` is easy to write and worth writing.
:::

:::quiz code id=M09-L02-q3
An interval type stores a record `{ lo : int; hi : int }` with
the representation invariant `lo <= hi`. Write
`rep_ok : interval -> interval` in the CS3110 style: return the
argument unchanged when the invariant holds, raise `Failure`
(with any message) when it does not.

```ocaml
type interval = { lo : int; hi : int }

(* RI: lo <= hi *)
let rep_ok (i : interval) : interval =
  failwith "not implemented"
```

```ocaml skip
let () =
  assert (rep_ok { lo = 1; hi = 3 } = { lo = 1; hi = 3 });
  assert (rep_ok { lo = 2; hi = 2 } = { lo = 2; hi = 2 });
  assert (try ignore (rep_ok { lo = 3; hi = 1 }); false
          with Failure _ -> true);
  assert (try ignore (rep_ok { lo = 0; hi = -1 }); false
          with Failure _ -> true);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type interval = { lo : int; hi : int }

(* RI: lo <= hi *)
let rep_ok (i : interval) : interval =
  if i.lo <= i.hi then i else failwith "RI violated: lo > hi"
```

The boundary case `lo = hi` (an empty-width interval like
`{ lo = 2; hi = 2 }`) satisfies `lo <= hi` and must pass; if you
wrote `<` instead of `<=`, the second assertion catches it. The
shape is always the same: test the documented predicate, return
the value, raise on violation.

:::

## Common pitfalls

**Pitfall 1: operational specs.** "Walks the list comparing each
element" narrates the implementation; it promises nothing and
goes stale on the first rewrite. Write what the result *is*.

**Pitfall 2: copying the signature's specs into the
implementation.** The structure should not repeat the `(** ... *)`
comments from the signature. Two copies drift apart, and the
drifted copy is a trap for the next maintainer. The
implementation's own comments are for the AF, the RI, and
algorithm notes: the things the signature cannot say.

**Pitfall 3: preconditions the client cannot check.** "Requires:
`xs` is sorted" is fine; the client can sort or can know it
sorted. "Requires: the result will be used responsibly" is not a
precondition, it is a wish. If you cannot state the requires
clause as a predicate on the arguments, it does not belong in
the contract.

**Pitfall 4: a spec that is silent on the boundary.** What does
`index_of` do on the empty list? What does `dedup` do on `[]`?
If the spec does not say, the implementer will decide by
accident, and the client will discover the decision in
production. The next lecture turns this observation into a
test-design method: the boundaries the spec mentions, and the
ones it forgot, are exactly where test cases earn their keep.

**Pitfall 5: `rep_ok` that never comes off.** A linear-time
`rep_ok` wrapped around every constant-time operation changes
the module's complexity class. The CS3110 convention is to keep
the expensive check during development and debugging, and swap
in a cheap or identity version for production, *keeping the
expensive code in the file* so it can be reinstated the day a
representation bug is suspected.

:::slide

## Common pitfalls

1. **Operational specs**: narrate the implementation, promise
   nothing.
2. **Copied specs**: signature comments duplicated in the
   structure drift apart.
3. **Uncheckable preconditions**: a requires clause must be a
   predicate on the arguments.
4. **Silent boundaries**: if the spec doesn't say what happens
   on `[]`, the implementer decides by accident.
5. **Permanent `rep_ok`**: an O(n) check on an O(1) op changes
   the complexity class; keep it swappable, not deleted.

:::

## What's next

The specification says what to check. The
[next lecture](M09-L03-test-design.html) confronts the question
that makes testing a craft rather than a chore: the input space
of even a tiny function is astronomically larger than any test
suite, so *which inputs do you choose*? The answer has two
halves: read the boundaries out of the specification (black-box
testing), and read the paths out of the implementation
(glass-box testing). The clauses you learned to write today,
including the boundaries your spec mentions and the requires
clauses it imposes, are exactly the raw material the choosing
works from.

:::slide

## What's next

- The spec says *what* to check; the input space is
  astronomical.
- L3: **designing test cases**.
  - Black-box: boundaries and partitions, read from the spec.
  - Glass-box: paths, read from the implementation.
  - Coverage: measuring what your suite actually exercised.

:::

## Reading

- **Cornell CS3110**, *Specifications*:
  <https://cs3110.github.io/textbook/chapters/correctness/specifications.html>
- **Cornell CS3110**, *Function Documentation*:
  <https://cs3110.github.io/textbook/chapters/correctness/function_docs.html>
- **Cornell CS3110**, *Module Documentation* (abstraction
  functions and representation invariants):
  <https://cs3110.github.io/textbook/chapters/correctness/module_docs.html>

## Sources

This lecture's prose, worked examples, and quizzes are original
to this course. Cornell CS3110's chapters on specifications,
function documentation, and module documentation are the
primary conceptual sources for the clause vocabulary, the
specification game, and the AF/RI/`rep_ok` discipline; CS3110's
prose is CC BY-NC-ND licensed and has not been derivatively
reused. The rational-number data abstraction is a standard
teaching example; the `Rational` modules, the `dedup`
specification game instance, and the interval activity are this
course's own. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
