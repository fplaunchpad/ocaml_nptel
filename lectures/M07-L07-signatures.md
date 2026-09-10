---
title: "Module signatures"
lecture_no: 7
week: 7
duration_target_min: 22
concepts: [signatures, sig...end, .mli files, abstraction, abstract types]
keywords: [OCaml, signature, sig, mli, abstract type, encapsulation]
activity_question: "Define a module [Logbook] that exposes only [log : string -> unit], [count : unit -> int], and [last : unit -> string option]; hide the internal list ref. Verify that external code cannot read or mutate the ref directly."
think_about_this: "A signature is the type-level description of a module. Once you constrain a module by a signature, what changes from the compiler's perspective? What can external callers stop relying on?"
reading:
  - title: "Cornell CS3110, Signatures"
    url: https://cs3110.github.io/textbook/chapters/modules/encapsulation.html
---

# Module signatures


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Module signatures</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 7</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The [last lecture](M07-L06-module-basics.html) introduced modules:
named bundles of definitions you can refer to with dot notation.
We ran into a
[limitation right at the end](M07-L06-module-basics.html#hiding-internals-the-natural-limitation).
The `Stack` module's internal [`ref`](M07-L01-references.html) was
visible to the outside world, because everything declared in a
module is visible by default. There is no way to write a "private"
helper just with the tools we have so far.

This lecture introduces the fix: *module signatures*. A signature
is a type-level description of a module, listing the names that
escape and the types they have. Once you constrain a module by a
signature, anything *not* listed in the signature becomes
invisible to callers. The signature is the wall between
implementer and user; only what is in the signature crosses it.

This is OCaml's encapsulation story. It is the same idea you have
seen in object-oriented languages under names like `private`,
`public`, and `interface`, but it lives at the *module* level
rather than the value level. The mechanism is structural rather
than nominal, and it is checked entirely at compile time.

:::slide

## This lecture: module signatures

- Last lecture: a `Stack` module's internal `ref` leaked
  out, because everything in a module is visible by default.
- This lecture's fix: *module signatures*.
- A signature is the type-level description of a module: which
  names escape, with which types.
- Constrain a module by a signature; anything not listed
  becomes invisible to callers.
- OCaml's encapsulation story: same idea as `private` /
  `public` / `interface`, at the module level.
- Structural rather than nominal; checked entirely at compile
  time.

:::

## Recall: the stack whose `ref` leaks

Last lecture's `Stack` kept its state in a
[`ref`](M07-L01-references.html) inside the module, with no
interface to hide it:

```ocaml
module Stack = struct
  let s = ref []
  let push x = s := x :: !s
  let pop () =
    match !s with
    | [] -> None
    | x :: rest -> s := rest; Some x
  let peek () =
    match !s with
    | [] -> None
    | x :: _ -> Some x
end
```

Because nothing constrains the module, the internal `s` is just
another name anyone can reach. Outside code can read it and, far
worse, scramble it in ways that make no sense for a stack:

```ocaml
let () = Stack.push 3
let () = Stack.push 1
let () = Stack.push 2
let _ = !Stack.s                             (* = [2; 1; 3] *)

(* sort the stack's internals: meaningless for a LIFO stack *)
let () = Stack.s := List.sort compare !Stack.s
let _ = !Stack.s                             (* = [1; 2; 3] *)
let _ = Stack.pop ()                         (* = Some 1, not Some 2! *)
```

Running `List.sort` on a stack is nonsense: a stack has no
business being sorted, and `pop` should hand back the most
recently pushed element (`2`), not the smallest. But with `s`
exposed, the compiler accepts it without complaint. The invariant
"`pop` returns elements last-in-first-out" is *unenforceable* as
long as the `ref` leaks. This lecture's job is to seal that leak.

:::slide

## Recall: the stack whose `ref` leaks

Last lecture's stack kept its state in a `ref`, with no interface
to hide it:

```ocaml
module Stack = struct
  let s = ref []
  let push x = s := x :: !s
  let pop () =
    match !s with [] -> None | x::r -> s := r; Some x
  let peek () =
    match !s with [] -> None | x::_ -> Some x
end
```

- Everything in the module is visible by default, `s` included.

:::

:::slide

## ...and the `ref` leaks out

```ocaml
let () = Stack.push 3; Stack.push 1; Stack.push 2
let _ = !Stack.s                                 (* = [2; 1; 3] *)
let () = Stack.s := List.sort compare !Stack.s   (* nonsense! *)
let _ = Stack.pop ()                             (* = Some 1, not 2 *)
```

- Outside code reads `s` and even *rewrites* it.
- Sorting a stack is meaningless, yet the compiler allows it.
- `pop` now returns `Some 1`, not the last-pushed `2`: the LIFO
  invariant is broken, and nothing prevented it.

:::

## A first signature

A signature is a `sig ... end` block listing values and their
types. Module type names conventionally begin with an uppercase
letter; many codebases (and most textbooks) use ALL CAPS for the
name, others use ordinary CamelCase. We will use ALL CAPS in this
lecture because it keeps the signature visually distinct from
modules; pick whichever your codebase already uses.

```ocaml
module type COUNTER = sig
  val next : unit -> int
  val reset : unit -> unit
end
```

By itself this declaration creates no module: it is just a
*description*. The keyword `val` is what you write inside a
signature to describe a value, with its type. The signature says
"any module bearing this type provides two functions, `next` and
`reset`, with the listed types." It says nothing about how those
functions are implemented; that is the job of an actual module.

:::slide

## A signature

```ocaml
module type COUNTER = sig
  val next : unit -> int
  val reset : unit -> unit
end
```

- A signature is a `sig ... end` block listing values (here,
  `next` and `reset`) with their types.
- **Convention**: signature names are ALL CAPS.
- The type itself is just a description; it doesn't have an
  implementation yet.

:::

## Constraining a module by a signature

To attach a signature to a module, write the signature after a
colon in the module definition:

```ocaml
module Counter : COUNTER = struct
  let n = ref 0
  let next () = incr n; !n
  let reset () = n := 0
end

let _ = Counter.next ()   (* = 1 *)
let _ = Counter.next ()   (* = 2 *)
let () = Counter.reset ()
let _ = Counter.next ()   (* = 1 *)
```

(`COUNTER` is the module type we declared above.) Two things are
happening at the colon. First, the compiler *checks* that every
value listed
in `COUNTER` is provided by the structure, with a type matching
or more general than what the signature requires. (Both `next`
and `reset` are present with the right types, so the check
passes.) Second, the compiler *hides* anything not in the
signature. The internal `n` is not listed, so from the outside,
`Counter.n` does not exist:

```ocaml skip
let _ = !Counter.n  (* error: Unbound value Counter.n *)
```

The error is *not* a runtime error or a permission warning. It
is a compile-time `Unbound value Counter.n`, exactly as if there
were no such name at all. From the outside, there isn't.

:::slide

## A module conforming to a signature

`COUNTER` is the signature from the previous slide.

```ocaml
module Counter : COUNTER = struct
  let n = ref 0
  let next () = incr n; !n
  let reset () = n := 0
end

let _ = Counter.next ()   (* = 1 *)
let _ = Counter.next ()   (* = 2 *)
let () = Counter.reset ()
let _ = Counter.next ()   (* = 1 *)
```

- Counter compiles because every value listed in `COUNTER` is
  provided by the struct.

:::

:::slide

## The signature hides what it doesn't mention

The internal `n` is **not listed** in `COUNTER`, so it's hidden:

```ocaml skip
let _ = !Counter.n  (* error: Unbound value Counter.n *)
```

- The signature is a *type-level wall* between implementation and
  the outside world.
- `n` is not just inaccessible: from the outside, it doesn't exist.

:::

The terminology here: the signature *seals* the module. Anything
not listed is irrevocably hidden from anyone holding the sealed
module. If you want both a sealed and an unsealed view, you can
define two names:

```text
module CounterFull = struct ... end
module Counter : COUNTER = CounterFull
```

`CounterFull` exposes everything, `Counter` exposes only what
`COUNTER` allows. Most code never needs this; you usually want
the sealed view.

## Why hide internals?

Two reasons, and they are the two reasons every encapsulation
mechanism in every programming language exists.

:::slide

## Why hide internals?

- **Invariants.** External code cannot do `Counter.n := -100`.
- Only `next` and `reset` reach the state; they enforce the rules
  (monotonic, non-negative, ...).
- **Change.** Swap the ref for a Zarith integer, an atomic
  counter, or a database row.
- Callers see the same `next` and `reset`; nothing breaks.

:::

**Invariants.** Suppose you designed `Counter` to count up from
zero, monotonically, never going backwards. With the internal
`ref` exposed, any caller can break that invariant by writing
`Counter.n := -100`. The signature makes the invariant
*enforceable*: external code can only interact with the counter
through `next` and `reset`, and those functions maintain whatever
properties you decided on. The compiler is now your ally in
keeping the invariant intact.

**Change.** Suppose six months from now you decide the counter
should be an [atomic counter](https://en.wikipedia.org/wiki/Linearizability)
for multi-threaded use, or that it should persist its value to a
database, or that it should use [Zarith](https://github.com/ocaml/Zarith)
to handle arbitrary-precision values. None of those changes
affect the *interface*: `next : unit -> int` and `reset : unit ->
unit` work for any underlying representation. With the signature
in place, you can change the implementation freely and no caller
breaks. Without the signature, callers may have come to rely on
the internal `ref`, and your refactor breaks their code.

The first reason is *encapsulation* (hiding for safety); the
second is *abstraction* (hiding for flexibility). Real signatures
do both at once, and both are why the OCaml standard library
exposes types through their operations rather than as raw
records.

## Abstract types

A signature can hide more than just *values*. It can hide the
type of a module's principal representation.

Why would you want that? The `Counter` example so far hid only a
ref. But often the more interesting thing to hide is the *shape*
of the data the module operates on. A stack might be implemented
today as a list and tomorrow as a two-list pair (for amortised
performance) or as a mutable array. If callers know the shape,
they can pattern-match on it directly, or build values of it
without going through the module's constructors, and then any
later change to the representation silently breaks them. Hiding
the type, not just the values, is what gives you the freedom to
change the implementation later without consulting every caller.

```ocaml
module type STACK = sig
  type 'a t
  val empty : 'a t
  val push : 'a -> 'a t -> 'a t
  val pop : 'a t -> ('a * 'a t) option
end

module Stack : STACK = struct
  type 'a t = 'a list
  let empty = []
  let push x s = x :: s
  let pop = function
    | [] -> None
    | x :: rest -> Some (x, rest)
end

let s = Stack.push 1 (Stack.push 2 (Stack.push 3 Stack.empty))
let _ = Stack.pop s   (* = Some (1, <abstr>) *)
```

The key
move is in the signature: `type 'a t` declares that the module
has a parameterised type called `t`, but does *not* say what `t`
is. From outside, `Stack.t` is an *abstract type*: a token you
can pass around but cannot look inside.

Abstract types have a precise birthplace, and it is a security
story. In the 1970s at Edinburgh, Robin Milner's team built the
LCF theorem prover, and ML (OCaml's direct ancestor) was
invented as its scripting language. The design hinged on one
abstract type, `thm`: the only way to construct a value of type
`thm` was through the module exposing the logic's inference
rules. Any value of type `thm`, anywhere in the system, was
therefore a *genuine theorem*; user code could script proof
searches as wildly as it liked without ever being able to forge
one. The type abstraction you just used to protect a stack
representation was invented to protect mathematical truth
([Gordon's history of LCF](https://www.cl.cam.ac.uk/archive/mjcg/papers/HolHistory.html)
tells the story).

:::slide

## Abstract types

A signature can hide the **type** of a module's representation:

```ocaml
module type STACK = sig
  type 'a t
  val empty : 'a t
  val push : 'a -> 'a t -> 'a t
  val pop : 'a t -> ('a * 'a t) option
end

module Stack : STACK = struct
  type 'a t = 'a list
  let empty = []
  let push x s = x :: s
  let pop = function
    | [] -> None
    | x :: rest -> Some (x, rest)
end
```

:::

:::slide

## Using the abstract `Stack`

```ocaml
let s = Stack.push 1 (Stack.push 2 (Stack.push 3 Stack.empty))
let _ = Stack.pop s   (* = Some (1, <abstr>) *)
```

- From outside, `Stack.t` is opaque; you can only build stacks via
  `empty` + `push` and take them apart via `pop`.

:::

:::slide

## Why abstract types matter

- From outside, `Stack.t` is **abstract**: you can't tell it's a list.
- The only way to make or take apart a stack is through `empty`,
  `push`, `pop`.
- Change the representation later (a `Dynarray`, a record that
  caches the depth, ...) and no external code notices.

:::

The implementation knows that `'a t` is `'a list`, and inside the
module you can write `[]` and `::` directly. Outside, code only
sees the abstract `Stack.t`; the only way to *make* a stack is to
start from `Stack.empty` and apply `Stack.push`. The only way to
*take apart* a stack is through `Stack.pop`. Try to write
`Stack.empty :: [1]` from outside and the compiler refuses:
`Stack.empty` has type `'a Stack.t`, not `'a list`.

If you later switch the representation to a `Dynarray`, or to a
record that caches the current depth, no external code notices.
(The same hiding technique lets the queue in the
[module tutorial](M07-L09-tutorial.html) switch to a two-list,
amortised-O(1) representation: the two-list trick is the classic
move for queues, not stacks, since a plain list is already O(1)
for a stack.) The signature is the *only* place the rest of the
program sees the type.

Abstract types are how almost every serious OCaml library is
structured. `Set.t`, `Map.t`, `Hashtbl.t`, `Buffer.t`: all
abstract, manipulated only through the module's operations.

## Signatures in .mli files

In a real OCaml project, you do not usually write inline
signatures. The convention is to put the implementation in
`foo.ml` and the interface in `foo.mli`. The compiler enforces
that `foo.ml` matches `foo.mli` exactly as if you had written
`module Foo : <contents of foo.mli> = struct <contents of foo.ml>
end`.

```text
(* counter.mli *)
val next : unit -> int
val reset : unit -> unit

(* counter.ml *)
let n = ref 0
let next () = incr n; !n
let reset () = n := 0
```

That is the entire idiom. The `.mli` file is a flat list of
specifications: `val`s, `type`s, exceptions, sub-modules. The
`.ml` file is the implementation. Code in other modules sees only
what `counter.mli` lists.

Two benefits over inline signatures: the interface lives in its
own file, which is good for documentation and for readers, and
the compiler checks the match at every build. In a large project,
every module pair (`.ml` and `.mli`) is checked, so the
abstraction is enforced project-wide.

:::slide

## `.mli` files: the same idea, in a separate file

- `foo.ml` is the implementation; `foo.mli` is the interface.
- The compiler enforces that `foo.ml` matches `foo.mli`.

```text
(* counter.mli *)
val next : unit -> int
val reset : unit -> unit

(* counter.ml *)
let n = ref 0
let next () = incr n; !n
let reset () = n := 0
```

Inline `module M : S = struct ... end` is the same idea; `.mli` is
just the disk-file form. We use inline in lecture cells; you'll
see `.mli` files in real projects.

:::

For the rest of this module we keep using inline signatures for
the toplevel-cell examples. In your projects, you will see
`.mli` files alongside every `.ml`, and that is the form to use.

## include: inherit another module

Sometimes you want a module that is "another module plus some
extras." The `include` keyword brings everything from one module
into another.

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
end

module Greet_extended = struct
  include Greet
  let shout name = String.uppercase_ascii (hello name)
end

let _ = Greet_extended.hello "alice"   (* = "hello, alice" *)
let _ = Greet_extended.shout "alice"   (* = "HELLO, ALICE" *)
```

`include Greet` copies all of `Greet`'s definitions into
`Greet_extended` as if they had been written there directly.
`Greet_extended.hello` works because `hello` was included from
`Greet`. `Greet_extended.shout` is the new definition added on
top. Inside the body of `shout`, the name `hello` is in scope
(unprefixed) because `include` brought it in.

:::slide

## `include`: inherit another module

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
end

module Greet_extended = struct
  include Greet
  let shout name = String.uppercase_ascii (hello name)
end

let _ = Greet_extended.hello "alice"   (* = "hello, alice" *)
let _ = Greet_extended.shout "alice"   (* = "HELLO, ALICE" *)
```

- `include Greet` **copies all of `Greet`'s definitions** into
  `Greet_extended`.
- The extended module can then add new ones (like `shout`).
- **Useful for**: extending standard library modules, or for
  layering modules where one is "everything in A plus a bit more".

:::

`include` is the OCaml moral equivalent of inheritance, but it
operates structurally rather than by class hierarchy. It is
commonly used to *extend* a stdlib module with your own helpers
(`include List` followed by your own list utilities, say) or to
layer modules where one is "everything in A plus a bit more."

The distinction with `open`: `open M` brings `M`'s names into the
local scope *temporarily*, but the names are not part of any new
module. `include M` makes the names part of the *enclosing*
module, visible to anyone who later refers to that enclosing
module.

## Module type aliasing

A signature can be given a name and reused, just like a `let`
binding for a value.

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module Int_ord : ORDERED = struct
  type t = int
  let compare = Int.compare
end

module String_ord : ORDERED = struct
  type t = string
  let compare = String.compare
end
```

We have defined a signature `ORDERED` for "any type with a
`compare` operation" and provided two modules that fit. Note that
`compare` returns an `int`, not a `bool`: it follows the standard
three-way contract (negative if the first argument is smaller,
zero if equal, positive if larger). A single `<` would return
only `bool` and could not distinguish "equal" from "greater," so
it would not satisfy `val compare : t -> t -> int`. `Int.compare`
and `String.compare` both honour the three-way contract, which is
why we reach for them rather than rolling our own from `<`. This is
how OCaml encodes what [Haskell](https://www.haskell.org/) calls
a *type class* (`Ord`, the class of types with ordering). The
difference is just where the polymorphism lives: in Haskell, the
class is part of the *type system* and the dispatch is implicit;
in OCaml, the implementation is in a *module* and you pass the
module explicitly to whoever needs it. This explicit-module
approach scales to the *functor* mechanism we cover in the next
lecture.

:::slide

## Module type aliasing

You can name a complex signature:

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module Int_ord : ORDERED = struct
  type t = int
  let compare = Int.compare
end

module String_ord : ORDERED = struct
  type t = string
  let compare = String.compare
end
```

:::

:::slide

## What `ORDERED` buys you

- Two modules implementing the *same* signature.
- This is what Haskell calls a "type class" (`Ord`), encoded by
  hand: a module with `compare` on an abstract `t`.
- It's the **basis of functors**, which we cover next.

:::

## A quick check

:::quiz mcq id=M07-L07-q3
Given this module:

```ocaml
module type S = sig
  val x : int
end

module M : S = struct
  let x = 1
  let y = 2
end
```

Which of the following compiles?

- [x] `let a = M.x`
- [ ] `let b = M.y`
- [ ] `let c = M.z`
- [ ] None of them.

**Why:** the signature `S` lists only `x`. The sealing of `M` by
`S` hides `y`. So `M.x` exists; `M.y` does not (compile error
`Unbound value M.y`); `M.z` never existed at all.
:::

:::quiz mcq id=M07-L07-q2
Given the `STACK` module with abstract `type 'a t`, what happens
if you try `Stack.empty :: [1]`?

- [ ] Returns `[1; Stack.empty]`.
- [ ] Returns `[Stack.empty]`.
- [x] Compile error: types do not match.
- [ ] Runtime error.

**Why:** `Stack.empty` has type `'a Stack.t`, which is *abstract*.
The list `[1]` has type `int list`. The `::` operator wants its
right argument to be a list of the same type as the head. `Stack.t`
and `int list` are different types from the compiler's point of
view (even though they happen to be the same at runtime). The
compiler refuses.
:::

## Activity

:::slide

## Activity

Define a `Logbook` module that exposes only `log : string ->
unit`, `count : unit -> int`, and `last : unit -> string option`.
Hide the internal list ref so external code cannot read or mutate
it directly.

:::

:::quiz code id=M07-L07-q1
Define a sealed `Logbook` module: `log` appends a message,
`count` returns how many have been logged, and `last` returns the
most recent message (or `None`). The signature is written for
you; fill in the implementation, keeping the list of entries
hidden behind it.

```ocaml
module type LOGBOOK = sig
  val log : string -> unit
  val count : unit -> int
  val last : unit -> string option
end

module Logbook : LOGBOOK = struct
  let log _ = failwith "not implemented"
  let count () = failwith "not implemented"
  let last () = failwith "not implemented"
end
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (Logbook.count () = 0) "empty count";
  check (Logbook.last () = None) "empty last";
  Logbook.log "boot";
  Logbook.log "ready";
  check (Logbook.count () = 2) "count after two logs";
  check (Logbook.last () = Some "ready") "last is most recent";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
module type LOGBOOK = sig
  val log : string -> unit
  val count : unit -> int
  val last : unit -> string option
end

module Logbook : LOGBOOK = struct
  let entries = ref []
  let log msg = entries := msg :: !entries
  let count () = List.length !entries
  let last () = match !entries with [] -> None | x :: _ -> Some x
end

(* Try Logbook.log "boot" and Logbook.log "ready" after checking
   your answer; count then returns 2 and last returns Some "ready". *)
```

- Most recent message is at the head: `log` prepends.
- Try `let _ = !Logbook.entries`: the compiler refuses with
  `Unbound value Logbook.entries`; the signature hid it.

:::

:::

The list of entries is private to the module; the only way in is
`log`, and the only ways to observe it are `count` and `last`.
Outside, `Logbook.entries` has *vanished*: `!Logbook.entries` is
no longer a valid expression. The encapsulation is total and
checked at compile time.

If you wanted to change the implementation later, say to keep the
entries in a `Buffer` or a `Dynarray`, or to cap the log at the
last hundred messages, no external code would notice. The
signature is the contract; the rest is implementation detail.

## What's next

The [next lecture](M07-L08-functors.html) introduces *functors*:
modules parameterized by other modules. A functor is the way OCaml
writes *generic* code that depends not just on a type but on the
*operations* on that type. The classic example is the standard
library's `Map.Make` and `Set.Make`: you give them an ordered type
(a module with `t` and `compare`), and they return a full map or
set module specialised to that type. This is how the standard
library stays generic and how you build your own generic data
structures.

:::slide

## What's next

Lecture 8: **functors**.

- A functor is a module that takes another module as an argument
  and produces a new module.
- The way OCaml expresses "parameterize over a type with its
  operations".

:::

## Reading

- **Cornell CS3110**, *Encapsulation*:
  <https://cs3110.github.io/textbook/chapters/modules/encapsulation.html>
- **Real World OCaml**, *Files, Modules, and Programs*:
  <https://dev.realworldocaml.org/files-modules-and-programs.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
