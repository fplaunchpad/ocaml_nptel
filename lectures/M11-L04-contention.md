---
title: "Contention: synchronisation at compile time"
lecture_no: 4
week: 11
duration_target_min: 23
concepts: [contention, uncontended, contended, shared, data race, Atomic, mode crossing]
keywords: [OCaml, OxCaml, contention, uncontended, contended, shared, Atomic, mode crossing, data race]
activity_question: "A record has one immutable and one mutable field and is shared between two domains: which accesses does OxCaml reject, and why does even a *read* of the mutable field get refused on a contended value? And can you launder the mutability out by reading an immutable field that holds an array, then writing the array?"
think_about_this: "Module 10 showed that OCaml keeps data races bounded at runtime. Bounded is still surprising, and still hard to reason about. What would the compiler have to track, at the type level, to refuse the racy program outright?"
reading:
  - title: "OxCaml documentation, modes"
    url: https://oxcaml.org/documentation/modes/
  - title: "CS6868 OxCaml handout, Part 2 (KC Sivaramakrishnan)"
    url: https://github.com/kayceesrk/cs6868_s26
---

# Contention: synchronisation at compile time


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Contention: synchronisation at compile time</h2>
<p class="title-slide-label">Module 11 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The first half of this module built the resource story: locality
(stack allocation without escape), uniqueness (safe `free`), and
linearity (no double-`close`). Each axis let the compiler refuse
a program that mishandles a value's lifetime.

This lecture and the next one move to the other half of OxCaml's
safety story: making *concurrency* data-race-free at the type
level.
Vanilla OCaml 5 gives you domains (real OS-thread parallelism) but
no compile-time help with the races those domains can create. The
runtime conventions are familiar from any other parallel language:
do not share a `ref` across domains; if you must share, wrap it in
an `Atomic.t`; remember to lock; remember to unlock on the error
path. Forget any one of these and you have a race that may only
fire under load in production.

The stakes can be lethal. The Therac-25 radiation-therapy machine
(1985-87) gave six patients massive radiation overdoses, several
fatal, and one root cause was a race condition: an experienced
operator who typed a correction fast enough hit a timing window the
developers never imagined, and the machine fired a high-energy beam
with its protective hardware out of position. The defect was
interleaving-dependent, so it passed testing and was for a long
time impossible to reproduce; it surfaced only on the unlucky
schedule. That is precisely the failure mode a compile-time race
check is meant to remove: not "test harder and hope you hit the bad
interleaving," but "the racy program does not compile."

OxCaml closes the gap with two new axes that work as a pair:
**contention** (this lecture) asks how a shared value may be
*accessed*; **portability** (the next lecture) asks whether a
value may *cross* to another domain at all. This lecture builds
the access half: which reads and writes the compiler permits on a
value that other domains can reach, and how atomics make shared
mutation legal again.

:::slide

## A new bug class: cross-domain races

- Memory bugs: M10 closed by GC + types.
- Stack escape, unsafe `free`, double `close`: closed by
  locality, uniqueness, linearity.
- Still open: **data races** across domains.
- Vanilla OCaml 5 ships domains but no compile-time race check.
- This lecture and the next: how OxCaml fixes that, at the type
  level.

:::

:::slide

## Where we are

- M10 defined the data race and left it a runtime hazard.
- M11-L01 to L03: the resource axes. Locality, uniqueness,
  linearity.
- This lecture (M11-L04): **contention**. How a shared value may
  be accessed.
- Next lecture (M11-L05): **portability**. Which values may
  cross a domain boundary.

:::

## Recall: what a data race is

The data-races lecture in the memory-safety module pinned the
definition down precisely, and everything below leans on that
precision, so here it is again. Two memory accesses (each a read
or a write) *race* when:

- they target the **same location**,
- at least **one of them is a write**, and
- **no synchronisation** orders one access before the other: no
  join, no lock, no atomic operation decides which goes first.

That lecture also established what a race *does* in OCaml: the
program stays memory-safe and the damage is bounded. But bounded
behaviour is still surprising behaviour, and still hard to reason
about; the goal now is for races not to happen at all.

A race only bites when the program actually runs in parallel, so
for this module it is convenient to split the same definition
into **four ingredients**: the parallel setting becomes
ingredient 1, and the no-synchronisation condition becomes
ingredient 4. Each piece of OxCaml's concurrency story will
attack one ingredient.

:::slide

## Recall: what a data race is

Two memory accesses **race** when (the memory-safety module's
definition):

- they target the **same location**,
- at least **one is a write**, and
- **no synchronisation** orders them.
  - no join, no lock, no atomic decides who goes first.

- In OCaml a race is *bounded*, not undefined.
  - but bounded is still surprising, and hard to reason about.
- This module's goal: the race never compiles.

:::

:::slide

## Four ingredients of a data race

The definition, split four ways:

1. **Two domains** executing code in parallel.
2. **A shared memory location** accessible by both.
3. **At least one write** (read-read is fine).
4. **Nothing orders the accesses**: no join, no lock, no atomic.

Remove any one ingredient and the race disappears. OxCaml's plan:
attack ingredient 3 with **contention** (this lecture), ingredient
4 with the synchronised type, the atomic (also this lecture), and
ingredient 2 with **portability** (next lecture).

:::

## Two new axes

For data-race freedom, OxCaml adds two mode axes to the three
resource axes you already know. They are designed as a pair, so
we meet both names now, even though this lecture develops only
the first:

- **Contention** tracks whether a value is being accessed by more
  than one domain. Its modes are `uncontended` (the default)
  `⊑ shared ⊑ contended`: `shared` is shared for reads only, and
  `contended` is shared with at least one writer somewhere.
- **Portability** tracks whether a value (usually a function) can
  *cross* a domain boundary. Its modes are
  `portable ⊑ nonportable` (the default). That axis is the next
  lecture's subject.

The division of labour: portability decides what may reach
another domain; contention decides what any domain may do with a
value once it is reachable. This lecture takes the second
question on its own terms.

:::slide

## Two new axes

- **Contention**: is the value accessed by 2+ domains?
  - modes: `uncontended` (default) `⊑ shared ⊑ contended`.
  - `shared` is shared, but reads only.
  - `contended` is shared, with at least one write.
- **Portability**: can the value *cross* a domain boundary?
  - modes: `portable ⊑ nonportable` (default).
  - the next lecture's subject.

This lecture: the contention axis, on its own terms.

:::

## The contention axis

A new wrinkle compared to the resource axes: the same value can
appear at different modes in different contexts. A record is
`uncontended` while it is local to one domain, and becomes
`contended` the moment another domain can reach it. The compiler
tracks the transition; the modes describe the value's current
situation, not its type.

- **`uncontended`** (the default): the value is exclusively
  yours. No other domain has access. You may read and write
  mutable fields freely.
- **`shared`**: the value is shared with other domains, but only
  for read access. You may read but not write any mutable
  field.
- **`contended`**: the value is shared with other domains, and
  somewhere there may be a writer. You may not read or write
  mutable fields at all.

The submoding is `uncontended ⊑ shared ⊑ contended`. A value at
the stronger end can be used at any of the weaker positions.
"Uncontended" is the strongest promise (exclusive access);
"contended" is the weakest (anyone may write at any time).

Two rules govern what code can do with these modes:

**Rule 1: if a value is contended, you cannot read or write its
mutable fields.** The write half is obvious; the read half is the
surprising one, and the cells below make both concrete. It
follows from ingredient 3 of a race: the compiler cannot tell at
the read site whether some other domain is mid-write, so the
conservative answer is to refuse both.

**Rule 2: everything inside a contended value is also
contended.** You cannot extract an uncontended component out of a
contended container. Without this rule, Rule 1 would be trivial
to launder away: read a mutable structure out through an
immutable field, then mutate it as a fresh uncontended value. The
contamination is deep, so the laundering does not typecheck.

:::slide

## The contention axis

| Mode | Meaning | Read mutable field? | Write? |
|---|---|---|---|
| **`uncontended`** | Exclusive access | Yes | Yes |
| **`shared`** | Shared, reads only | Yes | No |
| **`contended`** | Shared, a writer may exist | **No** | No |

Submoding: `uncontended ⊑ shared ⊑ contended`.

- **Rule 1**: contended value: no reads or writes of its mutable
  fields.
- **Rule 2**: everything inside a contended value is also
  contended.

:::

## Rule 1 in action

Let us see the rule on a record with one immutable and one
mutable field:

```ocaml
type mood = Happy | Neutral | Sad
type thing = { price : float; mutable mood : mood }
```

Reading the immutable `price` field from a contended `thing` is
fine: nobody can be racing the read, because the field is not
mutable.

```ocaml
let price_contended (t @ contended) = t.price
(* val price_contended : thing @ contended -> float = <fun> *)
```

Writing the mutable `mood` field, however, is rejected:

```ocaml skip
(* Press Run; the write is rejected. *)
let cheer_up_contended (t @ contended) = t.mood <- Happy
(* Error: This value is "contended" but is expected to be
   "uncontended" because its mutable field "mood" is being
   written. *)
```

And, the surprising one, *reading* the mutable field is also
rejected:

```ocaml skip
(* Press Run; even the read is rejected. *)
let read_mood_contended (t @ contended) = t.mood
(* Error: This value is "contended" but is expected to be "shared"
   or "uncontended" because its mutable field "mood" is being
   read. *)
```

The error is the type system encoding ingredient 3 of a race.
The read of a mutable field on a contended value is exactly
where the racy read goes; the compiler refuses to let it
through.

If you remove the `@ contended` annotation, the value defaults to
`uncontended` and everything compiles as in regular OCaml.

:::slide

## Reads and writes on a contended record

```ocaml
type mood = Happy | Neutral | Sad
type thing = { price : float; mutable mood : mood }

let price_contended (t @ contended) = t.price
(* val price_contended : thing @ contended -> float *)
```

- `price` is immutable. Read it from `contended`: fine.
  - nobody can be racing a read of an immutable field.
- `mood` is mutable: both accesses on the next slide are
  rejected.

:::

:::slide

## Mutable field on `contended`: no write, no read

```ocaml skip
(* Press Run; the write is rejected. *)
let cheer_up_contended (t @ contended) = t.mood <- Happy
```

```ocaml skip
(* Press Run; even the read is rejected. *)
let read_mood_contended (t @ contended) = t.mood
```

- The read rejection is the surprising bit.
  - it encodes ingredient 3: the compiler cannot know another
    domain is not mid-write, so it refuses both.

:::

## Rule 2 in action

Rule 2 closes the laundering loophole. Here is a record whose
only field is *immutable*, but the field holds a (mutable)
array:

```ocaml
type box = { arr : int array }
```

Reading the field from a contended `box` is fine, exactly as
`price` was: the field itself is immutable. But the array you get
out is still the shared array, so it comes out `contended`, and
writing through it is rejected:

```ocaml skip
(* Press Run; the write through the extracted array is rejected. *)
let write_through (b : box @ contended) = b.arr.(0) <- 7
(* Error: This value is "contended" because it is the field "arr"
   of the record ... which is "contended". However, the
   highlighted expression is expected to be "uncontended". *)
```

Read the error: the *array* is contended *because the record it
came from* is contended. Contention is contagious downward
through every component. There is no path from a contended
container to an uncontended part.

:::slide

## Contention is deep

```ocaml
type box = { arr : int array }
```

```ocaml skip
(* Press Run; the write through the extracted array is rejected. *)
let write_through (b : box @ contended) = b.arr.(0) <- 7
```

- `arr` is an immutable field: reading it is allowed.
- But the array comes out **contended** too.
  - everything inside a contended value is contended (Rule 2).
- No laundering mutability out of a shared container.

:::

:::slide

## The middle mode: `shared`

- `shared` is the read-only-share mode.
- Mutable field on `shared`: read **yes**, write **no**.
- The use case: many domains read the same mutable state, with
  writers excluded for the duration.
- Without `shared`, you would have to choose between
  `uncontended` (only one domain) and `contended` (no reads).

A practical example: domains holding a read lock on a shared
cache each see it at `shared`; the lock keeps writers out while
any reader is in.

:::

## Mode crossing on the contention axis

The contention axis is where mode crossing matters most.

- **Immutable types** mode-cross contention. An `int`, a
  `string`, an immutable record, an `Iarray.t`: every domain
  can read them simultaneously, because there is no write
  anywhere. The compiler waves them through at every contention
  mode.
- **`Atomic.t`** mode-crosses contention. The whole point of an
  atomic is to be hammered on by many domains; the runtime
  guarantees serialise the operations. The compiler trusts the
  atomic.
- **Mutable records, `ref`, `Hashtbl.t`**: do *not* mode-cross
  contention. Sharing them means accepting the contention
  discipline.

This is why the standard fix for a parallel counter is
`Atomic.t`: the atomic mode-crosses contention, so the counter
can be read and written from any domain without the compiler
raising an objection. See it live: the same `@ contended` mode
that rejected `t.mood` waves the atomic through. Press Run:

```ocaml
(* The same contended mode that rejected t.mood: the atomic
   passes, for the write and the read alike. *)
let bump (a : int Atomic.t @ contended) = Atomic.incr a
let peek (a : int Atomic.t @ contended) = Atomic.get a
```

The mode-crossing rule
expresses, at the type level, exactly the discipline you would
use at runtime: "use atomics to share state safely." It is also
how the type system attacks race ingredient 4: an atomic
operation *synchronises*, so the accesses through it are ordered
and the definition's third condition cannot hold.

:::slide

## `Atomic.t`: a typed mode-crossing pattern

```ocaml
(* The same contended mode that rejected t.mood: the atomic
   passes, for the write and the read alike. *)
let bump (a : int Atomic.t @ contended) = Atomic.incr a
let peek (a : int Atomic.t @ contended) = Atomic.get a
```

- `Atomic.t` *mode-crosses contention*.
  - the compiler accepts read and write at any contention mode.
- The runtime serialises atomic operations.
  - an atomic operation synchronises: race ingredient 4 falls.

:::

:::slide

## Mode crossing on contention

| Type | Mode-crosses contention? |
|---|---|
| `int`, `string`, immutable records | Yes |
| `Iarray.t` (immutable arrays) | Yes |
| `Atomic.t` | Yes |
| `ref`, mutable record, `Hashtbl.t` | No |

- Immutable data: no write anywhere, so no race anywhere.
  - make your data immutable and the contention axis disappears
    for free.
- `Atomic.t`: the typed pattern for safely shared mutable state.
  - always safe to access, regardless of contention mode.

:::

## Activity

:::quiz mcq id=M11-L04-q1
A record `state = { mutable counter : int; size : int }` is
shared between two domains. Both domains read `state.size`; one
domain also writes `state.counter` while the other reads it.
Which is rejected by OxCaml?

- [ ] Reading `state.size` from a contended `state`.
- [ ] Writing `state.counter` from an uncontended `state`.
- [x] Reading `state.counter` from a contended `state`.
- [ ] Constructing the `state` record.

**Why:** Reading `state.size` is fine even on a contended value
because `size` is immutable; nobody can be racing the read.
Writing `state.counter` is fine from an uncontended value (the
domain has exclusive access). The rejected access is *reading*
`state.counter` from a contended value: `counter` is mutable, and
another domain might be writing to it at the same time. The
contention axis refuses both writes *and* reads of mutable
fields on contended values, which is the surprising rule from
this lecture (Rule 1).
:::

:::quiz mcq id=M11-L04-q2
A record type `box = { arr : int array }` has a single
*immutable* field holding a (mutable) array. You receive
`b : box @ contended`. Reading `b.arr` is allowed, since the
field is immutable. Can you then write `b.arr.(0) <- 7`?

- [ ] Yes: `arr` is an immutable field, so the array came out
      clean.
- [x] No: the extracted array remains contended, so writing is rejected.
- [ ] Yes, but only if no other domain currently holds `b`.
- [ ] No, because reading `b.arr` was already rejected.

**Why:** This is Rule 2: contention is deep. The field read
itself is fine (immutable field, same as `price` earlier), but
the array that comes out is a component of a contended value, so
it is contended too, and Rule 1 then rejects the write. If the
extraction laundered the array back to uncontended, the whole
axis would be trivial to bypass. The compiler's error says
exactly this: the value is contended *because it is the field
`arr` of a contended record*.
:::

:::solution

Q1: reading the *immutable* field of a `contended` value is fine;
reading or writing its *mutable* field is rejected (a `contended`
value may be shared with other domains, so its mutable parts are
off-limits without synchronisation). That is Rule 1.

Q2: Rule 2. The immutable-field read is allowed, but the array it
produces is itself contended (everything inside a contended value
is contended), so the write through it is rejected. There is no
laundering mutability out of a shared container.

:::

## Common pitfalls

**Pitfall 1: "Contended just means shared."** It means shared
*with a possible writer*. The middle mode `shared` is the
read-only share. A value at mode `shared` lets all domains read
its mutable fields but not write them; a value at `contended`
lets nobody touch its mutable fields.

**Pitfall 2: "Reading a mutable field is always safe."** Not on
a contended value. Even reads can race a concurrent write. The
compiler refuses, conservatively, both. If you need read-only
access from multiple domains, mark the value `shared` (or make
the field immutable, which is often the cleaner fix).

**Pitfall 3: "I can extract the mutable part and use it
freely."** Rule 2 says no: every component of a contended value
is contended. An immutable field holding an array, a ref inside
a tuple, a record inside a record: the contention follows the
data all the way down.

**Pitfall 4: "Atomics are exempt, so the axis has a hole."** The
exemption is the point, not a hole. An atomic operation
synchronises (it orders the accesses through it), so the
data-race definition's no-synchronisation condition cannot hold.
Mode crossing is the type-level record of that runtime fact.

:::slide

## What contention buys you

- Race ingredient 3 (mutable read or write) becomes a
  compile-time check, deep through every component.
- `Atomic.t` is the typed pattern for shared mutable state:
  ingredient 4 falls to synchronisation.

The cost is zero at runtime. The benefit is "the program does
not compile" instead of "the program races under load."

:::

## What's next

Contention controls what a domain may do with a value it can
reach. The other half of the story is whether a value can reach
another domain at all: that is **portability**, the next
lecture, where the two axes click together into a two-step
argument that rules data races out at compile time. The module
then closes with the tutorial, which builds a bracketed
resource-management API and attacks it.

:::slide

## What's next

- Lecture 5: **portability**. Which values may cross a domain
  boundary; how the two axes together rule out races.
- Lecture 6: tutorial. A bracketed resource-management API,
  designed, implemented, and attacked.

:::

## Reading

- **OxCaml documentation**, the modes overview:
  <https://oxcaml.org/documentation/modes/>
- **CS6868 OxCaml handout** (KC Sivaramakrishnan), Part 2
  (Modes and Data-Race Freedom):
  <https://github.com/kayceesrk/cs6868_s26>
- **OCaml manual**, *Module `Atomic`*:
  <https://ocaml.org/manual/5.4/api/Atomic.html>

## Sources

The contention-axis rules and their `mood`/`thing` examples and
the deep-contention rule are adapted from the
CS6868 OxCaml handout and slides, Part 2 (the
instructor's own teaching material, freely reusable). The
ingredient-by-ingredient framing of which axis attacks which race
condition is original to this course. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
