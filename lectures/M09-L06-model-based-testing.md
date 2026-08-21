---
title: "Model-based testing of stateful data structures"
lecture_no: 6
week: 9
duration_target_min: 25
concepts: [model-based testing, stateful testing, reference implementation, command sequences, observable equivalence, queue, PBT for state]
keywords: [OCaml, QCheck, model-based testing, reference implementation, command, stateful, queue, hash table, association list, observable equivalence]
activity_question: "You are handed a hash table module with [add : t -> int -> string -> unit], [find : t -> int -> string option], [remove : t -> int -> unit], and [size : t -> int]. Sketch the model-based harness: the [command] type, the reference implementation, and the observations. Why is an association list the right reference?"
think_about_this: "If your reference implementation is the *spec* (because it is so simple it is obviously correct), what kind of property are you actually checking? Is model-based testing a form of refinement checking? What is the relationship to formal specifications?"
reading:
  - title: "QCheck-STM: stateful model-based testing"
    url: https://github.com/ocaml-multicore/multicoretests
  - title: "Cornell CS3110, Randomized testing with QCheck"
    url: https://cs3110.github.io/textbook/chapters/correctness/randomized.html
  - title: "John Hughes, Experiences with QuickCheck (2016)"
    url: https://publications.lib.chalmers.se/records/fulltext/232550/local_232550.pdf
---

# Model-based testing of stateful data structures


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Model-based testing of stateful data structures</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[Lecture 5](M09-L05-property-based-testing.html) developed
property-based testing on *pure* functions: a list reversal, a
sort. The properties were statements
about a single function call: "for every input `xs`, `rev (rev
xs) = xs`." No state. No mutation. No sequence of calls. Just
input goes in, output comes out, property holds.

Most of real software is not like that. A queue is *stateful*:
what `dequeue` returns depends on every `enqueue` and `dequeue`
that came before it. A hash table is stateful: the result of
`find` depends on every previous `add` and `remove`. A file
handle is stateful. A database is stateful. The entire OS is
stateful. And the property "for every input, the output is
correct" no longer obviously applies, because there is no
single input; there is a *history*.

This lecture shows how to extend PBT to stateful code. The
technique is *model-based testing*: write a simple, obviously-
correct reference implementation (often a list or a sorted
list); generate random sequences of operations; run each
sequence against both your sophisticated implementation and the
reference; assert observable equivalence at every step.

If your real implementation is correct, the test passes for any
operation sequence. If it has a bug, some sequence triggers a
divergence between the two implementations, and QCheck shrinks
that sequence to the smallest one that still diverges. The
result is a tiny reproducer for a stateful bug, which is what
you need to debug it.

:::slide

## What this lecture covers

- **The state problem**: PBT for stateful code is harder than
  PBT for pure code.
- **Model-based testing**: test a sophisticated impl against a
  simple reference, on random sequences of operations.
- A worked example: a mutable two-list queue tested against a
  plain-list reference.
- The shrinker: how QCheck minimises *operation sequences*, not
  just data.
- When this scales: stateful libraries, parallel algorithms,
  protocol implementations.

:::

## The state problem

We have a function. We want to test it. The
[property-based testing recipe](M09-L05-property-based-testing.html)
says: generate a random input, run the function, check a
property of the output. For `sort`, that is

```text
QCheck.Test.make QCheck.(list int)
  (fun xs ->
     let ys = sort xs in
     is_sorted ys && same_elements xs ys)
```

One generated input, one call, one property. Done.

Now we have a queue of `int`s, with this interface:

```text
create  : unit -> queue
enqueue : queue -> int -> unit
dequeue : queue -> int option
size    : queue -> int
```

What is the *input* we generate? A single call to `enqueue`
does not test much; the interesting behaviour is in the
*interaction* between `enqueue` and `dequeue` over a sequence
of calls: what comes out, and in what order, depends on
everything that went in.

What is the *property*? "The queue is correct" is not a
property; it is a paragraph. We need something concrete. And
the natural concrete thing is: *the queue behaves the same as a
much simpler, obviously-correct implementation of the same
interface*.

The PBT shape stays the same: generate a random "input" (now a
*sequence of operations*), run the function (now a *function
sequence*), check a property (now *observable equivalence* with
the reference at each step). It is the same idea applied at a
higher level.

:::slide

## The state problem

A pure function:

```text
input -> output -> check property
```

A stateful API:

```text
   sequence of operations
-> sequence of outputs
-> check equivalence with reference at each step
```

Same PBT shape, lifted to sequences and references.

:::

## The recipe in five steps

Model-based testing has a fixed structure. The five pieces:

1. **A representation of operations as data.** Define a
   variant type `command` whose constructors mirror the
   public API of the data structure under test. `Enqueue of
   int`, `Dequeue`, `Size`.

2. **A generator for `command list`.** Use QCheck combinators
   to produce random sequences of commands. Make sure the mix
   is interesting (e.g. enough `Dequeue`s that the queue
   sometimes drains empty, enough `Enqueue`s that it sometimes
   grows long).

3. **Two interpreters.** A function `run_real : queue -> command
   -> observation` and `run_ref : model -> command -> observation`.
   Each takes the (possibly mutable) state, applies the
   command, and returns whatever the operation observably
   produced (the result of `dequeue`, the new size, ...).

4. **A property.** Given a `command list`, run it through both
   interpreters in lockstep; check that at every step, both
   produce the same observation. If any step diverges, the
   property fails and that sequence is the bug.

5. **A shrinker.** Attach QCheck's list shrinker to the
   command list. When a failing sequence is found, the
   shrinker tries to delete commands, simplify their arguments,
   and find the *smallest* sequence that still diverges.

The five pieces are all the model-based testing you need. Once
you have them, the test is one line.

:::slide

## The recipe

1. Define `command` as a variant.
2. Write a generator for `command list`.
3. Write two interpreters: `run_real` and `run_ref`.
4. Property: equivalent at every step.
5. Let QCheck shrink the failing sequence.

:::

## A worked example: a two-list queue

Concretely: we test a *two-list queue* against a reference
implementation built from a single `int list`. The two-list
queue is a classic: you met its persistent cousin in
[the modules tutorial](M07-L09-tutorial.html), as a functor.
Here it returns in mutable clothing, as a *test subject*.

### Under test: the two-list queue

The idea: keep two lists in mutable fields. `front` holds the
elements about to leave, oldest at the head; `back` holds the
recent arrivals, newest at the head. `enqueue` conses onto
`back` (constant time). `dequeue` takes the head of `front`;
when `front` runs dry, it *reverses* `back` into `front` and
clears `back`. Each element is moved at most once, so the cost
is constant amortised.

```ocaml
type queue = {
  mutable front : int list;   (* next to leave, oldest first *)
  mutable back : int list;    (* arrivals, newest first *)
}

let create () = { front = []; back = [] }

let enqueue q x = q.back <- x :: q.back

let dequeue q =
  match q.front with
  | x :: rest -> q.front <- rest; Some x
  | [] ->
    match List.rev q.back with
    | [] -> None
    | x :: rest ->
      q.front <- rest;
      q.back <- [];
      Some x

let size q = List.length q.front + List.length q.back
```

Twenty lines of mutable state with one delicate moment: the
refill, where `dequeue` must reverse `back`, install the tail
as the new `front`, clear `back`, and hand out the head, all in
the right order. Plenty of room for a bug. The *reference*
implementation (`m_` for *model*) looks like this:

```ocaml
type model = int list ref   (* head of the list = front of the queue *)

let m_create () : model = ref []

let m_enqueue q x = q := !q @ [x]

let m_dequeue q =
  match !q with
  | [] -> None
  | x :: rest -> q := rest; Some x

let m_size q = List.length !q
```

Eight lines of substance. The queue *is* a list; `m_enqueue`
appends at the far end, `m_dequeue` takes the head. *Obviously*
correct, at the price of `m_enqueue` walking the whole list. The
reference does not need to be fast, it does not need to scale,
it only needs to be unambiguously correct.

This is the heart of model-based testing: the reference is the
spec, written in code. Anything more complex than the reference
is something to test *against* the reference.

:::slide

## Under test: the two-list queue

```ocaml
type queue = {
  mutable front : int list;   (* next to leave *)
  mutable back : int list;    (* newest first *)
}

let create () = { front = []; back = [] }
let enqueue q x = q.back <- x :: q.back
let size q = List.length q.front + List.length q.back
```

- `enqueue` conses onto `back`: constant time.
- `dequeue` (next slide) serves from `front`.

:::

:::slide

## `dequeue` and the refill

```ocaml
let dequeue q =
  match q.front with
  | x :: rest -> q.front <- rest; Some x
  | [] ->
    match List.rev q.back with
    | [] -> None
    | x :: rest ->
      q.front <- rest;
      q.back <- [];
      Some x
```

- `front` empty: reverse `back` into `front`, clear `back`.
- The delicate moment; plenty of room for a bug.

:::

:::slide

## The reference: the queue *is* a list

```ocaml
type model = int list ref   (* head = front of the queue *)

let m_create () : model = ref []
let m_enqueue q x = q := !q @ [x]
let m_dequeue q =
  match !q with
  | [] -> None
  | x :: rest -> q := rest; Some x
let m_size q = List.length !q
```

- Slow (`m_enqueue` walks the whole list), obviously correct.
- The reference is the spec; the fast impl is what we ship.
- Bug => divergence under some operation sequence.

:::

### Step 1: commands as data

:::slide

## Step 1: commands as data

```ocaml
type command =
  | Enqueue of int
  | Dequeue
  | Size

let command_to_string = function
  | Enqueue x -> Printf.sprintf "Enqueue %d" x
  | Dequeue -> "Dequeue"
  | Size -> "Size"
```

- One constructor per public operation.
- A test input is now a *value*: a `command list`
  - generatable, printable, shrinkable.
- The printer feeds failure messages.
- `create` is not a command
  - it is the fresh start of every test.

:::

A pretty-printer comes with it, because QCheck's failure
messages will show command sequences, and `<opaque>` is not
helpful:

```ocaml
let command_to_string = function
  | Enqueue x -> Printf.sprintf "Enqueue %d" x
  | Dequeue -> "Dequeue"
  | Size -> "Size"
```

Each constructor mirrors one operation of the queue API. We carry the
arguments inside the constructor.

We deliberately do *not* model `create` as a command; that is
the initial state. Each test starts with a freshly created
queue and applies a sequence of `command`s to it.

### Step 2: a generator for `command list`

```ocaml
let command_gen : command QCheck.Gen.t =
  let open QCheck.Gen in
  oneof [
    map (fun x -> Enqueue x) (int_range 0 9);
    return Dequeue;
    return Size;
  ]

let command_shrink (c : command) : command QCheck.Iter.t =
  match c with
  | Enqueue x -> QCheck.Iter.map (fun x' -> Enqueue x') (QCheck.Shrink.int x)
  | Dequeue | Size -> QCheck.Iter.empty

let command_list_gen : command list QCheck.arbitrary =
  QCheck.make
    ~print:(fun cs ->
      "[" ^ String.concat "; " (List.map command_to_string cs) ^ "]")
    ~shrink:(QCheck.Shrink.list ~shrink:command_shrink)
    (QCheck.Gen.list_size (QCheck.Gen.int_range 0 30) command_gen)
```

`Gen.oneof` picks one of the listed generators uniformly;
`Gen.map` builds an `Enqueue` around a random small int;
`Gen.return` is the generator that always produces exactly its
argument (the same `return` idea as in the monads module).
`QCheck.make` wraps the generator into an `arbitrary`; `~print`
attaches our pretty-printer so failure messages show readable
command lists.

The `~shrink` argument deserves a note; it is the one custom
shrinker the
[PBT lecture](M09-L05-property-based-testing.html) promised you
would write. For built-in types, `QCheck.(list int)` comes with
a shrinker; for a custom type, `QCheck.make` cannot guess one,
and without it a failing 30-command sequence is reported *as
is*. A shrinker maps a failing value to a stream
(`QCheck.Iter.t`) of smaller candidates to try in its place. We
attach `Shrink.list`, which drops commands from the list, and
give it a per-command shrinker: `Shrink.int` walks an
`Enqueue`'s argument toward zero (`Iter.map` wraps each shrunk
int back into the constructor), while `Dequeue` and `Size`
carry nothing to shrink (`Iter.empty`).

Three observations on the generator:

**The enqueued values are small (0 to 9).** For a queue, the
*values* never steer control flow, so they only need to be
readable in counterexamples; single digits are perfect. (For a
*keyed* structure, a map or a hash table, the analogous choice
is the most important one in the harness: a small key space
forces operations to collide on the same keys, which is where
keyed bugs live. The activity takes this up.)

**The command mix is uniform.** `oneof` picks each constructor
with equal probability, so `Dequeue` fires about as often as
`Enqueue`: the queue repeatedly drains to empty (exercising the
refill) and `Dequeue`-on-empty happens regularly too.

**The list length is bounded.** `list_size (int_range 0 30)`
caps sequences at 30 commands: long enough for several
fill-and-drain cycles, short enough that each test is fast and
the shrinker has manageable work.

:::slide

## Step 2: generating commands

```ocaml
let command_gen : command QCheck.Gen.t =
  let open QCheck.Gen in
  oneof [
    map (fun x -> Enqueue x) (int_range 0 9);
    return Dequeue;
    return Size;
  ]
```

- **Uniform mix**: `Dequeue` as often as `Enqueue`
  - the queue drains to empty regularly; the refill runs in
    almost every test.
- **Small values** (`0..9`): values never steer the queue.
  - keyed structures differ: there a small *key* space is the
    crucial choice (it forces collisions).

:::

:::slide

## Step 2: shrinking commands

```ocaml
let command_shrink (c : command) : command QCheck.Iter.t =
  match c with
  | Enqueue x ->
    QCheck.Iter.map (fun x' -> Enqueue x') (QCheck.Shrink.int x)
  | Dequeue | Size -> QCheck.Iter.empty
```

- The custom shrinker the PBT lecture promised you would write.
- A shrinker maps a failing value to *smaller candidates*
  - a stream (`QCheck.Iter.t`) of values to try in its place.
- `Enqueue x`: `Shrink.int` walks `x` toward `0`
  - `Iter.map` wraps each shrunk int back into `Enqueue`.
- `Dequeue` and `Size` carry nothing to shrink
  - `Iter.empty`: no candidates.

:::

:::slide

## Step 2: wrap into an `arbitrary`

```ocaml
let command_list_gen : command list QCheck.arbitrary =
  QCheck.make
    ~print:(fun cs ->
      "[" ^ String.concat "; " (List.map command_to_string cs) ^ "]")
    ~shrink:(QCheck.Shrink.list ~shrink:command_shrink)
    (QCheck.Gen.list_size (QCheck.Gen.int_range 0 30) command_gen)
```

- `QCheck.make` turns the generator into an `arbitrary`
  - for a custom type it has **no defaults**: attach both.
- `~print`: failures print readable command lists, not `<opaque>`.
- `~shrink`: `Shrink.list` drops commands, `command_shrink` shrinks each.
- `list_size (int_range 0 30)`: at most 30 commands, fast to shrink.

:::

### Step 3: two interpreters

The interpreters apply a single command to a piece of state and
return an `observation`, which captures whatever the operation
makes visible.

:::slide

## Step 3: interpreters return observations

```ocaml
type observation =
  | OUnit | OInt of int | ODeq of int option

let run_real q = function
  | Enqueue x -> enqueue q x; OUnit
  | Dequeue -> ODeq (dequeue q)
  | Size -> OInt (size q)

let run_ref q = function
  | Enqueue x -> m_enqueue q x; OUnit
  | Dequeue -> ODeq (m_dequeue q)
  | Size -> OInt (m_size q)
```

- The property compares the two observation streams step by step.

:::

The reference's interpreter mirrors the same three arms against
the model:

```ocaml
let run_ref (q : model) (c : command) : observation =
  match c with
  | Enqueue x -> m_enqueue q x; OUnit
  | Dequeue -> ODeq (m_dequeue q)
  | Size -> OInt (m_size q)
```

The observations are exactly the parts of each call's result
that are publicly visible. `Enqueue` returns `unit`, so its
observation is `OUnit` (it passes trivially); `Dequeue` returns
an `int option`, observed as `ODeq`; `Size` returns an `int`,
observed as `OInt`.

Why an `observation` type at all? Because the property has to
compare the *observable* output of each call. A test that just
checked "no exception was raised" would miss bugs that silently
return wrong values from `Dequeue`. By making every visible
result an `observation`, we explicitly compare the parts of
behaviour the user can see. And the cheap `Size` observation
earns its keep: it can expose a corrupted internal state right
after the operation that corrupted it, before any `Dequeue`
gets around to revealing it.

### Step 4: the property

```ocaml
let test_q_matches_ref =
  QCheck.Test.make
    ~name:"queue matches reference"
    ~count:1000
    command_list_gen
    (fun cs ->
       let real = create () in
       let model = m_create () in
       List.for_all
         (fun c ->
            let o_real = run_real real c in
            let o_model = run_ref model c in
            o_real = o_model)
         cs)
```

Five lines of property. Read them carefully because they encode
the entire model-based-testing idea:

- Create both a real queue and a reference queue, fresh.
- Walk the command list. At each step, apply the same command
  to both. Compute their observations.
- The step *passes* if the observations are equal. The step
  *fails* if they differ.
- The property is `true` iff *every* step passes.

Run it against our (correct) two-list queue:

```ocaml
let _ = QCheck_runner.run_tests ~colors:false [test_q_matches_ref]  (* = 0 *)
```

If the queue is correct, both implementations produce the same
observation for every command, the equality holds for every
step, and the test passes, as it just did: a thousand random
operation sequences, every step agreeing. If the queue has a
bug, some operation eventually produces a different observation
than the reference, the equality fails, the step returns
`false`, and `List.for_all` short-circuits to `false`. The
property fails and QCheck reports the operation sequence as a
counterexample. We will watch that happen in a moment.

:::slide

## Step 4: the property

```ocaml
let test_q_matches_ref =
  QCheck.Test.make
    ~name:"queue matches reference"
    ~count:1000
    command_list_gen
    (fun cs ->
       let real = create () in
       let model = m_create () in
       List.for_all
         (fun c -> run_real real c = run_ref model c)
         cs)

let _ = QCheck_runner.run_tests ~colors:false [test_q_matches_ref]  (* = 0 *)
```

- Both impls start fresh.
- Apply each command to both.
- Observations must agree at *every* step.
- Disagreement => bug; QCheck shrinks the sequence.

:::

### Step 5: what shrinking does to operation sequences

The list shrinker we attached in step 2 is exactly what we
want. When the property fails on a long sequence, the
shrinker:

1. Tries dropping a single command. Re-runs both interpreters
   on the shorter sequence. Does the divergence still happen?
   If yes, the smaller sequence is the new witness; recurse.
2. If dropping any single command makes the divergence go
   away, the shrinker tries dropping pairs, then halves.
3. Eventually the shrinker arrives at a minimum-length
   sequence that still triggers the bug. For most queue bugs,
   this is 2-4 commands.
4. Once the length is minimal, the shrinker tries to simplify
   the arguments inside each command (integers toward zero).
   `Enqueue 7` shrinks to `Enqueue 0` if the smaller version
   still triggers the bug.

The shrunk sequence is *the bug report*. For a typical refill
bug, the shrinker might end up reporting:

```
Test failed on input:
  [Enqueue 0; Dequeue; Dequeue]
```

Three commands. A long failing sequence with random
distractors would be unreadable. The three-command shrunk witness reads
itself: "enqueue one element, dequeue it, dequeue again.
The two implementations disagree on what comes out." Now you
know exactly where to look: the moment `dequeue` crosses from
a drained `front` into `back`.

:::slide

## Step 5: shrinking the failing sequence

A long failing sequence shrinks to:

```
[Enqueue 0; Dequeue; Dequeue]
```

- Drop commands one by one.
- Then simplify arguments (integers toward 0).
- The attached list shrinker does all this.
- Three commands = a readable bug report.

:::

## The full test, end to end

Putting the pieces together (this is the complete file you
would put in `test/test_queue.ml`, below the queue and model
definitions):

```text
type command =
  | Enqueue of int
  | Dequeue
  | Size

let command_to_string = function
  | Enqueue x -> Printf.sprintf "Enqueue %d" x
  | Dequeue -> "Dequeue"
  | Size -> "Size"

type observation =
  | OUnit
  | OInt of int
  | ODeq of int option

let run_real (q : queue) = function
  | Enqueue x -> enqueue q x; OUnit
  | Dequeue -> ODeq (dequeue q)
  | Size -> OInt (size q)

let run_ref (q : model) = function
  | Enqueue x -> m_enqueue q x; OUnit
  | Dequeue -> ODeq (m_dequeue q)
  | Size -> OInt (m_size q)

let command_gen : command QCheck.Gen.t =
  let open QCheck.Gen in
  oneof [
    map (fun x -> Enqueue x) (int_range 0 9);
    return Dequeue;
    return Size;
  ]

let command_shrink (c : command) : command QCheck.Iter.t =
  match c with
  | Enqueue x -> QCheck.Iter.map (fun x' -> Enqueue x') (QCheck.Shrink.int x)
  | Dequeue | Size -> QCheck.Iter.empty

let command_list_gen : command list QCheck.arbitrary =
  QCheck.make
    ~print:(fun cs ->
      "[" ^ String.concat "; " (List.map command_to_string cs) ^ "]")
    ~shrink:(QCheck.Shrink.list ~shrink:command_shrink)
    (QCheck.Gen.list_size (QCheck.Gen.int_range 0 30) command_gen)

let test_q_matches_ref =
  QCheck.Test.make
    ~name:"queue matches reference on all command sequences"
    ~count:1000
    command_list_gen
    (fun cs ->
       let real = create () in
       let model = m_create () in
       List.for_all
         (fun c -> run_real real c = run_ref model c)
         cs)

let () = QCheck_runner.run_tests_main [test_q_matches_ref]
```

Some fifty lines for a complete stateful test. The `dune`:

```dune
(test
 (name test_queue)
 (libraries qcheck))
```

One test executable, one `dune runtest`, 1000 random operation
sequences per run, automatic shrinking on failure.

## Watching it catch a real bug

To make this concrete: suppose someone writes the refill in
`dequeue` and forgets one assignment. The reverse happens, the
new `front` is installed, but `back` is never cleared. The
type and the other operations are untouched; only `dequeue`
changes:

```ocaml
let bad_dequeue q =
  match q.front with
  | x :: rest -> q.front <- rest; Some x
  | [] ->
    match List.rev q.back with
    | [] -> None
    | x :: rest ->
      q.front <- rest;
      (* BUG: forgot   q.back <- [];   *)
      Some x
```

The consequence: every element that was in `back` at refill
time stays there, and the *next* refill delivers all of them a
second time. The queue duplicates elements. But notice how
quiet the bug is: the refill itself returns the right element,
and every `dequeue` before the next refill is right too.

Point the same harness at the bad `dequeue` (the interpreter
reuses `enqueue` and `size`; only the `Dequeue` arm changes):

```ocaml
let run_buggy (q : queue) = function
  | Enqueue x -> enqueue q x; OUnit
  | Dequeue -> ODeq (bad_dequeue q)
  | Size -> OInt (size q)

let test_buggy =
  QCheck.Test.make
    ~name:"buggy queue matches reference"
    ~count:1000
    command_list_gen
    (fun cs ->
       let real = create () in
       let model = m_create () in
       List.for_all
         (fun c -> run_buggy real c = run_ref model c)
         cs)

let _ = QCheck_runner.run_tests ~colors:false [test_buggy]  (* = 1 *)
```

QCheck finds a diverging sequence almost immediately and
shrinks it. The minimal witness is three commands, in one of
two equivalent shapes (which one you get varies with the seed):

```
Test buggy queue matches reference failed (... shrink steps):

[Enqueue 0; Dequeue; Size]
```

Read it: enqueue one element, dequeue it (this refill leaves
the element stranded in `back`), then ask for the size. The
real queue says `1`, the reference says `0`. The other shape,
`[Enqueue 0; Dequeue; Dequeue]`, catches the duplicate
directly: the second `Dequeue` returns `Some 0` instead of
`None`. Either way the witness is immediately legible. A
unit-test suite would need to *think* of this scenario; the
model-based test *generates* it.

This is the value proposition: writing the reference plus the
five-step harness costs maybe half an hour. The harness then
catches every refill bug, every ordering bug, every lost or
duplicated element, every thing the random sequences happen to
trip over. The cost is bounded; the coverage is unbounded.

:::slide

## Seed a bug in the refill

```ocaml
let bad_dequeue q =
  match q.front with
  | x :: rest -> q.front <- rest; Some x
  | [] ->
    match List.rev q.back with
    | [] -> None
    | x :: rest ->
      q.front <- rest;
      (* BUG: forgot   q.back <- [];   *)
      Some x
```

- Every refill re-delivers the old contents of `back`.
- Quiet: nothing visibly wrong until the *next* refill.

:::

:::slide

## A bug found

```ocaml
let run_buggy q = function
  | Enqueue x -> enqueue q x; OUnit
  | Dequeue -> ODeq (bad_dequeue q)
  | Size -> OInt (size q)

let test_buggy =
  QCheck.Test.make ~name:"buggy queue matches reference"
    command_list_gen
    (fun cs ->
       let real = create () in
       let model = m_create () in
       List.for_all (fun c -> run_buggy real c = run_ref model c) cs)

let _ = QCheck_runner.run_tests ~colors:false [test_buggy]  (* = 1 *)
```

- Shrunk witness `[Enqueue 0; Dequeue; Size]`: size 1 vs 0. Caught.

:::

## When does this scale?

Model-based testing scales to any data structure with a clean
interface. Some examples:

**Hash tables.** Reference: an association list
`(key * value) list`. Test: open addressing, chaining,
resizing. (This is the activity.)

**Stacks.** Reference: a `list` (head = top). Test: any stack
implementation (array-backed, linked, persistent).

**Priority queues.** Reference: a sorted list. Test: heap,
pairing heap, leftist heap.

**Maps and sets.** Reference: an association list or a sorted
list. Test: AVL tree, red-black tree, hash table, B-tree.

**LRU caches.** Reference: a list plus a counter for recency.
Test: a doubly-linked-list + hash table implementation.

**Persistent data structures.** Reference: a list of all
versions. Test: a persistent vector, finger tree, zipper.

In every case the pattern is the same: the reference is the
simplest possible thing that satisfies the interface, the
implementation under test is the optimised version, and the
property checks that they agree on every sequence of
operations.

### Limits and extensions

**Limit 1: non-determinism.** If the implementation is
non-deterministic (e.g. concurrent code, hash-table iteration
order), the simple equality check `or_ = oref` fails because
the observations *legitimately* differ. The fix is to compare
*equivalence classes*: maps as their multi-sorted contents,
iteration as the sorted result of `to_list`. The shape of the
property gets richer, but the framework still applies.

**Limit 2: concurrent code.** For multi-threaded data
structures, you want to test linearisability: the parallel
history is *equivalent to some sequential interleaving*. This
is what the [`multicoretests`
library](https://github.com/ocaml-multicore/multicoretests)
does for OCaml 5's parallel runtime, with `qcheck-stm`
(stateful model) and `qcheck-lin` (linearisability). The
underlying technique is the same as this lecture: define
commands, run on a model, check equivalence.

**Limit 3: external state.** If the data structure interacts
with the filesystem, network, or database, the reference can
sometimes be an in-memory mock. When the external state itself
is the spec, model-based testing degrades to integration
testing. The boundary is fuzzy and worth thinking about.

**Extension: state-aware command generation.** A more advanced
technique is to make the *generator itself* aware of state. For
example, after an `Add 5`, the generator should be biased to
generate `Find 5` or `Remove 5` (to exercise interesting
follow-ups), not just uniform random keys. Libraries like
`qcheck-stm` support this via a "command precondition"
mechanism: each command can be conditioned on the current
model state. Beyond the scope of this introductory lecture but
worth knowing exists.

:::slide

## When this scales

| Structure | Reference |
| --- | --- |
| Queue, stack | `list` |
| Hash table | association list |
| Priority queue | sorted `list` |
| Map, set | association list |
| LRU cache | list + recency counter |
| Persistent vector | list of versions |
| Concurrent data structure | linearised sequential history |

Same five-step recipe. Different reference.

:::

## The relationship to formal specifications

A philosophical aside. When you write the reference implementation,
you are writing *a specification in code*. It is executable, it
is type-checked, it is testable, and it is human-readable. It
is not a formal proof of correctness for the optimised version,
but it is a *very strong* specification: any difference between
the two on any operation sequence is, by definition, a bug in
the optimised version.

There is a classical name for the idea. An *equational
specification* (or algebraic specification) defines a data
abstraction by equations between its operations, with no
implementation in sight: for a queue, laws like "`front` of
`enqueue x` on an empty queue is `x`" and "`dequeue` then
`enqueue` commutes with `enqueue` then `dequeue` on a non-empty
queue". A reference implementation is those equations packaged
as code: the simplest structure that satisfies all of them. When
the test harness compares the optimised implementation against
the reference on every operation sequence, it is checking the
equations, wholesale, without ever writing them down one by one.

This puts model-based testing into a productive middle ground.
On one side, formal verification (Rocq, Lean) gives mathematical
certainty but costs months of effort per data structure. On the
other side, unit testing gives the cases you thought of. Model-
based PBT gives you, for one hour of harness writing,
exhaustive sampling of operation sequences against a hand-
written spec. It catches almost all the bugs that unit testing
misses, almost free of cost. It is the highest-leverage testing
technique we will cover.

Some industrial cases worth knowing:

- John Hughes's group at Quviq applied this technique to
  industrial codebases at AUTOSAR, Volvo Cars, and Ericsson;
  see the *Experiences with QuickCheck* paper in the Reading.
- Kyle Kingsbury's
  [Jepsen](https://jepsen.io/) does exactly this to distributed
  databases: it drives a cluster with random operation
  sequences, checks the observed history against a reference
  consistency model, and injects network partitions mid-run. It
  has found lost writes and consistency violations in Redis,
  MongoDB, and many other production systems. The data structure
  is a whole database and the divergence is a violated
  consistency guarantee, but it is the same recipe as the queue
  above: commands, a reference, equivalence checked over the
  history.
- Industrial OCaml codebases lean on property tests with
  generators derived from type definitions
  (`ppx_quickcheck`); the RWO Testing chapter shows the
  pattern.
- The OCaml 5 runtime's lock-free data structures are tested
  with `multicoretests` against a linearisability model.

:::slide

## The bigger picture

Model-based testing is the *executable spec* version of formal
verification.

- The reference implementation is an **equational
  specification** packaged as code:
  - the queue laws ("front of enqueue x on empty is x", ...)
    checked wholesale, never written one by one.
- **Formal proof (Rocq, Lean)**: mathematical certainty, months
  of effort.
- **Unit testing**: the cases you thought of.
- **Model-based PBT**: a sampled refinement check against a
  reference, hours of effort.

Industrial cases: Quviq + Volvo + Ericsson (Hughes); Jane
Street (ppx_quickcheck); OCaml 5's multicoretests.

:::

## Activity

:::quiz mcq id=M09-L06-q1
You are testing a custom red-black tree implementation using
model-based PBT against an association-list reference. The
default `command_gen` produces `Add k v`, `Remove k`, and
`Find k` with equal probability and `k` chosen uniformly from
`int_range 0 1_000_000`.

After running 1000 random sequences, the test passes. A user
later reports a bug: `Remove` on a key already in the tree
sometimes leaves the tree unbalanced. Why did the test not
catch this?

- [ ] Property-based testing cannot find bugs in tree
  algorithms.
- [x] The key space makes successful `Remove`s too rare.
- [ ] The reference implementation must also be a red-black
  tree, otherwise the comparison is meaningless.
- [ ] `Remove` cannot be tested by model-based PBT; it requires
  a dedicated invariant checker.

**Why:** the issue is *distribution*. A million-element key
space means random commands almost never collide. `Remove k`
on a key not in the tree is a no-op for both implementations,
so observations agree trivially. The interesting case (remove
a present key) almost never happens. The fix is the keyed-
structure version of the lecture's generator-design lesson:
use a small key space so that random commands frequently
target existing keys and exercise the algorithm's interesting
branches.
:::

:::quiz mcq id=M09-L06-q2
In the worked example, the property compares observations
step-by-step:

```text
List.for_all (fun c -> run_real real c = run_ref model c) cs
```

Why is step-by-step equivalence important? Why not just compare
the *final* state of the two queues after running all commands?

- [ ] OCaml's `=` does not work on mutable state.
- [ ] Step-by-step is faster.
- [x] Later commands can hide an earlier divergence.
- [ ] Final-state comparison is impossible because the queue is
  mutable.

**Why:** if two impls diverge at step 7 and then reconverge at
step 12, a final-state comparison passes; the bug is hidden. By
asserting equivalence at every step, the test fires at the
*earliest* step where the divergence occurs. Combined with
shrinking, this gives you the smallest possible bug reproducer:
"the first time these two implementations disagree is on a
3-command sequence ending in this `Dequeue`."
:::

:::quiz code id=M09-L06-q3
Take the hash table from the activity question: `add : t -> int
-> string -> unit`, `find : t -> int -> string option`,
`remove : t -> int -> unit`, and `size : t -> int`. (The right
reference is an association list `(int * string) list`: it is
the simplest finite-map structure, and each operation is one
line.) Write the harness's `command` variant type, one
constructor per operation, and a `command_to_string` function
that pretty-prints each command for failure messages. (`%S` in
a `Printf` format prints a string with quotes and escapes.)

```ocaml
type command =
  | (* TODO: fill in *)

let command_to_string = function
  | _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let s = command_to_string (Add (3, "x")) in
  assert (s = "Add (3, \"x\")");
  let s = command_to_string (Find 7) in
  assert (s = "Find 7");
  let s = command_to_string (Remove 0) in
  assert (s = "Remove 0");
  let s = command_to_string Size in
  assert (s = "Size");
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type command =
  | Add of int * string
  | Find of int
  | Remove of int
  | Size

let command_to_string = function
  | Add (k, v) -> Printf.sprintf "Add (%d, %S)" k v
  | Find k -> Printf.sprintf "Find %d" k
  | Remove k -> Printf.sprintf "Remove %d" k
  | Size -> "Size"
```

Four constructors mirroring the four operations, plus a printer
that uses `Printf.sprintf` for the parameterised cases (`%S`
prints the string quoted and escaped). The rest of the harness
follows the lecture's recipe: an association-list reference,
interpreters returning `OUnit` / `OFound of string option` /
`OInt of int` observations, and one crucial generator choice:
draw the keys from a *small* range, so `Find` and `Remove`
frequently hit keys that are actually present.

:::

## Common pitfalls

**Pitfall 1: the reference is wrong too.** If the reference
implementation contains the same bug as the system under test,
or quietly implements different semantics, the test passes
despite both being wrong. Two defences. *Keep the reference
trivial*: the whole point is that it is so simple that any
reader can convince themselves it is right; if the reference
is more complex than 30-50 lines, you have lost the property.
And *check the reference against the actual specification
once*, by hand or with a few unit tests, before using it as
the oracle. Garbage in, garbage out.

**Pitfall 2: incomplete observations.** Comparing only
`Dequeue` results misses bugs where the internal state has gone
wrong but the divergence has not yet reached the front of the
queue (our seeded bug was exactly this kind of quiet). Include
enough observations to make any state divergence visible: at
minimum, compare the size after every operation; ideally,
compare the full visible state.

**Pitfall 3: distribution that misses interesting cases.** The
canonical mistake in a *keyed* structure: use the default
`QCheck.int` for keys. The test passes vacuously because no two
random commands ever operate on the same key. Force collisions
with a small key range.

**Pitfall 4: not enough commands.** A bug that only fires after
several drain-and-refill cycles (or, for a growing structure,
several resizes) needs sequences long enough to trigger them.
If your tests are too short, you miss bugs that emerge from
interactions between many operations. Bound sequences at 30-50
commands by default; experiment with longer for data structures
that grow.

**Pitfall 5: assuming determinism.** If your data structure has
any randomised behaviour (e.g. a hash with `Random.int` salt,
or any concurrency), the equality check breaks. Either seed the
randomness explicitly so the test is reproducible, or compare
equivalence classes rather than raw observations.

:::slide

## Common pitfalls

1. **The reference itself is wrong.** Keep it under 50 lines
   - and sanity-check it against the spec once, by hand.
2. **Observations too narrow.** Compare more than just return
   values
   - include cheap state observations like `Size`.
3. **Distribution misses collisions.** Small key space.
4. **Sequences too short.** 30-50 commands per test.
5. **Non-determinism.** Seed it or compare equivalence classes.

:::

## What's next

[Lecture 7](M09-L07-tutorial.html) is the module's wrap-up
tutorial: the whole toolkit, applied end to end to a single
worked example. We take a small arithmetic `expr` evaluator (a
float cousin of the pattern-matching tutorial's interpreter),
write its specification,
design black-box cases from it, mechanise them with OUnit2,
add QCheck properties with a custom generator, and watch the
shrinker corner a deliberately introduced bug.

:::slide

## What's next

- L7: **tutorial wrap-up.** The full toolkit on the `expr`
  evaluator:
  - spec → designed cases → OUnit2 suite → QCheck
    properties → a planted bug, caught and shrunk.

:::

## Reading

- **QCheck-STM**, a QCheck extension specifically for
  model-based testing of stateful code. Used in the OCaml 5
  multicore runtime for testing lock-free data structures:
  <https://github.com/ocaml-multicore/multicoretests>
- **Cornell CS3110**, *Randomized testing with QCheck*. The
  abstraction layering used in this lecture matches CS3110's:
  <https://cs3110.github.io/textbook/chapters/correctness/randomized.html>
- **John Hughes**, *Experiences with QuickCheck: Testing the
  Hard Stuff and Staying Sane* (2016). Industrial-scale
  applications of QuickCheck, including model-based testing of
  AUTOSAR drivers:
  <https://publications.lib.chalmers.se/records/fulltext/232550/local_232550.pdf>
- **Claessen and Hughes**, *QuickCheck: A Lightweight Tool for
  Random Testing of Haskell Programs* (2000). The original
  paper introducing PBT, and the "test against a model"
  example with finite maps:
  <https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf>
- **Real World OCaml**, *Testing*. The Quickcheck section
  covers manual generators for compound types, with
  `ppx_quickcheck` for boilerplate reduction:
  <https://dev.realworldocaml.org/testing.html>

## Sources

This lecture's prose, worked examples, and quizzes are original
to this course. The "test stateful impl against a simple
reference using random operation sequences" pattern is the
canonical model-based testing technique, originally articulated
in Claessen and Hughes 2000 and elaborated in Hughes 2016
(both cited in the Reading); the OCaml-specific phrasing and
the hash-table / queue worked examples are our own. The
two-stack queue (Banker's queue without lazy thunks) is a
classic data structure originally due to Burton; our
presentation is the textbook one. The QCheck library
(Simon Cruanes and contributors) is BSD-2-Clause licensed and
linked through its public API. Cornell CS3110's testing
chapters are CC BY-NC-ND licensed and have not been
derivatively reused. Real World OCaml's testing chapter is
linked for further reading; its Quickcheck and `ppx_quickcheck`
discussion is independent of ours.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
