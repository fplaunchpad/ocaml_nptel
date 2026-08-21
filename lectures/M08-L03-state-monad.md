---
title: "The state monad and parameterised state"
lecture_no: 3
week: 8
duration_target_min: 26
concepts: [monads simulate effects, state monad, STATE_MONAD signature, state functor, threading state, gensym, parameterised monad, parameterised state, type-encoded preconditions, typed stack machine, WebAssembly stack typing]
keywords: [OCaml, state monad, STATE_MONAD, functor, get, set, gensym, parameterised monad, PSTATE_MONAD, stack machine, WebAssembly, let*]
activity_question: "Extend the typed stack machine with [dup] that duplicates the top of the stack (type [('a * 's, 'a * ('a * 's), unit) PState.t]). Show a program that pushes 7, dups, then adds (top becomes 14)."
think_about_this: "The state monad threads one state type throughout. Parameterised state lets the type change per step. What programs become well-typed under the second that the first could not even express?"
reading:
  - title: "Cornell CS3110, Monads"
    url: https://cs3110.github.io/textbook/chapters/conc/monads.html
---

# The state monad and parameterised state


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">The state monad and parameterised state</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous lectures built monads for *failure*
([option](M08-L01-option-monad.html),
[result](M08-L02-laws-list-result.html)) and *non-determinism* (the
[list monad](M08-L02-laws-list-result.html)). Those are two
instances of a much larger pattern. A monad is a reusable way to
*simulate an effect* in otherwise pure code: fix the carrier type
`'a t`, and the one `return` / `bind` / `let*` interface starts
behaving like that effect. State, concurrency, probabilistic choice,
logging, even reversible computation can each be packaged as a
monad. This lecture builds the canonical one, the *state monad*,
which threads a piece of *ambient state* through a chain of steps:
each step receives the current state and returns a new one, with no
mutation. We write it once as a [functor](M07-L08-functors.html)
parameterised by the state type, behind an interface `STATE_MONAD`
that extends the `MONAD` of the
[previous lecture](M08-L02-laws-list-result.html) with two
operations, `get` and `set`. At the end we let the state's *type*
itself change from step to step, the *parameterised* state monad,
which is the first bridge to GADTs.

:::slide

## One pattern, many effects

- A monad is a reusable way to *simulate an effect* in pure code.
  - Fix the carrier `'a t`, and the same `return` / `bind` / `let*`
  behave like that effect.
  - Already seen: `option` / `result` (failure), `list`
  (non-determinism).
- Effects that are "just a monad" too:
  - **state**: a cell threaded through the chain (this lecture).
  - concurrency: `'a Lwt.t`, `'a Eio.Promise.t` (`async` / `await`).
  - probabilistic choice: a distribution monad.
  - reversible / backtracking computation, logging, parsing, ...
- No `ref`, no mutation: the effect lives in the *type*, the
  plumbing in `bind`.

:::

:::slide

## This lecture

- The **state monad**: thread state through a chain without
  mutation. `return`, `bind`, `get`, `set`, `run`.
- Written once as a [functor](M07-L08-functors.html) `State(S)`
  behind the interface `STATE_MONAD`, parameterised by the state
  type.
- Worked example: a `gensym` that issues fresh names.
- State monad versus a plain `ref`.
- **Parameterised state**: when the state's *type* changes per
  step. A typed stack machine whose ill-typed programs are compile
  errors. The bridge to [GADTs](M08-L04-gadts-basics.html).

:::

## Threading state, not mutating it

A *stateful computation* producing an `'a` is a function from the
current state to a pair of (value, new state): `state -> 'a *
state`. This is the carrier `'a t` of the state monad, and it plays
exactly the role that `'a option` played in the option monad and
`'a list` in the list monad: each monad is "a value of shape `'a t`
plus `return` and `bind`", and here the shape happens to be a
*function* rather than a data structure. There is no mutable cell
anywhere; each step takes the state in and hands the next state out,
and `bind` is what lines the output of one step up with the input of
the next.

:::slide

## State without mutation

- A stateful computation of an `'a` is a function `state -> 'a *
  state`.
  - Take the current state, return a value and the next state.
- `return x`: produce `x`, leave the state alone.
- `bind m f`: run `m` on the state, feed its *output* state into
  `f`. The threading is automatic and sequential.
- Two new operations read and write the state:
  - `get`: hand the current state back *as the value*.
  - `set s`: replace the state with `s`, produce `()`.

:::

We saw in the [previous lecture](M08-L02-laws-list-result.html) that
every monad implements one `MONAD` interface. The state monad needs
two operations beyond `return` and `bind`, so its interface
*extends* `MONAD`:

:::slide

## `STATE_MONAD`: the interface

```ocaml
module type MONAD = sig
  type 'a t
  val return : 'a -> 'a t
  val bind   : 'a t -> ('a -> 'b t) -> 'b t
end

module type STATE_MONAD = sig
  type state
  include MONAD                      (* type 'a t, return, bind *)
  val get : state t                  (* read the state          *)
  val set : state -> unit t          (* overwrite the state     *)
  val run : 'a t -> state -> 'a * state
end
```

- *Extends* `MONAD` with `get`, `set`, and `run`.
- `'a t` stays abstract: `get` / `set` are the only handles on the
  state. `run` is the escape hatch (start state in, results out).

:::

The state is always *some* fixed type, but which type depends on the
program: an `int` counter here, a record elsewhere. That is exactly
what [functors](M07-L08-functors.html) are for. We write the
implementation once, parameterised by a module that supplies the
state type:

:::slide

## `State(S)`: one functor, any state type

```ocaml
module State (S : sig type t end) :
  STATE_MONAD with type state = S.t = struct
  type state = S.t
  type 'a t = state -> 'a * state
  let return x = fun s -> (x, s)
  let bind m f = fun s -> let (a, s') = m s in (f a) s'
  let get = fun s -> (s, s)
  let set s' = fun _ -> ((), s')
  let run m s = m s
end
```

- Parameterised by `S.t`: instantiate at `int`, a record, anything.
- `bind` threads state: `m`'s output `s'` feeds `f`'s input.
- `get` reads, `set` overwrites, `run` applies to a start state.

:::

The result signature `STATE_MONAD with type state = S.t` keeps
`state` visible (callers know it is `int`, say) while leaving `'a t`
abstract, just as `Map.Make` exposed `key` but hid the tree. That
abstraction is the point: outside the functor the representation
`state -> 'a * state` is invisible, and the only handles on the
state are `get` and `set`.

## A worked example: gensym

A *gensym* hands out a fresh symbol each time it is called: `x_1`,
`x_2`, `x_3`. The state parks "the next number to use". We
instantiate `State` at `int`, `open` the result so `get`, `set`,
`return`, and `run` are in scope, and bind `let*` to `bind`:

:::slide

## gensym

```ocaml
module IntState = State (struct type t = int end)
open IntState
let ( let* ) = bind

let gensym prefix : string t =
  let* n = get in
  let* () = set (n + 1) in
  return (prefix ^ "_" ^ string_of_int n)

let program =
  let* a = gensym "x" in
  let* b = gensym "x" in
  let* c = gensym "y" in
  return (a, b, c)

let _ = run program 1   (* = (("x_1", "x_2", "y_3"), 4) *)
```

Read the current counter, increment it, return a fresh name.

:::

State starts at 1, ends at 4 (three calls used 1, 2, 3; 4 is the
next available). *The user-facing code never mentions the counter*,
and it could not, since `'a t` is abstract. No `ref`, no `incr`;
the state is implicit in the `let*` plumbing, threaded by
`bind`. And `gensym` is itself the domain helper that hides `get`
and `set`: callers write `gensym "x"`, never `get` or `set`
directly. Wrapping the raw state operations in a meaningfully named
function (`gensym`, `next_token`, `read_byte`) is the usual way to
use the monad.

## State monad versus `ref`

The `ref` version of gensym is shorter:

:::slide

## What you buy versus `ref`

```ocaml
let counter = ref 1
let gensym_ref prefix =
  let n = !counter in
  counter := n + 1;
  prefix ^ "_" ^ string_of_int n
```

Two lines, easy to write. But:

- Not pure: calling twice gives different answers; equational
  reasoning is gone for any function touching `counter`.
- Tests cannot reset without poking the implementation.
- Parallel code races on the cell.

:::

The "tests cannot reset" point is worth seeing concretely. Take two
tests, one that increments once and one that increments twice, each
meant to start from `0`. In the state monad each test is just a
value we `run` from a fresh `0`, so they cannot interfere:

:::slide

## Test isolation: `run` from a fresh state

```ocaml
let incr = let* n = get in set (n + 1)

let test1 = incr                    (* 1 increment  *)
let test2 = let* () = incr in incr  (* 2 increments *)

let _ = run test1 0   (* = ((), 1) *)
let _ = run test2 0   (* = ((), 2) *)
```

- `run prog 0` supplies the initial state, so every test starts at
  `0`.
  - Order-independent and repeatable: `test2` is `2` whether or not
    `test1` ran first.

:::

The shared-`ref` version has no such reset. Both tests read and
write the *same* global cell (the hazard `gensym_ref` already has),
so the second test's result depends on whether the first one ran:

:::slide

## ...but a shared `ref` leaks between tests

```ocaml
let counter = ref 0
let incr_ref () = counter := !counter + 1; !counter

let test1_ref () = incr_ref ()                       (* wants 1 *)
let test2_ref () = let _ = incr_ref () in incr_ref () (* wants 2 *)

let _ = test1_ref ()   (* = 1; counter is now 1 *)
let _ = test2_ref ()   (* = 3, not 2: counter was never reset to 0 *)
```

- One global `counter`, shared by both tests.
  - `test2_ref ()` returns `3`: it started from the `1` that
    `test1_ref` left behind, not from `0`.
- The fix is a manual `counter := 0` between tests; the state monad
  never needs it, because `run` takes the start state as an
  argument.

:::

Pick by scale: a one-off counter, use `ref`; a whole module of
state-threading computations, the monad pays off (state in the
type, local reasoning per step); parallel code, the monad is safer
but more painful. Ask whether you want the state to be a *value*
(visible in types, threaded by the monad) or a *side effect*
(invisible, mutated in place). Both are legitimate.

The same `State` functor, instantiated at a different state type,
becomes a different tool: a PRNG (state is the seed), a parser
(state is the unread input), a type checker (state is the
environment plus a fresh-variable counter). The interface, `return`,
`bind`, `let*`, `get`, `set`, `run`, never changes; only `state`
varies, which is exactly why it is a functor.

## When the state's *type* should change

The `State` functor fixes *one* state type for the whole
computation: `IntState` threads an `int` from start to finish, and
`'a t` is `int -> 'a * int` throughout. But sometimes the state's
type should change between steps. Imagine a small stack machine:
`push 5` turns a stack of shape `'s` into one of shape `int * 's`;
`add` turns `int * (int * 's)` into `int * 's`. The state's *type*
is the running shape of the stack. The fix is to give the carrier
*two* state indices, a `'pre` and a `'post`, and bundle the result
behind its own interface, just as we did for `STATE_MONAD`:

:::slide

## `PSTATE_MONAD`: a parameterised monad

```ocaml
module type PSTATE_MONAD = sig
  type ('pre, 'post, 'a) t
  val return : 'a -> ('s, 's, 'a) t
  val bind : ('p, 'q, 'a) t -> ('a -> ('q, 'r, 'b) t) -> ('p, 'r, 'b) t
  val get : ('s, 's, 's) t
  val set : 'post -> ('pre, 'post, unit) t
  val run : ('pre, 'post, 'a) t -> 'pre -> 'a * 'post
end
```

- Three indices (pre, post, value): can't `include MONAD`.
- `get` / `set` from `STATE_MONAD`, indices freed: `set` changes the
  state's *type*, which is the whole point.

:::

Read `bind`'s indices the way you would a relay race: the first
step carries the state from `'p` to `'q`, hands the baton to the
continuation, which carries it from `'q` to `'r`, and the composite
runs from `'p` to `'r`. The middle type `'q` has to match exactly,
and that handover check is what will let the compiler chain
preconditions step by step.

The implementation is a plain module, not a functor: there is no
single state type to parameterise over, since the type changes per
operation. Otherwise it mirrors `State` exactly, abstract carrier and
all: `get` and `set` are again the only state-aware operations.

:::slide

## `PState`: the implementation

```ocaml
module PState : PSTATE_MONAD = struct
  type ('pre, 'post, 'a) t = 'pre -> 'a * 'post
  let return x = fun s -> (x, s)
  let bind m f = fun s -> let (a, s') = m s in (f a) s'
  let get = fun s -> (s, s)
  let set s' = fun _ -> ((), s')
  let run m s = m s
end
open PState
let ( let* ) = bind
```

- Same bodies as `State`'s `get` / `set` / `return` / `bind`; only
  the *types* are richer.
- Carrier abstract again (`: PSTATE_MONAD`): the only way to touch
  the state is `get` / `set`.

:::

## A well-typed stack machine

Now the payoff use case. We want a stack machine where the *type*
tracks the shape of the stack, so that `add` can run only when there
really are two `int`s on top, and a malformed program is rejected by
the compiler instead of crashing at runtime. We get this directly
from the `PState` monad: take the *state to be the stack itself*,
and each instruction becomes a `PState.t` whose `'pre` and `'post`
indices record how it reshapes the stack.

:::slide

## Goal: ill-typed programs don't compile

- A stack machine where the *type* tracks the stack's shape.
  - `add` runs only with two `int`s on top.
  - A malformed program is a *compile* error, not a runtime crash.
- Built on `PState`: the state *is* the stack.
  - Each instruction is a `PState.t`; its `'pre` / `'post` indices
    record the reshape.

:::

A stack is a *nested pair* with `unit` at the bottom, so its type
records the whole shape. Each instruction is built from `get` and
`set`, never by poking the representation:

:::slide

## Stack instructions, typed by shape

```ocaml
let push (x : 'a) : ('s, 'a * 's, unit) PState.t =
  let* s = get in set (x, s)

let add : (int * (int * 's), int * 's, unit) PState.t =
  let* (x, (y, s)) = get in set (x + y, s)
```

- Each is `let* s = get in set ...`: read the stack, install the new
  one; the type records the shape change.
- `push x`: input `'s`, output `'a * 's`. Adds one element.
- `add`: input *must* be `int * (int * 's)`, output `int * 's` (two
  ints in, one out).

:::

`push x` always succeeds: any stack accepts a value on top. `add`
is fussier: its type `int * (int * 's)` demands at least two `int`s
on top.

One piece of fine print about that `'s`. `push` is a function, but
`add` is a `bind` application, so the
[value restriction](M07-L01-references.html) leaves its `'s` only
*weakly* polymorphic (the toplevel reports `'_s`). Every program in
this lecture uses `add` on stacks with the same tail type, so
nothing notices; if one session reused it at two different
stack-tail types, OCaml would complain at the second use. The fix
is the usual one, making it a function: `let add () = ...`, applied
as `add ()` (the same applies to any instruction defined this way).

Run two pushes and an add and the types line up:

:::slide

## A well-typed program

```ocaml
let prog =
  let* () = push 4 in
  let* () = push 5 in
  add

let _ = run prog ()   (* = ((), (9, ())) *)
```

- Start `()` : `unit`; after `push 4` : `int * unit`; after
  `push 5` : `int * (int * unit)`; `add` consumes both ->
  `(9, ())` : `int * unit`.
- The compiler verifies the stack *shape* at every point is what the
  next instruction needs.

:::

Push a `bool` instead, and `add` can no longer apply. The mismatch
is a *compile* error, not a runtime one:

:::slide

## An ill-typed program is rejected at compile time

```ocaml skip
let bad_prog =
  let* () = push 4 in
  let* () = push true in  (* stack: bool * (int * unit) *)
  add                     (* add wants int * (int * 's) *)
```

```text
Error: This expression has type
         (bool * (int * unit), 'a, 'b) PState.t
       but an expression was expected of type
         (int * (int * 'c), 'd, 'e) PState.t
       Type bool is not compatible with type int
```

- `add` wants two ints on top; after `push true` the top is `bool`.
- The program will not even build.

:::

This is the payoff. "A stack machine that needs two ints on top to
add" is a constraint that lives in the *type* of the operation, and
the compiler enforces it before any code runs.

This is not a toy. It is essentially how **WebAssembly** bytecode is
typed. A Wasm module is *validated* before it runs by tracking the
types on the operand stack, instruction by instruction: every
instruction is specified with a stack type, and `i32.add` has
exactly the type our `add` does, `[i32 i32] -> [i32]`, popping two
`i32`s and pushing one. The validator walks the function body
keeping the operand-stack type up to date and rejects the module if
any instruction does not find the shape it needs, exactly as the
OCaml compiler rejects `bad_prog`. Our `'pre` and `'post` indices
*are* the operand-stack type before and after a step. The same shape
turns up in session types (a client cannot `send` before it
`connect`s) and in typed builders.

:::slide

## Not a toy: this is how WebAssembly is typed

- A Wasm module is *validated* before it runs by tracking the
  operand-stack type, instruction by instruction.
  - `i32.add : [i32 i32] -> [i32]`: exactly our `add`'s type.
- Validation rejects a module whose stack shape is wrong, just as
  OCaml rejects `bad_prog`.
- Our `'pre` / `'post` *are* the operand-stack type before / after a
  step.
- Same shape elsewhere: session types (`connect` before `send`),
  typed builders.

:::

:::slide

## Bridge to GADTs

- Parameterised state encodes preconditions in the *type
  parameters of a function*.
- GADTs (next lecture) encode them in the *type parameters of a
  constructor*.
- Both say: "the type witnesses what state we are in."

:::

The stack machine is one step short of a GADT: the state type *is*
a witness for the shape of the stack at this point. The
[next lecture](M08-L04-gadts-basics.html) makes the pattern
first-class, with constructors that carry such witnesses inline and
pattern matching that refines them.

## A quick check

:::quiz mcq id=M08-L03-q2
After `run program 1` in the gensym example the result is
`(("x_1", "x_2", "y_3"), 4)`. Why does the state end at `4` and not
`3`?

- [ ] The counter is off-by-one due to a bug.
- [ ] OCaml indexing is one-based.
- [x] State `4` is the next unused counter.
- [ ] `run` adds 1 to the final state.

**Why:** each call reads the current `n`, sets the state to `n +
1`, and produces a name using `n`. After producing `y_3` the state
was set to `4`. The final state is the "next available", not the
"last used".
:::

:::quiz mcq id=M08-L03-q3
Why does the ill-typed `let* () = push true in add` fail at compile
time rather than runtime?

- [ ] OCaml defers checking state-monad operations until `run` executes.
- [x] After `push true`, `add` requires two `int`s on the stack.
- [ ] The bool is allocated dynamically.
- [ ] `add` raises an exception immediately.

**Why:** parameterised state encodes each operation's precondition
in its type. `add` says "I take a state shaped `int * (int * 's)`",
so the compiler rejects any preceding chain that does not produce
such a state. No runtime check; the error is caught at compile
time.
:::

:::slide

## Activity

Extend the stack machine with `dup`, which duplicates the top of
the stack: it takes an `'a * 's` state and produces an `'a * ('a *
's)` state. Then write a program that pushes 7, dups, and adds (top
becomes 14). Do not use a `ref`; thread the state with `let*`.

:::

:::solution

:::slide

## Activity solution: `dup`

`PState`, `push`, `add`, `run`, and `let*` are from earlier in this
lecture. `dup` is the one new instruction:

```ocaml
let dup : ('a * 's, 'a * ('a * 's), unit) PState.t =
  let* (x, s) = get in set (x, (x, s))
```

- `get` reads the top `x`; `set (x, (x, s))` puts two copies back.
- Input stack `'a * 's`, output `'a * ('a * 's)`: one element in,
  two out.

:::

:::slide

## Activity solution: the program

```ocaml
let prog =
  let* () = push 7 in
  let* () = dup in
  add

let _ = run prog ()   (* = ((), (14, ())) *)
```

- `push 7` then `dup` leaves two `7`s on top: `int * (int * unit)`.
- Both copies are `int`s, so `add` applies and gives `14`.

:::

:::

A code quiz on the plain state monad:

:::quiz code id=M08-L03-q1
Write `incr_state : unit state` that increments the state by 1 and
produces `()`. Use `get` and `set`. (This is the bare state monad,
before the functor packaging.)

```ocaml
type 'a state = int -> 'a * int
let return x : 'a state = fun s -> (x, s)
let bind (m : 'a state) (f : 'a -> 'b state) : 'b state =
  fun s -> let (a, s') = m s in (f a) s'
let ( let* ) = bind
let get : int state = fun s -> (s, s)
let set new_s : unit state = fun _ -> ((), new_s)
let run (m : 'a state) (s : int) : 'a * int = m s

let incr_state : unit state =
  fun _ -> failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let prog =
  let* () = incr_state in
  let* () = incr_state in
  let* () = incr_state in
  return ()
let () =
  let (_, final) = run prog 10 in
  check (final = 13) "incremented three times from 10";
  let (_, final) = run prog 0 in
  check (final = 3) "incremented three times from 0";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let incr_state =
  let* n = get in
  set (n + 1)
```

Read the state into `n`, then set it to `n + 1`. The value of `set`
is `()`, which is what `incr_state` should produce.

:::

## What is next

:::slide

## What is next

Lecture 4: **GADTs**, the second half of the module.

- Variant constructors that carry their own type indices.
- Pattern matching that refines the index per branch.
- The same idea as the stack-machine state types, made
  first-class.

:::

The [next lecture](M08-L04-gadts-basics.html) starts the GADT half.
The parameterised-state pattern reappears there in rigorous form:
GADT constructors carry type witnesses, pattern matching refines
them, and the compiler tracks state-like information through
expressions naturally.

## Reading

- **Cornell CS3110**, *Monads*:
  <https://cs3110.github.io/textbook/chapters/conc/monads.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The state-monad and parameterised-state framing draw on
the author's CS3100 monads notebook, used here as a private
structural reference; the surface code, comments, and explanations
are written from scratch. Cornell CS3110 and Real
World OCaml are CC BY-NC-ND-licensed and have not been derivatively
reused. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
