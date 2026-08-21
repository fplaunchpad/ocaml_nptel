---
title: "Tutorial: a resource-management API"
lecture_no: 6
week: 11
duration_target_min: 21
concepts: [tutorial, file handle, bracket, with_handle, locality, linearity, uniqueness, resource management, API design]
keywords: [OCaml, OxCaml, tutorial, file handle, with_handle, bracket, local, once, unique]
activity_question: "Why does [with_handle] take its callback at [@ once], and which mode stops the handle from being stashed in a global [ref] for later use?"
think_about_this: "C's [fopen]/[fclose] protocol relies on every programmer pairing the two calls, on every path, including the error paths. Sketch a [with_file] combinator whose *type alone* makes the pairing automatic and the handle impossible to retain."
reading:
  - title: "OxCaml documentation, modes overview"
    url: https://oxcaml.org/documentation/modes/
  - title: "CS6868 OxCaml handout (KC Sivaramakrishnan)"
    url: https://github.com/kayceesrk/cs6868_s26
---

# Tutorial: a resource-management API


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: a resource-management API</h2>
<p class="title-slide-label">Module 11 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous five lectures introduced the five mode axes and
worked small examples for each. This tutorial puts the resource
axes to work in one production-shaped API: a **bracketed**
file-handle module, where the library opens the file, hands your
callback a handle that *cannot leave the callback*, and
guarantees the close, even when your code raises. We design the
signature, write the implementation, attack it three ways, and
close by reading a real signature from the OxCaml ecosystem that
scales the same idea up using every axis this module taught.

:::slide

## Today's plan

1. The design problem: a file-handle protocol.
2. The trick: do not expose `open` and `close`.
3. The bracketed signature.
4. The implementation: a sealed module.
5. Attack the API three ways.
6. Why the callback is `@ once`.
7. Compare to C's `FILE *`.

:::

## The design problem

We want a file-handle module that delivers four guarantees:

1. **Open and close are always paired.** Every successful open is
   followed by exactly one close, on every path, including the
   paths where the client's code raises an exception.
2. **No handle escape.** The handle cannot outlive its file: no
   stashing it in a global `ref`, no returning it, no capturing
   it in a closure that runs later.
3. **No double close.**
4. **No use after close.**

The resource lectures earlier in the course built these from
runtime discipline: the positional `fun_protect` combinator
paired the open with the close, and convention did the rest. The
locality lecture then showed the compiler rejecting an escaping
handle. This tutorial assembles the full package, and the key
design move is the first guarantee's: **do not expose `open` and
`close` at all.** If the client can never call `close`, the
client can never call it twice, never use a handle after it, and
never forget it. The library brackets the resource; the client
only ever sees the middle.

Notice what the design is made of. An abstract type behind a
sealed module, a higher-order combinator that lends a resource to
a callback, a signature serving as the contract: every move is
from the first half of the course. The modes are the only new
ingredient, and their job is to make the old moves' promises
checkable.

:::slide

## The design problem

| Guarantee | Delivered by |
|---|---|
| Open and close always paired | the bracket |
| No handle escape | locality (`@ local`) |
| No double close | unwritable: `close` is not exposed |
| No use after close | unwritable, for the same reason |

The design move: the client never sees `open` or `close`. The
library brackets the resource; the client writes the middle.

- Sealed module, higher-order bracket, signature as contract.
  - all from the FP half of the course.
  - the modes are the only new ingredient.

:::

## The signature

Here is the whole module type; press Run:

```ocaml
module type Handle = sig
  type t
  val with_handle : string -> (t @ local -> 'a) @ once -> 'a
  val read  : t @ local -> int -> string
  val write : t @ local -> string -> unit
end
```

Read each piece:

- `with_handle path f` is the only way in. It opens the file,
  runs `f` on the fresh handle, closes the file, and returns
  whatever `f` returned. There is no `open_` and no `close` for
  the client to misuse: the bracket owns both ends.
- The callback receives the handle at **`t @ local`**: the
  handle belongs to the callback's region and cannot leave it.
  Locality is what turns "please don't keep the handle" into a
  compile-time fact.
- `read` and `write` accept the handle at `@ local`, so they can
  be called freely *inside* the bracket; their results (`string`,
  `unit`) are ordinary global values that may flow out.
- The callback itself is **`@ once`**: the bracket promises to
  run it at most one time. There is a deeper reason this
  annotation matters, and it is easier to appreciate after we
  have attacked the API, so we return to it below.

:::slide

## The signature

```ocaml
module type Handle = sig
  type t
  val with_handle : string -> (t @ local -> 'a) @ once -> 'a
  val read  : t @ local -> int -> string
  val write : t @ local -> string -> unit
end
```

- `with_handle` is the only way in: no `open_`, no `close`.
- The handle is `@ local`: it cannot leave the callback.
- The callback is `@ once`: the bracket runs it at most once.

:::

## The implementation

The implementation is a *sealed* module: `open_` and `close`
exist inside, but the signature ascription hides them, so no
client can name them. The bracket pairs them with the
`match ... with exception` shape that the `fun_protect`
combinator used earlier in the course, so the close happens on
the exception path too.

As in the rest of the module, the backing is an **in-memory
mock** (the browser toplevel has no real file system): the handle
carries a mutable buffer and a cursor, and `open_` and `close`
print a tag so you can *see* the bracket doing its job in every
demo below. In production they would be `Unix.openfile` and
`Unix.close`; not one mode annotation would change.

```ocaml
module Handle : Handle = struct
  type t = { mutable buf : Bytes.t; mutable pos : int }
  let open_ _path = print_endline "[open]";
    { buf = Bytes.create 0; pos = 0 }       (* prod: Unix.openfile *)
  let close _t = print_endline "[close]"    (* prod: Unix.close *)
  let with_handle path f =
    let t = open_ path in
    match f t with
    | result -> close t; result
    | exception e -> close t; raise e
  let read (t @ local) n =                  (* prod: Unix.read *)
    let avail = Bytes.length t.buf - t.pos in
    let take = if n < avail then n else avail in
    let s = if take <= 0 then "" else Bytes.sub_string t.buf t.pos take in
    t.pos <- t.pos + take;
    s
  let write (t @ local) s =                 (* prod: Unix.write *)
    t.buf <- Bytes.cat t.buf (Bytes.of_string s)
end
```

A few points to note. The handle record is created as an ordinary
global value inside `with_handle` and *coerces* to `local` when
passed to `f` (`global ⊑ local`, from the locality lecture): the
implementation keeps full rights, the callback gets restricted
ones. `read` and `write` accept `(t @ local)` and freely read and
write its mutable fields; `local` restricts where a value may
*go*, not what you may do with it while it is in scope. And the
`string` that `read` returns is fresh global data, so it flows
out of the bracket without ceremony.

## Correct usage

A client opens, uses, and never thinks about closing:

```ocaml
let example () =
  Handle.with_handle "scratch.txt" (fun h ->
    Handle.write h "hello";
    Handle.read h 5)

let () = print_endline (example ())
(* [open]
   [close]
   hello *)
```

The `[open]` / `[close]` tags from the mock show the bracket
pairing the two ends. Now the path that runtime discipline always
gets wrong: the client's callback *raises*. The bracket still
closes:

```ocaml
let () =
  try Handle.with_handle "boom.txt" (fun _h -> failwith "boom")
  with Failure _ -> print_endline "caught"
(* [open]
   [close]
   caught *)
```

This is the first guarantee, delivered: open and close are
paired on every path, and no client code can unpair them. The
forgotten-`close` leak that the linearity lecture honestly
admitted it could not chase is simply gone; there is nothing for
the client to forget.

:::slide

## Correct usage: the bracket closes, always

```ocaml
let example () =
  Handle.with_handle "scratch.txt" (fun h ->
    Handle.write h "hello";
    Handle.read h 5)

let () = print_endline (example ())
```

```ocaml
let () =
  try Handle.with_handle "boom.txt" (fun _h -> failwith "boom")
  with Failure _ -> print_endline "caught"
```

- The forgotten-`close` leak is gone: there is nothing to
  forget.

:::

## Attack the API

Now try to break it. Three attacks, in increasing order of
sneakiness.

### Attack 1: stash the handle for later

Store the handle in a global `ref` during the callback, to use
after the bracket returns. In C, saving the `FILE *` in a global
works, and is the root of every use-after-close. Here:

```ocaml skip
(* Press Run; locality refuses to let the handle out. *)
let stash : Handle.t option ref = ref None
let () = Handle.with_handle "f" (fun h -> stash := Some h)
(* Error: This value is "local" to the parent region but is
   expected to be "global" because it is contained (via
   constructor "Some") in the value ... which is expected to be
   "global". *)
```

The handle is `local` to the callback's region; the global `ref`
demands a global value; the assignment is rejected. The compiler
even names the route: the handle would have escaped *via the
constructor `Some`*.

### Attack 2: return the handle

Skip the `ref`; just return the handle as the callback's result:

```ocaml skip
(* Press Run; the result must be global, the handle is not. *)
let leaked = Handle.with_handle "f" (fun h -> h)
(* Error: This value is "local" to the parent region but is
   expected to be "global". *)
```

The signature says `f : t @ local -> 'a`, and a plain `'a` is a
global result. A local handle cannot be the result, so the
callback cannot smuggle it out as its return value. The same
refusal catches the closure variant (returning
`fun () -> Handle.read h 10`), because the closure captures the
local handle and becomes local itself.

### Attack 3: close it twice

In the threading designs we sketched earlier in the module, a
double-close was a *type error*. Here it is something better:

```ocaml skip
(* Press Run. *)
let () = Handle.with_handle "f" (fun h ->
  ignore (Handle.read h 1);
  Handle.close h)
(* Error: Unbound value "Handle.close" *)
```

`Unbound value`. The misuse is not rejected; it is
*unwritable*. There is no `close` in the signature, so there is
no program text that closes twice, or closes early and reads
after. The C bug classes catalogued as CWE-1341 (double release)
and CWE-416 (use after free) have no spelling in this API.

:::slide

## Attack 1: stash the handle

```ocaml skip
(* Press Run; locality refuses to let the handle out. *)
let stash : Handle.t option ref = ref None
let () = Handle.with_handle "f" (fun h -> stash := Some h)
```

- The handle is `local` to the callback's region.
- The global `ref` demands a global value.
- The error names the escape route: via constructor `Some`.

:::

:::slide

## Attacks 2 and 3: return it, close it

```ocaml skip
(* Press Run; the result must be global, the handle is not. *)
let leaked = Handle.with_handle "f" (fun h -> h)
```

```ocaml skip
(* Press Run. *)
let () = Handle.with_handle "f" (fun h ->
  ignore (Handle.read h 1);
  Handle.close h)
```

- Returning the handle: a plain `'a` result is global. Rejected.
- Closing it: `Unbound value Handle.close`.
  - not rejected: **unwritable**. The signature has no `close`.

:::

## Why is the callback `@ once`?

One annotation in the signature is still unexplained: the
callback is declared `@ once`. Why?

Suppose it were not. The callback parameter would sit at the
default `many`, meaning "I may call this any number of times,"
and a `many` function may not touch `once` values. The
consequence: **you could not call any `@ once` function in the
body of the bracket.** Perfectly reasonable client code would be
rejected.

To see it, here is `Handle_many`: exactly the same signature,
except the `@ once` annotation on the callback has been dropped.
Press Run:

```ocaml
module type Handle_many = sig
  type t
  val with_handle : string -> (t @ local -> 'a) -> 'a
  val read  : t @ local -> int -> string
  val write : t @ local -> string -> unit
end
```

The implementation behind it is `Handle`'s, unchanged, sealed
behind this weaker signature:

```ocaml
module Handle_many : Handle_many = struct
  type t = { mutable buf : Bytes.t; mutable pos : int }
  let open_ _p = print_endline "[open]"; { buf = Bytes.create 0; pos = 0 }
  let close _t = print_endline "[close]"
  let with_handle path f =
    let t = open_ path in
    match f t with
    | result -> close t; result
    | exception e -> close t; raise e
  let read (t @ local) n =
    let avail = Bytes.length t.buf - t.pos in
    let take = if n < avail then n else avail in
    let s = if take <= 0 then "" else Bytes.sub_string t.buf t.pos take in
    t.pos <- t.pos + take;
    s
  let write (t @ local) s =
    t.buf <- Bytes.cat t.buf (Bytes.of_string s)
end
```

Now a dummy `unit -> unit` function carrying the `@ once`
annotation. Calling it inside `Handle_many`'s bracket is
rejected:

```ocaml skip
(* Press Run; the many-callback may not touch a once value. *)
let () =
  let (dummy @ once) = fun () -> () in
  Handle_many.with_handle "f" (fun _h -> dummy ())
(* Error: The value "dummy" is "once" but is expected to be
   "many" because it is used inside the function ... which is
   expected to be "many". *)
```

The same call inside our `Handle`, whose callback is declared
`@ once`, goes through:

```ocaml
(* The once-callback bracket accepts the same body. Press Run. *)
let () =
  let (dummy @ once) = fun () -> () in
  Handle.with_handle "f" (fun _h -> dummy ())
(* [open]
   [close] *)
```

So the annotation is the bracket telling the truth about itself:
it calls the callback at most one time, and saying so is what
lets the body use `once` values. And since `many ⊑ once`,
ordinary callbacks are accepted as before; the annotation only
*adds* legal clients, it never subtracts.

:::slide

## Why is the callback `@ once`?

Suppose it were not: the callback would be `many`, and a `many`
function may not touch `once` values.

```ocaml
module type Handle_many = sig
  type t
  val with_handle : string -> (t @ local -> 'a) -> 'a
  val read  : t @ local -> int -> string
  val write : t @ local -> string -> unit
end
```

Identical to `Handle`, except the `@ once` has been dropped: the
callback is now `many`.

:::

:::slide

## A `once` function cannot enter a `many` bracket

```ocaml skip
(* Press Run; the many-callback may not touch a once value. *)
let () =
  let (dummy @ once) = fun () -> () in
  Handle_many.with_handle "f" (fun _h -> dummy ())
```

```ocaml
(* The once-callback bracket accepts the same body. Press Run. *)
let () =
  let (dummy @ once) = fun () -> () in
  Handle.with_handle "f" (fun _h -> dummy ())
```

- `f @ once` is the bracket telling the truth: one call, at most.
  - the truth is what admits `once` values into the body.

:::

## Comparison to C's `FILE *`

Here is the file protocol C gives you:

```c
FILE *fopen(const char *path, const char *mode);
size_t fread(void *ptr, size_t size, size_t count, FILE *stream);
int fclose(FILE *stream);
```

Nothing in these types says "pair `fopen` with `fclose` on every
path," "do not keep the pointer," or "do not close twice." The
protocol lives in the documentation, and every C codebase
re-implements the bracket by hand, with `goto cleanup` chains and
code review standing in for the type checker. The libc runtime
checks are partial at best: `fclose` on a closed stream is
undefined behaviour, and the stale-pointer reads that follow a
missed pairing are this course's oldest enemies.

The OxCaml bracket moves the whole protocol into one type:

```text
val with_handle : string -> (t @ local -> 'a) @ once -> 'a
```

Pairing is the library's code, written once. Retention is a
locality error. Double-close has no syntax. The type checker is
the code review.

:::slide

## C vs the OxCaml bracket

| Property | C `FILE *` | `with_handle` |
|---|---|---|
| open/close paired | discipline, every path | the bracket, incl. exceptions |
| handle retention | compiles, crashes later | locality error |
| double close | undefined behaviour | unwritable: no `close` |
| bugs found at | runtime, in production | compile time, or no spelling |

The protocol of use became one type. The type checker is the
code review.

:::

## Where this pattern recurs

A short list of where this kind of API discipline pays off.

**Database connections.** A pooled connection is borrowed, used,
returned: `with_connection pool use`. The bracket returns the
connection to the pool; locality keeps the callback from keeping
a copy.

**Cryptographic keys.** Key material is loaned to a signing
callback and zeroed by the bracket afterwards; a retained
reference would defeat the zeroing.

**Mapped memory.** A `mmap`'d region must be `munmap`'d exactly
once; `with_mapped` owns both ends, and the region's pointer
must not survive the unmap.

**Iterators over external state.** A cursor into a database or a
directory walk holds OS resources; the bracket frees them when
the walk ends, and locality stops the cursor from being used
after.

The pattern recurs because the underlying *protocol* recurs:
acquire, lend, release. The bracket is the shape of "lend."

:::slide

## Where this pattern recurs

- Database connection pools: `with_connection`.
- Cryptographic key material: loaned, then zeroed.
- `mmap`'d memory regions: `with_mapped`.
- Cursors and directory walks: freed when the walk ends.

Acquire, lend, release. The bracket is the shape of "lend."

:::

## The production pattern: where `unique` fits

One axis from the module did not appear in our API:
**uniqueness**. It is not an accident: inside a single bracket,
the library owns the resource and the callback merely borrows it,
so `local` and `once` carry the whole design. Uniqueness earns
its keep when *ownership itself must travel*: between brackets,
across data structures, from one part of a program to another.

You do not have to take that on faith. Here is a signature from
the `capsule` library that ships with the OxCaml toolchain (the
compile-time lock discipline mentioned in the further reading),
lightly abridged:

```text
val with_password
  :  'k Key.t @ unique
  -> f:('k Password.t @ local -> 'a) @ local once
  -> 'a * 'k Key.t @ unique
```

Every idea in this tutorial is in that type, plus the one we
deferred:

- the **bracket**: `with_password ... ~f` lends a capability and
  takes it back;
- the **`local`** capability: the `Password.t` exists only inside
  the callback, exactly like our handle;
- the **`once`** callback: the bracket runs `f` at most once;
- and **`unique` ownership that travels**: the `Key.t` is the
  long-lived ownership of the protected state. It arrives
  `unique`, and the bracket hands it back in the result, the
  ownership-chain threading from the uniqueness lecture, used
  across brackets rather than inside one.

The library's documentation says it in one line: the uniqueness
of the key "guarantees that only one thread can access the
capsule at a time." Our tutorial API is the same design one size
smaller; when your resource's ownership needs to move around,
the unique-threaded key is the next size up.

## Activity

:::quiz mcq id=M11-L06-q1
`with_handle` declares its callback at `@ once`:

```text
val with_handle : string -> (t @ local -> 'a) @ once -> 'a
```

What would break if the callback were left at the default
`many`?

- [ ] Nothing; `many` and `once` are interchangeable here.
- [x] A `many` callback cannot call `once` functions.
- [ ] The handle could escape the callback.
- [ ] The bracket might run the callback twice.

**Why:** a `many` function is one that may be called any number
of times, so it may not touch `once` values; the `Handle_many`
demo shows the rejection ("once but is expected to be many").
Declaring `f @ once` is the bracket telling the truth, it calls
the callback at most one time, and that truth is what admits
`once` values into the body. Escape is locality's job, not
linearity's, and the bracket's own code determines how many
times it runs `f`, not the annotation. Since `many ⊑ once`,
ordinary callbacks are accepted either way; the annotation only
adds legal clients.
:::

:::quiz mcq id=M11-L06-q2
Match the misuse to what stops it. A client (a) stores the handle
in a global `ref` during the callback, (b) calls `Handle.close`
twice. What stops each?

- [ ] (a) linearity, (b) linearity.
- [ ] (a) locality, (b) linearity.
- [x] (a) locality; (b) the signature exposes no `close`.
- [ ] (a) the bracket controls escape; (b) locality controls closing.

**Why:** the stash is a mode error: the handle is `@ local` to
the callback's region, and a global `ref` cell can only hold
global values; the compiler points at the escape route ("via
constructor `Some`"). The double-close needs no mode at all: the
signature exposes no `close`, so there is no program text that
performs it, once or twice. Sealing the module turns a whole bug
class from "rejected" into "unwritable," which is the strongest
guarantee in this lecture.
:::

:::solution

Q1: `once` on the callback is for the *caller's* benefit. The
closure rule makes once-capturing callbacks `once`; a bracket
demanding `many` would reject them, and `f @ once` welcomes them
while still accepting every ordinary callback (`many ⊑ once`).

Q2: the stash is stopped by locality (`local` handle, global
`ref`, no flow). The double-close is stopped by the seal: no
`close` in the signature means the misuse has no spelling at all.

:::

## Common pitfalls

**Pitfall 1: "`local` makes the handle read-only."** No.
`read` and `write` mutate the handle's fields freely. Locality
restricts where a value may *go* (it cannot leave its region),
not what you may do with it while it is in scope.

**Pitfall 2: "The bracket plus `local` made linearity
redundant."** Inside one bracket, mostly yes, and that is the
point of the design. But `once` still does two jobs here: it is
the honest type of the callback (the bracket runs it at most
once), and it admits callbacks that capture once/unique values.
And when ownership must travel between brackets, the
unique-threaded key pattern is exactly the linearity-style chain
again.

**Pitfall 3: "Sealing is just hiding; a determined client can
still misuse the resource."** Within the language, no: there is
no `Handle.close` to call and no way to conjure a `t` outside a
callback. The guarantee is as strong as the abstraction boundary,
which is why the signature, not the implementation, is the
security review surface.

**Pitfall 4: "The mock makes the demo unrealistic."** The mode
discipline never mentions the backing. Swap the mock's body for
`Unix.openfile` / `Unix.read` / `Unix.close` and not one
annotation changes; the bracket, the locality wall, and the seal
are identical. (That swap is exactly what the production
libraries do.)

## Module summary

We have spent the module on five OxCaml mode axes:

- **Locality**: tracks whether a value escapes its
  scope. Replaces the C `return &x` bug. Lets you stack-allocate
  short-lived values safely, and walls a lent resource into its
  bracket.
- **Uniqueness**: tracks whether a value has been
  aliased in the past. Gives modular reasoning from signatures
  alone, and lets ownership travel safely.
- **Linearity**: tracks whether a value will be used
  again in the future. Replaces use-after-close and double-close
  (and is honest about the leak: at most once, not exactly once).
  Provides the protocol vocabulary for resource APIs.
- **Contention**: tracks whether a value is being
  shared across domains. `Atomic.t` mode-crosses contention so it
  can be hammered on by many domains safely.
- **Portability**: tracks whether a value can cross
  a domain boundary. Closures that mutate captured state are
  `nonportable`; `Domain.Safe.spawn` requires `portable`.

Five axes, eleven modes in all (`global`/`local`,
`unique`/`aliased`, `many`/`once`,
`uncontended`/`shared`/`contended`, `portable`/`nonportable`),
each independent. The
compiler checks all of them simultaneously. The cost is zero at
runtime; the benefit is whole categories of bugs becoming
impossible. This is the two-sided promise the module opened with:
*control* (stack allocation and zero-allocation hot loops, from
locality) and *safety* (no escapes, no use-after-free, no
double-close, no data races), in one type system.

The same shape of argument ran through all five: a runtime
discipline (careful scoping, manual release protocols, locking,
careful sharing) became a compile-time invariant. That closes an
arc that began two modules ago. The testing module sampled runs
for evidence; the memory-safety module mapped exactly where the
language's guarantees stop; this module moved the missing
guarantees into the type system, where they hold for every run.
The CS6868
OxCaml handout linked at the top of this lecture is the most
comprehensive treatment of the deeper end of the design
(capsules, fork-join, parallel arrays).

:::slide

## Module 11 summary

| Axis | Default | Other mode(s) | Tracks | Replaces |
|---|---|---|---|---|
| Locality | `global` | `local` | Escape | `return &x` |
| Uniqueness | `aliased` | `unique` | Past aliasing | use-after-free, double-free |
| Linearity | `many` | `once` | Future use | use-after-close, double-close |
| Contention | `uncontended` | `shared`, `contended` | Cross-domain access | racy reads on shared mutable state |
| Portability | `nonportable` | `portable` | Cross-domain crossing | shared `ref` racing |

Five axes, zero runtime cost: what testing sampled and M10
mapped, modes now prove, for every run.

:::

## What's next

Module 11 closes the type-level chapter of the safety story. The
next module (M12) zooms out: if the language is this safe, what
falls out if you write the *operating system* itself in OCaml?
The answer is **unikernels**, and that is where we go next.

:::slide

## What's next

- Module 12: **Unikernels (MirageOS)**. What an OS looks like
  when the whole stack is written in safe OCaml.

:::

:::slide

## Closing thoughts: from modes to systems

- M11 built a typed mental model: protocol of use becomes type.
- The same protocol-as-contract thinking recurs at the systems
  level: network buffers, device handles, scheduler tokens.
- Module 12: MirageOS unikernels: small, single-purpose,
  library-OS appliances written in safe OCaml end to end.

Safety as something you build in with the language, not bolt on
afterwards: that idea carries from this module's APIs to the
next module's operating systems.

:::

## Reading

- **OxCaml documentation**, the modes overview:
  <https://oxcaml.org/documentation/modes/>
- **CS6868 OxCaml handout** (KC Sivaramakrishnan), the
  comprehensive treatment including contention, portability,
  capsules, and fork-join parallelism:
  <https://github.com/kayceesrk/cs6868_s26>
- **OxCaml ICFP 2025 tutorial**, the hands-on exercises:
  <https://github.com/oxcaml/tutorial-icfp25>
- The blog posts that anchored the locality lecture (Jane
  Street's *Oxidizing OCaml: locality*) and the uniqueness and
  linearity lectures (KC Sivaramakrishnan's *Uniqueness for
  behavioural types* and *Linearity and uniqueness*), linked in
  those lectures.

## Sources

The bracketed `Handle` design, the sealed-module implementation,
the three-attack walkthrough, and the C comparison are original
to this course, assembling the locality, linearity, and
uniqueness material of CS6868 Parts 1 and 3 (the instructor's own
teaching material, freely reusable) into one API. The
`with_password` signature is quoted (abridged) from the `capsule`
library distributed with the OxCaml toolchain. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
