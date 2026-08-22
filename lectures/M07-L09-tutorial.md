---
title: "Tutorial: a queue functor"
lecture_no: 9
week: 7
duration_target_min: 28
concepts: [worked module, abstract type, functor, two-stack queue]
keywords: [OCaml, queue, two-stack, functor, tutorial, module]
activity_question: "Add a [length : 'a t -> int] operation to the queue (update both the signature and the struct; what does the compiler require if you forget one side?). Then instantiate a queue of queues of integers ([int Queue.t Queue.t]) and show an example run."
think_about_this: "We built a queue using two stacks (lists). [enqueue] is O(1), [dequeue] is amortized O(1). Why does the two-list trick give amortized O(1) rather than worst-case O(1)?"
reading:
  - title: "Cornell CS3110, A functional queue"
    url: https://cs3110.github.io/textbook/chapters/modules/functors.html
---

# Tutorial for Module 7


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: a queue functor</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 9</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

This tutorial pulls together the machinery from the rest of the
module. We build a small *functional queue* (FIFO: first-in,
first-out) using the classic two-stack trick. We package it as a
module with a signature that hides the representation. Then we
turn it into a functor parameterised by the element type, with a
printer attached. By the end of the lecture you will have used
every piece of vocabulary from Module 7 in one worked example.

The two-stack queue is a small classic of functional programming.
A queue is a FIFO: you push onto one end and pop from the other.
If you implement it naively as a single list, *push* and *pop*
can't both be O(1): one of them has to walk to the far end. The
trick is to keep *two* lists, one for the front (in normal order)
and one for the back (in reverse order). `enqueue` conses onto
the back; `dequeue` pulls from the head of the front; when the
front runs out, we reverse the back to become the new front.

This is the same trick that backs many real-world queue
implementations in functional languages. It is the kind of small
data structure that is exactly the sort of thing a module
system is designed for: a few operations on an abstract type,
maintaining an invariant we do not want callers to see or break.

:::slide

## What this tutorial does

- Build a *functional queue* (FIFO) using the classic two-stack
  trick.
- Wrap it in a module with a signature that hides the
  representation.
- Turn the module into a *functor* parameterised by the element
  type, with a printer attached.
- Uses every piece of vocabulary from Module 7: module,
  signature, abstract type, functor.
- Walk away with one worked example covering the whole module.

:::

## A picture first: how the two lists work

Before the code, trace three enqueues and a dequeue. `enqueue`
always conses onto `back`, so `back` holds the newest elements in
*reverse* arrival order. `dequeue` pops the head of `front`; when
`front` is empty, it reverses `back` onto `front`, which flips
those elements back into arrival order, so the oldest comes out
first.

```text
            front (pop here)        back (push here)
enqueue 1   []                      [1]
enqueue 2   []                      [2; 1]
enqueue 3   []                      [3; 2; 1]

dequeue     front is empty: reverse back onto front
            [1; 2; 3]               []
            pop the head, returns 1
            [2; 3]                  []
```

After the reverse, the next dequeues are plain list-head pops:
that is the seed of the amortised-O(1) argument we make below.
Both `enqueue` and `dequeue` are amortised O(1): `enqueue` is a
single cons, and each element is reversed onto the front only
once in its lifetime.

:::slide

## Tracing the two-stack queue

- `enqueue` conses onto `back`: newest first, in reverse order.
- `dequeue` pops `front`; an empty `front` reverses `back` onto it.
- The reverse flips back into arrival order: FIFO preserved.
- Both push and pop are amortised O(1).

```text
            front (pop here)        back (push here)
enqueue 1   []                      [1]
enqueue 2   []                      [2; 1]
enqueue 3   []                      [3; 2; 1]

dequeue     front empty: reverse back onto front
            [1; 2; 3]               []
            pop the head, returns 1
            [2; 3]                  []
```

:::

## The implementation, unsealed

We start with the raw implementation, with no signature attached.

```ocaml
type 'a queue = { front : 'a list; back : 'a list }

let empty = { front = []; back = [] }

let is_empty q = q.front = [] && q.back = []

let enqueue x q = { q with back = x :: q.back }

let rec dequeue q =
  match q.front, q.back with
  | [], [] -> None
  | x :: rest, _ -> Some (x, { q with front = rest })
  | [], back -> dequeue { front = List.rev back; back = [] }

let q = empty |> enqueue 1 |> enqueue 2 |> enqueue 3
let _ = dequeue q   (* = Some (1, ...) *)
```

Let's walk through each
piece.

The type `'a queue` is a record with two fields, both `'a list`.
The *invariant* (a property the implementation maintains and the
caller relies on) is: if there is anything in the queue, the
front list is the oldest elements in FIFO order, and the back
list is the newest elements in *reverse* FIFO order. Equivalently,
the conceptual queue is `front @ List.rev back`.

`empty` is the queue with both lists empty.

`is_empty` checks both lists. A queue is empty only if both are
empty: if the front is empty but the back is not, there are still
elements waiting (they will get moved to the front on the next
dequeue).

`enqueue x q` adds `x` to the new end: it conses onto the back.
This is O(1).

`dequeue` is the interesting one. Three cases:

- `[], []`: the queue is empty; return `None`.
- `x :: rest, _`: the front has at least one element; return it,
  and the rest of the queue is `{ front = rest; back = q.back }`.
- `[], back`: the front is empty but the back is not; reverse the
  back into a fresh front and recurse.

The third case is where the *amortised* analysis kicks in. A
single `List.rev` is O(n), so in the worst case a single
`dequeue` takes O(n). But each element is only reversed *once* in
its lifetime in the queue: it gets pushed onto the back, sits
there, then is reversed onto the front exactly once. Over the
total lifetime of the queue, each element pays O(1) of reversal
cost. *Amortised*, `dequeue` is O(1). Worst-case, it is O(n).

:::slide

## The implementation

```ocaml
type 'a queue = { front : 'a list; back : 'a list }

let empty = { front = []; back = [] }

let is_empty q = q.front = [] && q.back = []

let enqueue x q = { q with back = x :: q.back }

let rec dequeue q =
  match q.front, q.back with
  | [], [] -> None
  | x :: rest, _ -> Some (x, { q with front = rest })
  | [], back -> dequeue { front = List.rev back; back = [] }
```

:::

:::slide

## The implementation: a run

```ocaml
let q = empty |> enqueue 1 |> enqueue 2 |> enqueue 3
let _ = dequeue q   (* = Some (1, ...) *)
```

- First `dequeue` hits the recursive case (front empty), reverses
  `back` into `front`, recurses.
- Subsequent dequeues are O(1).

:::

## The signature

We have a working queue, but the representation is exposed. A
caller can construct a record `{ front = [1; 2]; back = [3; 4] }`
directly, possibly violating our invariant. Even worse, a caller
can come to *rely on* the two-list shape, so that any future
change to the representation breaks their code.

The fix from the [signatures lecture](M07-L07-signatures.html#abstract-types):
a signature with an abstract type.

```ocaml
module type QUEUE = sig
  type 'a t
  val empty : 'a t
  val is_empty : 'a t -> bool
  val enqueue : 'a -> 'a t -> 'a t
  val dequeue : 'a t -> ('a * 'a t) option
end

module Queue : QUEUE = struct
  type 'a t = { front : 'a list; back : 'a list }

  let empty = { front = []; back = [] }

  let is_empty q = q.front = [] && q.back = []

  let enqueue x q = { q with back = x :: q.back }

  let rec dequeue q =
    match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }
end
```

Running it from outside the module:

```ocaml
let q = Queue.empty |> Queue.enqueue 1 |> Queue.enqueue 2 |> Queue.enqueue 3
let _ = Queue.dequeue q          (* = Some (1, <abstr>) *)
let _ = Queue.is_empty Queue.empty   (* = true *)
```

The dequeue now returns `<abstr>` in place of the record: from
outside `Queue`, the second component is an opaque `'a t`.

The `QUEUE` signature lists exactly the operations callers can
use. The type `'a t` is abstract: outside `Queue`, you cannot see
that it is a two-list record. The constructors `empty` and
`enqueue` are how you build queues; `dequeue` is how you take
them apart; `is_empty` lets you check. That is the entire
surface.

:::slide

## The signature

```ocaml
module type QUEUE = sig
  type 'a t
  val empty : 'a t
  val is_empty : 'a t -> bool
  val enqueue : 'a -> 'a t -> 'a t
  val dequeue : 'a t -> ('a * 'a t) option
end
```

- Callers see only `'a t`, `empty`, `enqueue`, `dequeue`, `is_empty`.
- `'a t` is **abstract**: the two-list representation is hidden.

:::

:::slide

## Sealing the implementation

```ocaml
module Queue : QUEUE = struct
  type 'a t = { front : 'a list; back : 'a list }
  let empty = { front = []; back = [] }
  let is_empty q = q.front = [] && q.back = []
  let enqueue x q = { q with back = x :: q.back }
  let rec dequeue q =
    match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }
end
```

- Outside, only `QUEUE`'s operations work; the fields `front` /
  `back` are inaccessible.

:::

:::slide

## Sealed: the run

```ocaml
let q = Queue.empty |> Queue.enqueue 1 |> Queue.enqueue 2 |> Queue.enqueue 3
let _ = Queue.dequeue q   (* = Some (1, <abstr>) *)
```

- `dequeue` returns `<abstr>` for the queue component: from
  outside, it is an opaque `'a t`.

:::

## Why hide the representation?

The [two reasons we hid internals](M07-L07-signatures.html#why-hide-internals),
applied here.


:::

**Invariants.** Our queue depends on `front` containing the
elements in FIFO order and `back` containing them in reverse. If
callers could write `{ front = [3; 2]; back = [1] }` directly,
they could create a queue that violates the invariant; subsequent
operations would return elements in the wrong order. The
signature prevents this: the only way to make a queue is to start
from `Queue.empty` and use `Queue.enqueue`, which maintain the
invariant.

**Change.** Maybe later we want to switch to a different
implementation: a `Dynarray`, a doubly-linked list, an array
ring buffer. As long as the new implementation provides `empty`,
`is_empty`, `enqueue`, `dequeue` with the same types, no caller
needs to change. The signature is the contract; we are free to
change anything below it.

:::slide

## Why hide the representation?

Two reasons we've seen before:

- **Invariants.** Our queue assumes `front` is the "front in
  normal order". If callers could touch the record directly, they
  could violate that. Hiding the representation enforces it.
- **Change.** If we later switch to a different implementation (a
  Dynarray, a linked structure), no caller breaks.


## Turning it into a functor

Suppose now we want a queue parameterised by the *element type*,
with a typed printer attached. (Maybe we want a debugger view, or
a logger that prints queue contents.) The element type can no
longer be free: we need a way to turn an element into a string.

The mechanism from the [functors lecture](M07-L08-functors.html): a
functor. We start by writing a signature describing what we need
from the element type.

```ocaml
module type ELT = sig
  type t
  val to_string : t -> string
end

module Make (E : ELT) = struct
  type elt = E.t
  type t = { front : elt list; back : elt list }

  let empty = { front = []; back = [] }
  let is_empty q = q.front = [] && q.back = []
  let enqueue x q = { q with back = x :: q.back }
  let rec dequeue q =
    match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }

  let print q =
    let items = q.front @ List.rev q.back in
    print_endline ("[" ^ String.concat ", " (List.map E.to_string items) ^ "]")
end
```

Apply it to `int` and run:

```ocaml
module IQ = Make (struct type t = int let to_string = string_of_int end)

let q = IQ.empty |> IQ.enqueue 1 |> IQ.enqueue 2 |> IQ.enqueue 3
let () = IQ.print q   (* prints: [1, 2, 3] *)
```

Notice `print` shows the queue as a single FIFO sequence, not the
internal two-list split: it joins `front @ List.rev back`, exactly
the conceptual queue. The printer respects the abstraction it
sits behind: callers see `[1, 2, 3]`, never the `front` / `back`
representation. Internally `front` is empty and `back` is
`[3; 2; 1]` here, but that never reaches the output.

:::slide

## Turning it into a functor: the parameter

- Suppose we want a queue parameterised by element type, with a
  printer for elements.
- The element type isn't free anymore: we need a `to_string` on it.

```ocaml
module type ELT = sig
  type t
  val to_string : t -> string
end
```

:::

:::slide

## The functor body

```ocaml
module Make (E : ELT) = struct
  type elt = E.t
  type t = { front : elt list; back : elt list }
  let empty = { front = []; back = [] }
  let is_empty q = q.front = [] && q.back = []
  let enqueue x q = { q with back = x :: q.back }
  let rec dequeue q = match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }
  let print q =
    let xs = q.front @ List.rev q.back in
    print_endline ("[" ^ String.concat ", " (List.map E.to_string xs) ^ "]")
end
```

- `E.t` is the element type; `E.to_string` is its printer.
- `print` shows the logical FIFO sequence (`front @ List.rev
  back`), not the internal two-list split.

:::

:::slide

## Applying the functor

```ocaml
module IQ = Make (struct
  type t = int
  let to_string = string_of_int
end)

let q = IQ.empty |> IQ.enqueue 1 |> IQ.enqueue 2 |> IQ.enqueue 3
let () = IQ.print q   (* prints: [1, 2, 3] *)
```

- Pass an inline module providing `int` + `string_of_int`; get
  out a fully working int-queue with printing.

:::

A few things to read out of this. The `Make` functor takes a
parameter `E` of signature `ELT`: any module with a type `t` and
a `to_string : t -> string`. Inside `Make`, we reference `E.t`
(the element type) and `E.to_string` (the printer). The resulting
module type fixes `elt = E.t`, so `IQ.elt` is `int` once we
instantiate with the `int` module.

This is the same shape as
[`Map.Make`](M07-L08-functors.html#the-pattern-mapmake): a
constraint on the element type (via the parameter signature), and
a generic implementation parameterised by that constraint.

## What is notable about the functor

:::slide

## What's notable about the functor

- **Specialised**: `IQ.elt` is `int`, period. Trying to enqueue a
  `string` is a type error.
- **Generic**: the *queue logic* is the same regardless of element
  type. We wrote it once.
- **Composable**: a `String_queue` is one line.
- This is how `Map.Make`, `Set.Make`, `Hashtbl.Make` work in the
  standard library.
- **One implementation, many specialisations.**

:::

:::slide

## A string queue: a run

```ocaml
module String_queue = Make (struct
  type t = string
  let to_string s = s
end)

let sq = String_queue.empty
         |> String_queue.enqueue "a" |> String_queue.enqueue "b"
let () = String_queue.print sq   (* prints: [a, b] *)
```

- Same `Make`, different element module; `String_queue.elt` is
  `string`.

:::

The functor is *specialised once you apply it*: `IQ.elt` is
exactly `int`. Trying to enqueue a string into `IQ` is a type
error caught at compile time, the same way trying to add a string
to an `int list` is. But the *implementation* of the queue
operations is written once: the body of `Make` does not know or
care what the element type is, except through `E.to_string`.

To build a string queue you write one line, then use it like any
other queue:

```ocaml
module String_queue = Make (struct
  type t = string
  let to_string s = s
end)

let sq = String_queue.empty
         |> String_queue.enqueue "a" |> String_queue.enqueue "b"
let () = String_queue.print sq   (* prints: [a, b] *)
```

This is exactly how `Map.Make`, `Set.Make`, and `Hashtbl.Make` in
the standard library work: one implementation, many specialised
instantiations. You write the data structure once and reuse it
forever.

## A quick check

:::quiz mcq id=M07-L09-q3
In the two-stack queue, what is the worst-case time complexity of
a single `dequeue` operation?

- [ ] O(1)
- [x] O(n)
- [ ] O(log n)
- [ ] O(n^2)

**Why:** when the front list is empty and the back has n
elements, `dequeue` calls `List.rev` on the back, which is O(n).
Amortised across many operations the cost is O(1) per element
(each element is reversed only once), but a *single* dequeue can
be O(n).
:::

:::quiz mcq id=M07-L09-q2
Given `module Make (E : ELT) = struct ... end`, what happens if
we try `Make (struct type t = int end)` (forgetting `to_string`)?

- [ ] Returns a partial module.
- [ ] Sets `to_string` to `string_of_int` automatically.
- [x] Compile error: signature mismatch, `to_string` not provided.
- [ ] Runtime error when `to_string` is called.

**Why:** the functor argument must satisfy `ELT`, which requires
both `t` and `to_string`. Missing one is rejected at the
functor application, at compile time, before any code runs.
:::

## Activity

:::slide

## Activity

Add `length : 'a t -> int` to the queue. Update the signature.
What does the compiler require?

:::

:::quiz code id=M07-L09-q1
Add a `length` operation to the queue. Both the signature and the
struct need updating. The starter has the unsealed version; your
job is to add `length` everywhere.

```ocaml
module type QUEUE = sig
  type 'a t
  val empty : 'a t
  val is_empty : 'a t -> bool
  val enqueue : 'a -> 'a t -> 'a t
  val dequeue : 'a t -> ('a * 'a t) option
end

module Queue : QUEUE = struct
  type 'a t = { front : 'a list; back : 'a list }
  let empty = { front = []; back = [] }
  let is_empty q = q.front = [] && q.back = []
  let enqueue x q = { q with back = x :: q.back }
  let rec dequeue q =
    match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }
end

let queue_length _q : int = failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let q = Queue.empty |> Queue.enqueue 1 |> Queue.enqueue 2 |> Queue.enqueue 3 in
  check (queue_length q = 3) "three elements";
  check (queue_length Queue.empty = 0) "empty";
  (match Queue.dequeue q with
   | Some (_, q') -> check (queue_length q' = 2) "after dequeue"
   | None -> failwith "expected non-empty");
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution: the signature

```ocaml
module type QUEUE = sig
  type 'a t
  val empty : 'a t
  val is_empty : 'a t -> bool
  val length : 'a t -> int
  val enqueue : 'a -> 'a t -> 'a t
  val dequeue : 'a t -> ('a * 'a t) option
end
```

One new `val`: `length : 'a t -> int`.

:::

:::

:::solution

:::slide

## Activity solution: the module

```ocaml
module Queue : QUEUE = struct
  type 'a t = { front : 'a list; back : 'a list }
  let empty = { front = []; back = [] }
  let is_empty q = q.front = [] && q.back = []
  let length q = List.length q.front + List.length q.back
  let enqueue x q = { q with back = x :: q.back }
  let rec dequeue q =
    match q.front, q.back with
    | [], [] -> None
    | x :: rest, _ -> Some (x, { q with front = rest })
    | [], back -> dequeue { front = List.rev back; back = [] }
end

let queue_length q = Queue.length q

let q = Queue.empty |> Queue.enqueue 1 |> Queue.enqueue 2 |> Queue.enqueue 3
let _ = queue_length q   (* = 3 *)
```

- The starter's `queue_length` stub forwards to the new
  `Queue.length`; the tests call `queue_length`.

:::

:::

:::slide

## The compiler enforces both sides

- Signature lists `length`; implementation provides it.
- Forget `length` in the module → `Signature mismatch: missing
  value 'length'`.
- Forget `length` in the signature → it's inaccessible from outside.

:::

This is the value of the signature in action. Adding a feature
requires touching both files (or both halves of an inline
declaration): the signature gets a `val`, the implementation gets
a `let`. The compiler checks both directions. If you add to the
signature but forget the implementation, you get `Signature
mismatch: missing value 'length'`. If you add to the implementation
but forget the signature, the new function exists but is
inaccessible from outside. The compiler keeps the contract
between interface and implementation consistent.

The implementation `length q = List.length q.front + List.length
q.back` is itself O(n) (each `List.length` walks its list). For a
queue that you query often, you might cache the length in a third
field of the record, updated by each `enqueue` and `dequeue`. The
signature would not change; only the implementation would. This
is the kind of optimisation the abstract type lets you do
silently.

## Activity: a queue of queues

The element type of `'a Queue.t` is unconstrained, so `'a` can be
*any* type, including another queue. Instantiate a queue of queues
of integers, type `int Queue.t Queue.t`, with two inner queues,
then reach in: dequeue the first inner queue, and dequeue its
first element.

:::slide

## Activity: a queue of queues

- `'a Queue.t` is polymorphic, so `'a` can itself be `int Queue.t`.
- Build an `int Queue.t Queue.t` holding two inner queues.
- Dequeue the first inner queue, then dequeue its first element.

:::

:::solution

:::slide

## Activity solution: nesting comes for free

```ocaml
let inner1 = Queue.empty |> Queue.enqueue 1 |> Queue.enqueue 2
let inner2 = Queue.empty |> Queue.enqueue 3
let qoq = Queue.empty |> Queue.enqueue inner1 |> Queue.enqueue inner2
(* qoq : int Queue.t Queue.t *)

let first_elt =
  match Queue.dequeue qoq with
  | Some (first, _) ->
      (match Queue.dequeue first with Some (x, _) -> Some x | None -> None)
  | None -> None
(* = Some 1 *)
```

- No new code: the abstract `'a t` already works for any `'a`,
  including another queue.

:::

:::

## What you should be able to do now

:::slide

## What you should be able to do now

After Module 7 you can:

- Use `ref`s and mutable record fields when imperative state is right.
- Use arrays for O(1) indexed access.
- Raise and catch exceptions; pick between exceptions and option/result.
- Group definitions into modules.
- Constrain a module by a signature to hide internals.
- Use stdlib functors (`Map.Make`, `Set.Make`); write your own.

Next: Module 8 covers **monads and GADTs**.

:::

You have now seen every piece of the imperative and modular OCaml
toolkit. [Refs](M07-L01-references.html) and
[arrays](M07-L02-arrays-and-mutation.html) for mutation when the
algorithm wants it. [Exceptions](M07-L03-exceptions.html) for
unexpected failures, alongside
[`option` and `result`](M04-L04-recursive-types.html) for
predictable ones. [Modules](M07-L06-module-basics.html) for
grouping and namespacing.
[Signatures](M07-L07-signatures.html) for hiding internals.
[Functors](M07-L08-functors.html) for writing generic data
structures parameterised by element operations. Together they are
enough to structure a real OCaml project at scale.

[Module 8](M08-L01-option-monad.html) turns to two more advanced
abstractions: *monads*, which sequence computations cleanly across
effects ([option](M08-L01-option-monad.html),
[result](M08-L02-laws-list-result.html),
[state](M08-L03-state-monad.html), exceptions, IO), and
[*GADTs*](M08-L04-gadts-basics.html), generalized algebraic data
types, which let you encode richer constraints in the type
system. Both are common in serious OCaml code; both reward the
groundwork we have laid through Modules 1 through 7.

## Reading

- **Cornell CS3110**, *Functors* (the functional queue is a
  worked example late in the chapter):
  <https://cs3110.github.io/textbook/chapters/modules/functors.html>
- **Real World OCaml**, *Functors*:
  <https://dev.realworldocaml.org/functors.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
