---
title: "Linearity: use at most once"
lecture_no: 3
week: 11
duration_target_min: 29
concepts: [linearity, once, many, linear types, closure capture, file handle, resource discipline, linear logic]
keywords: [OCaml, OxCaml, linearity, once, many, linear types, file handle, Linear Logic, Girard]
activity_question: "Given the [Handle] signature, which of three clients fails to type-check? And why does a closure that captures a once-handle itself become once?"
think_about_this: "Rust's ownership system enforces 'this value will be used at most once' through move semantics. OxCaml's linearity is a similar idea, but the value is not the package: the *mode* is. What does it buy you to separate the value from the mode?"
reading:
  - title: "KC Sivaramakrishnan, Linearity and uniqueness (2025-06-04)"
    url: https://kcsrk.info/ocaml/modes/oxcaml/2025/06/04/linearity_and_uniqueness/
  - title: "Oxidizing OCaml: ownership (Jane Street blog)"
    url: https://blog.janestreet.com/oxidizing-ocaml-ownership/
  - title: "Jean-Yves Girard, Linear logic (1987)"
    url: https://www.sciencedirect.com/science/article/pii/0304397587900454
---

# Linearity: use at most once


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Linearity: use at most once</h2>
<p class="title-slide-label">Module 11 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous lecture ended on a puzzle. A closure captured a
unique reference and freed it; calling the closure twice would be
a double-free; and the compiler rejected the program with an
error that uniqueness could not explain. Here is the puzzle
again, live. The first cell recalls the safe reference's `alloc`
and `free` in miniature, so this page stands alone:

```ocaml
(* The previous lecture's alloc / free, recalled in miniature. *)
module M : sig
  type 'a t
  val alloc : 'a -> 'a t @ unique
  val free  : 'a t @ unique -> unit
end = struct
  type 'a t = { mutable value : 'a }
  let alloc x = { value = x }
  let free _t = ()
end
open M
```

```ocaml skip
(* Press Run; the rejection names a mode we have not met. *)
let wat () =
  let t = alloc 42 in       (* t : int t @ unique *)
  let f () = free t in      (* closure captures t *)
  f ();
  f ()                      (* rejected, but on what grounds? *)
```

> Error: This value is used here, but it is defined as once and
> has already been used:
> Line 5, characters 2-3.

"Defined as *once*." That mode belongs to this lecture's axis:
**linearity**. Where the uniqueness axis tracked something about
a value's **past** (has it been aliased before now?), linearity
tracks something about a value's **future**: how many more times
may it be used?

These sound similar but are different. A value can have
no aliases right now (unique) and still be used many times in the
future. A value can be used only once in the future (linear) even
if it has been aliased in the past. The two axes are independent;
they cooperate, but they are not redundant.

For a *resource* like a file handle, linearity is often the
natural axis. The protocol for a file is:

1. Open the file. Get a handle.
2. Read from the handle some number of times.
3. Close the handle.
4. Do not use the handle again.

What the language needs to enforce is step 4 (use no further), not
"the handle has no other references" (which it may, depending on
the program). Linearity is the axis that says "after this use,
there are no more." That is exactly the file-handle discipline.

This lecture introduces the linearity axis, resolves the closure
puzzle, walks through a file-handle module built on the axis,
asks when to reach for uniqueness and when for linearity,
contrasts the result briefly with Rust's ownership, and traces
the idea back to Girard's Linear Logic.

:::slide

## Where we are

- The uniqueness lecture ended on a puzzle.
  - the error: "defined as **once** and has already been used."
- `once` lives on a new axis: **linearity**.
  - uniqueness tracks the *past*: has it been aliased?
  - linearity tracks the *future*: how many more uses?
- This lecture: the axis, the puzzle resolved, a file-handle API,
  and which axis to reach for when.

:::

## The linearity axis, mechanically

Two modes:

- **`many`** (the default): the value may be used any number of
  times in the future. This is the normal world: a string, an
  integer, a list, a function value can be referenced many times.
- **`once`**: the value will be used at most once. After that use,
  the binding is consumed; the compiler refuses any further
  reference to it.

The submoding is `many ⊑ once`. A `many` value can be used
anywhere a `once` value is expected. The intuition: "use many
times" is a *stronger* promise than "use at most once." If you can
use it many times, you can use it once and then stop. The reverse
is rejected: a `once` value cannot satisfy a context that may use
the value many times.

The annotation goes after `@`, like the other axes. For example,
`val close : t @ once -> unit` says that `close` takes a `t` at
mode `once`. Calling `close` consumes that single use. After the
call, the binding is gone; the compiler refuses any further
reference. We will see the full signature in context in a moment.

:::slide

## The linearity axis

| Mode | Meaning | Future uses |
|---|---|---|
| **`many`** (default) | Use any number of times | Unbounded |
| **`once`** | Use at most once | One |

Submoding: `many ⊑ once`. A many-value can flow into a once-slot.
The reverse is rejected.

:::

## A `once` function, explicitly

The simplest way to meet a `once` value is to build one. A
function can declare that the closure it returns is usable at
most once:

```ocaml
let make_once_fn () : (unit -> int) @ once =
  let v @ unique = 42 in
  fun () -> v
```

The body binds `v` at mode `unique` and returns a closure that
captures it. The return annotation says the caller receives the
closure at mode `once`. Using it once is fine:

```ocaml
let use_once () =
  let f = make_once_fn () in
  let result = f () in
  Printf.printf "%d\n" result

let () = use_once ()   (* prints 42 *)
```

Using it twice is rejected:

```ocaml skip
(* Press Run; the second call is the second use of a once value. *)
let use_twice () =
  let f = make_once_fn () in
  let _ = f () in
  f ()
```

> Error: This value is used here, but it is defined as once and
> has already been used:
> Line 4, characters 10-11.

The same error as the `wat` puzzle, now with nothing mysterious
about it: `f` is a `once` value, the first call used it, the
second call is one use too many. The bookkeeping is the same
consumed-binding tracking as the uniqueness lecture's, applied to
*future* uses instead of past aliases.

:::slide

## A `once` function, explicitly

```ocaml skip
let make_once_fn () : (unit -> int) @ once =
  let v @ unique = 42 in
  fun () -> v

let use_twice () =
  let f = make_once_fn () in
  let _ = f () in
  f ()            (* type error: f is once, already used *)
```

- The annotation hands the caller the closure at mode `once`.
- First call: fine. Second call: one use too many.
- Same consumed-binding bookkeeping as uniqueness, aimed at the
  *future*.

:::

## Resolving the closure puzzle

Now the `wat` error from the uniqueness lecture reads cleanly. In
`make_once_fn` we *declared* the closure `once`. In `wat` nobody
declared anything; the compiler *inferred* it. The rule:

**A closure that captures a `unique` (or `once`) value is itself
given mode `once`.**

The reasoning: each call to the closure uses the captured value
once. If the captured value tolerates at most one use (a unique
value being consumed, a once value being used), then the closure
tolerates at most one call. Capture is not consumption, but it
transfers the restriction from the captured value to the closure.

This is automatic. You do not annotate it; the compiler computes
the closure's mode from the modes of its captures. So in `wat`,
the closure `f` captured the unique `t`, the compiler marked `f`
as `once`, the first `f ()` consumed that single use, and the
second `f ()` was rejected, not because `t` was already freed
(the linearity check fires before any value-level reasoning about
`t`), but because `f` itself had already been used.

This is also why the two axes ship together: uniqueness alone
cannot police a unique value that hides inside a closure, and
linearity is exactly the axis that can.

:::slide

## Resolving the closure puzzle

```ocaml skip
let wat () =
  let t = alloc 42 in       (* t : int t @ unique *)
  let f () = free t in      (* closure captures t *)
  f ();
  f ()                      (* error: f is once, already used *)
```

- Rule: a closure capturing a `unique` or `once` value is itself
  `once`.
  - inferred from the captures, no annotation needed.
- Uniqueness alone cannot police a capture.
  - linearity is the axis that can.

:::

## A file-handle module

Here is the running example for this lecture. A small module that
manages file handles, with the type system enforcing the
"open-read*-close" protocol. We will define the module type, the
implementation, and three deliberately buggy clients in turn; the
implementation has to exist first so that the bug demos have an
`open_`, `read`, and `close` to call.

A note on the implementation: this lecture uses an **in-memory
mock** as the backing of `Handle`. The body of `open_` allocates
a small record with an empty buffer; `read` slices substrings;
`close` does nothing. In production you would back the same
signature with `Unix.openfile` / `Unix.read` / `Unix.close`, and
the I/O code would do the real work. The point of the lecture is
not the I/O; it is that the linearity guarantees are entirely
independent of the backing. With a real file descriptor inside,
the type system's "used at most once" contract is exactly the
contract you want on an OS file descriptor. The mock keeps the
runtime trivial so we can focus on the compiler's behaviour.

```ocaml
module type Handle = sig
  type t

  val open_ : string -> t @ once
  (** [open_ filename] opens a file and returns a once-usable
      handle. *)

  val read : t @ once -> int -> string * t @ once
  (** [read t n] reads [n] bytes from [t] and returns the data
      and a fresh once-usable handle. *)

  val close : t @ once -> unit
  (** [close t] closes [t]. The handle is consumed. *)
end

module Handle : Handle = struct
  type t = { mutable buf : string; mutable pos : int }

  let open_ _path =
    (* In production: Unix.openfile path [...] mode and store the
       fd. Here: an empty in-memory buffer. *)
    { buf = ""; pos = 0 }

  let read t n =
    (* In production: Unix.read t.fd buf 0 n and copy. Here:
       safely substring whatever the buffer holds. *)
    let avail = String.length t.buf - t.pos in
    let take = if n < avail then n else avail in
    let s = if take <= 0 then "" else String.sub t.buf t.pos take in
    t.pos <- t.pos + take;
    s, t

  let close _t =
    (* In production: Unix.close t.fd. Here: nothing to release. *)
    ()
end
```

Read each line of the signature:

- `open_` produces a `once` handle. The caller will use it at
  most once, then.
- `read` consumes a `once` handle and returns a *fresh* `once`
  handle. This is the ownership-chain shape from the uniqueness
  lecture:
  threading the handle through each operation lets us call `read`
  many times in sequence, each call consuming its handle and
  producing the next.
- `close` consumes the `once` handle without returning a new one.
  After `close`, there is no live handle to the file.

The implementation itself looks ordinary, and its packaging is
the course's sealed-module discipline: `Handle : Handle` hides
the record, and the signature carries the contract, now with
modes in it. OxCaml's mode checking
is structural, not type-level: the compiler reads the
implementation in light of the declared signature and verifies
that each function respects linearity. The mode bookkeeping is in
the *checker*, not in the runtime.

A correct client looks like this:

```ocaml
let read_two () =
  let t = Handle.open_ "data.txt" in
  let s1, t = Handle.read t 100 in
  let s2, t = Handle.read t 100 in
  Handle.close t;
  s1, s2
```

The handle threads through each call. Each line consumes the
current `t` and rebinds a fresh `t` (or, for `close`, consumes and
returns nothing). At the end of the function, `t` no longer
exists; the file is closed; the strings escape to the caller.

This is *exactly* the same shape as the `Unique_ref` example in
the previous lecture. The shape is generic: any linear/unique
resource API ends up looking like an ownership chain. The
*meaning* differs (linearity tracks future use, uniqueness tracks
past aliasing), but the *programming model* is the same.

:::slide

## File-handle protocol as a type

```ocaml
module type Handle = sig
  type t
  val open_ : string -> t @ once
  val read  : t @ once -> int -> string * t @ once
  val close : t @ once -> unit
end
```

- `open_` produces a fresh once-usable handle.
- `read` consumes and re-produces a once-usable handle.
- `close` consumes without re-producing.

Client uses the **ownership-chain** shape: shadow `t` through
each operation.

:::

:::slide

## A correct client: threading the handle

```ocaml
let read_two () =
  let t = Handle.open_ "data.txt" in
  let s1, t = Handle.read t 100 in
  let s2, t = Handle.read t 100 in
  Handle.close t;
  s1, s2
```

- Each line consumes the current `t` and rebinds a fresh one.
- `close` ends the chain.
  - after it, no live handle exists.

:::

## Another protocol: a send-once channel

The file-handle module is one shape of "use exactly once" API.
The same machinery works for any protocol with a known final
step. A representative variation: a *send-once* channel, the kind
that some message-passing systems hand to one party for a single
send and then expire.

```ocaml
module Send_once_channel : sig
  type 'a t
  val make  : unit -> 'a t @ once
  val send  : 'a t @ once -> 'a -> unit
end = struct
  type 'a t = unit
  let make () = ()
  let send _t x = ignore x  (* in production: deliver the message *)
end
```

Read the signature. `make` produces a once-usable channel.
`send` consumes the channel and delivers the message. After
`send`, the channel does not exist as a once-usable binding;
sending twice is a type error, exactly as double-close was for
the file handle.

A correct client looks like:

```ocaml
let example () =
  let ch = Send_once_channel.make () in
  Send_once_channel.send ch "hello"
```

A bad client (sending twice) fails to type-check:

```ocaml skip
(* Press Run; the second send is rejected. *)
let bad () =
  let ch = Send_once_channel.make () in
  Send_once_channel.send ch "hello";
  Send_once_channel.send ch "again"   (* type error: ch is once,
                                         already used *)
```

The shape recurs: `commit` on a transaction, `consume` on a
generator, `finalise` on a builder, `release` on a lock. Each is
a "once" protocol, and each fits the same mode signature.

:::slide

## A send-once channel

```ocaml
module Send_once_channel : sig
  type 'a t
  val make  : unit -> 'a t @ once
  val send  : 'a t @ once -> 'a -> unit
end = struct
  type 'a t = unit
  let make () = ()
  let send _t x = ignore x  (* in production: deliver the message *)
end
```

- `make` produces a once-usable channel.
- `send` consumes it and delivers the message.

:::

:::slide

## Send-once: one send, no more

```ocaml
let example () =
  let ch = Send_once_channel.make () in
  Send_once_channel.send ch "hello"
```

```ocaml skip
(* Press Run; the second send is rejected. *)
let bad () =
  let ch = Send_once_channel.make () in
  Send_once_channel.send ch "hello";
  Send_once_channel.send ch "again"   (* type error *)
```

- The first send consumes the channel.
- A second send is a second use of a `once` value.

:::

## Two bugs caught, and one that is not

The point of the API is that you cannot misuse it, so let us try.
We walk through three deliberate bugs. The first two cells are
*meant* to fail to compile; press Run on each to see the OxCaml
compiler's refusal inline. The third is the honest surprise of
this lecture.

### Bug 1: double-close

```ocaml skip
(* Press Run; the compiler refuses on linearity grounds. *)
let double_close () =
  let t = Handle.open_ "data.txt" in
  Handle.close t;
  Handle.close t
```

The first `Handle.close t` consumed the handle. The second
`Handle.close t` is attempting to reference a binding that no
longer holds a live once-value. The compiler refuses, with a
message of the form "This value is used here, but it is defined
as once and has already been used", pointing at the offending use
and the prior one.

The corresponding C bug is the canonical double-close: calling
`fclose` twice, or `unix_close` twice, on the same file
descriptor. On Linux, the second call may close some *other*
descriptor (because the kernel has reassigned the integer); on
Windows, behaviour varies. None of this can happen here: the
program does not compile.

### Bug 2: use-after-close

```ocaml skip
(* Press Run; same shape as bug 1, different surface form. *)
let read_after_close () =
  let t = Handle.open_ "data.txt" in
  Handle.close t;
  let _s, _t' = Handle.read t 10 in
  ()
```

Same shape. The `close t` consumed the handle; `read t` then
tries to use it again. The compiler tracks the single allowable
use and rejects the second one with the same "already been used as
once" error.

### Bug 3: forgetting to close, not caught

```ocaml
(* Press Run; this COMPILES. The leak is invisible to linearity. *)
let leak () =
  let t = Handle.open_ "data.txt" in
  let _s, _t = Handle.read t 10 in
  ()
```

This one is the honest limit of the axis. The handle is consumed
by `read`, and the fresh handle returned by `read` is bound to
`_t` and silently discarded. The cell compiles without a murmur.

The reason is in the name of the mode: `once` means *at most*
once, not *exactly* once. The compiler guarantees a once-value is
never used twice; it does not demand that it be used at all. In
the vocabulary of the type-systems literature, OxCaml's linearity
axis is *affine* rather than strictly linear. The pragmatic
reason for the softer rule: exceptions and early exits routinely
abandon values mid-scope, and a type system that made every
abandonment an error would fight ordinary OCaml control flow.

So the forgotten `close` stays what it was in vanilla OCaml: a
silent resource leak, best handled by the runtime patterns from
earlier in the course (`fun_protect`, the `with_`-style wrappers)
or by a finaliser as a backstop. Linearity removes the *double*
uses; it does not chase the missing ones.

:::slide

## Double-close: rejected

```ocaml skip
(* Press Run; the compiler refuses on linearity grounds. *)
let double_close () =
  let t = Handle.open_ "data.txt" in
  Handle.close t;
  Handle.close t
```

- The first `close` consumed the handle.
  - the second is a second use of a `once` value.

:::

:::slide

## Use-after-close: rejected

```ocaml skip
(* Press Run; the same refusal as double-close. *)
let read_after_close () =
  let t = Handle.open_ "data.txt" in
  Handle.close t;
  let _s, _t' = Handle.read t 10 in
  ()
```

- `close` consumed the handle.
  - the `read` is one use too many.

:::

:::slide

## The forgotten `close` compiles

```ocaml
(* Press Run; this COMPILES. The leak is invisible to linearity. *)
let leak () =
  let t = Handle.open_ "data.txt" in
  let _s, _t = Handle.read t 10 in
  ()
```

- The fresh handle lands in `_t` and is silently discarded.
- `once` means *at most* once: zero uses are allowed.
  - affine, not strictly linear.

:::

## The closure rule, on a real resource

The capture rule from the puzzle resolution applies to `once`
captures just as it does to `unique` ones. A closure that
captures the once-handle has the handle's single use built into
it:

```ocaml skip
(* Press Run; the closure captures a once-handle and is itself
   forced to mode once, so a second call fails to type-check. *)
let use_it () =
  let t = Handle.open_ "data.txt" in
  let f = fun () -> Handle.close t in
  f ();
  f ()                  (* type error: f is once, already used *)
```

`f` captures a `once` handle, so `f` is `once`; the second call
is rejected. The rule keeps you from sneaking a once-resource
through an ordinary function value.

:::slide

## Closure capture forces `once`

```ocaml skip
let use_it () =
  let t = Handle.open_ "data.txt" in
  let f = fun () -> Handle.close t in
  f ();
  f ()           (* type error: f used twice *)
```

- A closure capturing a `once` value is `once`.
  - the same inference as the unique-capture rule.
- No sneaking a once-resource through an ordinary function value.

:::

## Linearity vs uniqueness: why both?

The 2025-06-04 blog post devotes a section to this question. The
short answer: each axis captures something the other does not.

**Uniqueness gives modular reasoning.** Compare two signatures
for a deallocation function:

```ocaml
module type Free_unique = sig
  type 'a t
  val free : 'a t @ unique -> unit
end
```

From this signature alone, you can conclude that calling `free`
is safe. The argument: the reference is unique (that is what the
type says); therefore no other live references to the resource
exist; therefore freeing it cannot create a dangling reference,
because there is nothing to dangle. You did not need `free`'s
implementation, the rest of the library, or any call site. The
signature is the contract.

Now the linear-only version of the same API:

```ocaml
module type Free_once = sig
  type 'a t
  val free : 'a t @ once -> unit
end
```

This says "the binding you pass will not be used again after
`free`." From the signature alone, you cannot conclude that no
aliases exist: `once` constrains *this binding's future use*, not
*aliasing*. To prove the API safe, you would have to inspect
every operation that produces a `'a t`, every operation that
consumes one, and the control flow of every client. That is
*whole-API reasoning*.

The submoding direction is what makes the two signatures so
different in strength. The uniqueness axis orders
`unique ⊑ aliased`, so an aliased value cannot flow into a
parameter that demands `unique`. The only way to call
`Free_unique.free` at all is to present a value the compiler has
*proven* has no other live references. The call site supplies a
fact about the *past*, and the body of `free` gets to rely on it:
that demand is hard to satisfy, which is exactly why satisfying
it carries information. The linearity axis points the other way:
`many ⊑ once` means *anything* flows into a `once` parameter,
freely aliased values included. The demand is trivially
satisfiable, so the callee learns nothing about the argument's
history; the annotation's entire content is the forward-looking
promise that `free` will use its argument at most once. The
double-free protection therefore cannot come from `free`'s
signature. It appears only when the *client's own binding* is
`once`, which is why every producer in the API must hand the
value out at `once`, and why the reasoning is whole-API.

**Linearity gives use-once guarantees that survive aliasing.** A
`@ once` handle may have aliases (someone earlier in the program
might have copied it), but the *binding the compiler is tracking*
will be used at most once. The downstream uses go through that
binding; the type system bookkeeps the count.

For some APIs, uniqueness is the right tool: anything resembling
`free`, `destroy`, `drop` where the *resource* is what is being
finalised. For others, linearity is the right tool: anything
resembling a *protocol* with a final step, like `close` on a
handle, `commit` on a transaction, `consume` on a generator.

And for some APIs, you want both. The file-handle module above is
actually a candidate for *both* uniqueness and linearity: the
handle should have no aliases (uniqueness) *and* be used at most
once on each thread of execution (linearity). The minimal version
in this lecture is the linearity-only one; the production API the
tutorial reads at the end of the module combines them.

:::slide

## `Free_unique`: safe from the signature alone

```ocaml
module type Free_unique = sig
  type 'a t
  val free : 'a t @ unique -> unit
end
```

- `free` **demands** `unique`.
  - `unique ⊑ aliased` is one-way: an aliased value cannot
    flow in.
  - the call site must *prove* "no other references".
- A fact about the *past*, supplied by the caller.
  - `free` can rely on it: nothing can dangle.
- **Modular reasoning**: the signature is the contract.

:::

:::slide

## `Free_once`: safe only with a whole-API audit

```ocaml
module type Free_once = sig
  type 'a t
  val free : 'a t @ once -> unit
end
```

- `free` **accepts** `once`.
  - `many ⊑ once`: anything flows in, aliases and all.
  - the callee learns nothing about the past.
- Only a promise about the *future*.
  - `free` uses its argument at most once.
- Double-free safety needs the **client's binding** to be `once`.
  - every producer must hand out `t @ once`: **whole-API
    reasoning**.

:::

:::slide

## Uniqueness vs linearity: when to reach for each

| Axis | Tracks | Best for |
|---|---|---|
| **Uniqueness** | Past aliasing | `free`-style APIs; modular reasoning |
| **Linearity** | Future uses | `close`-style protocols; sequence-of-ops |

For `free`-like APIs, **uniqueness is more appropriate**. Often
combined: the module's tutorial reads a production API that
uses both.

:::

## No aliasing vs no dropping

A complementary way to see the two axes. The classical
substructural-types literature distinguishes "no aliasing"
(uniqueness) from "no dropping" (linearity) cleanly:

- A **unique** value has *no other live references*: copying or
  aliasing it is forbidden. Discarding it is allowed (a unique
  handle that goes out of scope just disappears, like any other
  value).
- A **once** value has *at most one further use*: using it twice
  is forbidden, discarding it is allowed. Aliasing it is *not*
  prevented by linearity (a `once` value can have past aliases;
  what is restricted is *future* use). Classical linear logic
  forbids the discard too; OxCaml's axis is the *affine*
  variant.

Pick the axis by the invariant you need:

- Need "no other references right now" (so `free` is safe):
  reach for **uniqueness**.
- Need "this protocol step must not happen twice" (so a second
  `commit`, `close`, `consume` is rejected): reach for
  **linearity**. The step *happening at all* is not enforced;
  at-most-once has no opinion on zero uses.

The file-handle module in this lecture stays on the linearity
axis alone; the tutorial at the end of the module closes by
reading a production API where uniqueness joins in, for the
cases where the no-aliasing half also matters.

:::slide

## No aliasing vs no dropping

| | Uniqueness | Linearity |
|---|---|---|
| Forbids aliasing? | Yes | No |
| Forbids dropping? | No | No (at most once) |
| Tracks | Past | Future |
| Best for | `free` | `close` |

Pick uniqueness when "no other references" is what matters.
Pick linearity when "never used twice" is what matters.

:::

## A brief comparison to Rust's ownership

If you have written any Rust, the linearity story will feel
familiar. Rust's ownership model is, in a precise sense, an
affine type system in disguise (moved values may also simply be
dropped). When a Rust function takes ownership of
a value (`fn f(x: T)`), the value is "moved" into the function;
the caller cannot use the original binding afterward. Rust's
compiler tracks this just like OxCaml's compiler tracks `once`.

The differences are mostly cosmetic. Rust packages ownership into
the type itself: a `Box<T>` and a `&T` are different types. OxCaml
factors ownership out into a separate *mode*: a `t` and a
`t @ once` are the *same type* used at different modes. The
factoring matters for backward compatibility (an OxCaml program
can use a value at `many` or `once` depending on context, without
changing the type) and for expressing more flexible policies.

The other difference: Rust has *exactly one* axis (ownership +
borrowing). OxCaml has five, and this module covers all of them.
Rust's single axis is opinionated and well-integrated; OxCaml's
factoring gives more design freedom, at the cost of more axes to
remember.

For the purposes of this course, the *intuition* you build for
linearity here transfers to Rust if you ever read Rust code. The
"this value moves; you can't use it twice" mental model is the
same.

:::slide

## Linearity ≈ Rust's move semantics

| Rust | OxCaml |
|---|---|
| `fn f(x: T)` moves `x` | `f : t @ once -> ...` consumes `t` |
| `x` cannot be used after the move | binding cannot be referenced after consumption |
| One axis (ownership + borrowing) | Five axes; linearity is one of them |

Same underlying idea: track which uses are still live.

:::

## A footnote: where linearity comes from

Linear logic was introduced by Jean-Yves Girard in 1987 (the paper
is in the reading list). The original motivation was philosophical
and logical: classical logic has the *contraction* rule, which
says that if you can prove a proposition once, you can use the
proof any number of times. Girard noticed that *removing*
contraction leads to a logic where every proposition is *used
exactly once*. He called this *linear logic*, and it turned out to
have deep computational content: a linear proof can be read as a
program that uses its resources exactly once, with no duplication
and no discarding.

Linear logic powered a wave of research into linear type systems
in the 1990s, including the famous *Linear LISP* and Wadler's
*Linear Types Can Change the World*. The practical adoption was
slow: linear types are useful for resource management, but they
make ordinary programming awkward (you cannot freely copy a value,
which is the dominant thing programmers do). The breakthrough was
realising that you can have *both* worlds in one language: most
values at the default `many` mode, a small minority at `once`,
with cheap coercion `many ⊑ once` and rules for promoting one to
the other when needed.

OxCaml's linearity is this practical packaging of the 1987 idea,
with one pragmatic softening: `once` is *at most* once (affine),
so discarding a value is allowed.
The 2022 ESOP paper *Linearity and Uniqueness: An Entente
Cordiale* by Marshall, Vollmer, and Orchard, cited in the
uniqueness lecture too, brings the linearity and uniqueness threads together in
one formal system: that paper is the academic mirror of what
OxCaml ships.

## Activity

:::quiz mcq id=M11-L03-q1
Given the `Handle` signature in this lecture, which client
fails to type-check? (Decide first; then press Run on each cell
to check.)

```ocaml
(* A *)
let a () =
  let t = Handle.open_ "f" in
  let _, t = Handle.read t 10 in
  let _, _ = Handle.read t 10 in
  ()
```

```ocaml
(* B *)
let b () =
  let t = Handle.open_ "f" in
  let _, t = Handle.read t 10 in
  Handle.close t
```

```ocaml skip
(* C *)
let c () =
  let t = Handle.open_ "f" in
  let s1, _ = Handle.read t 10 in
  let s2, _ = Handle.read t 10 in
  s1, s2
```

- [ ] A only.
- [ ] B only.
- [x] C only.
- [ ] A and C.

**Why:** C is the use-after-consume: the first `read t 10`
consumes `t` (and its fresh handle is discarded into `_`), then C
calls `read t 10` on the *original* `t` again. The compiler
rejects the second use. B is the correct protocol: `read` threads
the fresh handle into the shadowed `t`, then `close` consumes it.
A *compiles*, and that is this lecture's honest lesson in
miniature: A discards the final handle without closing, a
resource leak, and at-most-once linearity has nothing to say
about a value that is never used again. The leak is silent, just
as in vanilla OCaml.
:::

:::quiz mcq id=M11-L03-q2
Inside a function `f`, the type checker reports that `f` itself
has mode `once`, even though you did not annotate it. Which of
these is the most likely cause?

- [ ] `f` is defined at top level.
- [ ] `f`'s body contains a side effect.
- [x] `f` captured a `once` value.
- [ ] `f` returns a value of type `unit`.

**Why:** The rule is: a closure's mode on the linearity axis is at
least as restrictive as the modes of the values it captures. If
the closure captures a `once` value (typically by referencing a
resource defined in the enclosing scope), the closure becomes
`once`. The other options are unrelated to linearity. Top-level
position, side effects, and return types do not by themselves
force `once`.
:::

:::solution

Q1: C is rejected. B threads the handle correctly (the ownership-chain
shape). A *compiles* (the discarded final handle is a silent leak;
at-most-once has no opinion on zero uses). C reads the *original* `t`
twice: the first `read t` consumes `t`, so the second is a second use
of a once-handle.

```ocaml skip
(* C: rejected; the original t is read twice. Run it. *)
let c () =
  let t = Handle.open_ "f" in
  let s1, _ = Handle.read t 10 in
  let s2, _ = Handle.read t 10 in
  s1, s2
```

Q2: a closure that captures a `once` value itself becomes `once`;
capturing is enough to downgrade it.

:::

## Common pitfalls

**Pitfall 1: "Once and unique are the same."** They are not. Once
is about *future use*; unique is about *past aliasing*. A value
can be aliased in the past and `once` in the future. A value can
be unique and used many times. The two axes are independent.

**Pitfall 2: "I can store a `once` value in a record."** You can,
but the record then becomes `once`. Linearity propagates into
containers, so a record carrying a `once` field is itself `once`.
This often surprises programmers used to vanilla OCaml's
permissive treatment of records.

**Pitfall 3: "Returning a `once` value is fine."** It can be, but
only if the *caller* threads it onwards. A function whose return
type is `t @ once` produces a once-handle for the caller to
consume; the caller must respect the discipline or the program
fails to type-check.

**Pitfall 4: "A `once` value can be safely updated in place,
since no one will use it later."** That safety story belongs to
*uniqueness* (see [the uniqueness
lecture](M11-L02-uniqueness.html)): in-place update is safe when
the compiler has proven there are *no other references*. `once`
proves less. It guarantees a second *use* of this binding is
rejected, but aliases made before the value became `once` may
still exist, so linearity alone does not license destructive
update. And recall the affine softening: dropping a `once` value
without ever using it is not caught either.

## What's next

With the three resource axes in hand (locality, uniqueness, and
now linearity), the module turns to concurrency. The next lecture
is **contention**: how a value may be touched once it is shared
across domains. Its sibling **portability** governs which values
may cross a domain boundary at all. The two together
deliver compile-time data-race freedom, and the tutorial
then puts the resource axes to work in one bracketed API.

:::slide

## What's next

- Lecture 4: **contention**. Cross-domain access.
- Lecture 5: **portability**. Cross-domain crossing.
- Lecture 6: tutorial. A bracketed resource-management API,
  designed, implemented, and attacked.

:::

## Reading

- **KC Sivaramakrishnan**, *Linearity and uniqueness* (2025-06-04),
  the *A linear ref* and *Why both linearity and uniqueness?*
  sections in particular:
  <https://kcsrk.info/ocaml/modes/oxcaml/2025/06/04/linearity_and_uniqueness/>
- **Jane Street blog**, *Oxidizing OCaml: ownership*:
  <https://blog.janestreet.com/oxidizing-ocaml-ownership/>
- **Jean-Yves Girard**, *Linear logic* (1987), the foundational
  paper:
  <https://www.sciencedirect.com/science/article/pii/0304397587900454>
- **Wadler**, *Linear Types Can Change the World* (1990), a
  classic early treatment of linear types in programming:
  <https://homepages.inf.ed.ac.uk/wadler/papers/linear/linear.ps>

## Sources

The `Handle` module shape, the explicit once-function example,
and the three-bug walkthrough are adapted from the CS6868 OxCaml
handout (the instructor's own teaching material). The
linearity-vs-uniqueness contrast (including the modular-reasoning
argument) and the past-vs-future framing are paraphrased from the
instructor's 2025-06-04 blog post. The historical footnote on Girard, Wadler,
and the long arc of linear types is original to this course but
relies on standard public-domain history. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
