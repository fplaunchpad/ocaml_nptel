---
title: "Uniqueness: the only reference"
lecture_no: 2
week: 11
youtube_id: CxlMuGf3-Ac
duration_target_min: 18
concepts: [uniqueness, unique, aliased, manual resource management, use-after-free, double-free, in-place update, closure capture]
keywords: [OCaml, OxCaml, uniqueness, unique mode, aliased, free, Unique_ref, closure capture]
activity_question: "Against the [Unique_ref] signature, decide which of three clients fails to type-check (an underscored shadow drops the fresh handle), and predict what happens when a closure captures a unique reference and is called twice."
think_about_this: "Your reference is unique; you call `free` on it; the compiler is happy. Now you put a closure around the `free` call: `let f () = free r`. The closure has captured a unique reference. How many times is it safe to call `f`?"
reading:
  - title: "KC Sivaramakrishnan, Uniqueness for behavioural types (2025-05-29)"
    url: https://kcsrk.info/ocaml/modes/oxcaml/2025/05/29/uniqueness_and_behavioural_types/
  - title: "KC Sivaramakrishnan, Linearity and uniqueness (2025-06-04)"
    url: https://kcsrk.info/ocaml/modes/oxcaml/2025/06/04/linearity_and_uniqueness/
  - title: "Oxidizing OCaml: ownership (Jane Street blog)"
    url: https://blog.janestreet.com/oxidizing-ocaml-ownership/
---

# Uniqueness: the only reference


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Uniqueness: the only reference</h2>
<p class="title-slide-label">Module 11 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

In M10 we made the case that OCaml's garbage collector takes the
use-after-free problem off the table for *memory*. The argument
was straightforward: the collector frees a block only when no
live reference to it remains. A program that holds a reference
to a block is, by definition, *not* in the situation where the
collector would free it. So "use after free" for GC-managed memory
is impossible.

That argument is correct and useful, but its premise is narrow:
*GC-managed memory*. The world of manually managed resources is
wider. Some examples your OCaml programs encounter every day:

- A file descriptor obtained from `Unix.openfile`. The OS counts
  it. You must `Unix.close` it exactly once.
- A database connection from a connection pool. The pool counts
  it. You must return it exactly once.
- A buffer obtained from `Bigarray.Array1.create`. The kernel
  may have mapped it for DMA; closing twice corrupts the kernel's
  bookkeeping.
- A file allocated through C's `fopen` via the FFI. The C runtime
  counts it. You must `fclose` it exactly once.

For all of these, the garbage collector is not the manager. The
*you-and-your-types* combination is. And until OxCaml, the
"your-types" half of that combination was effectively absent: the
types could express that the value was a `Unix.file_descr`, but
not that it should be closed exactly once.

The traditional OCaml mitigation is an exception-safe wrapper
like the `fun_protect` cleanup combinator from the memory-safety
module: `fun_protect close (fun () -> ...)` closes on both exit
paths. This works for the
common case where the resource has a single owner. It does not
work when the resource is passed around the program, or stored in
a record, or captured in a closure: now the "exactly once close"
discipline becomes a property of the whole call graph, and there
is no language-level help to enforce it.

OxCaml's **uniqueness** axis is the type-level fix. Like locality,
it is a *mode*: it tracks not what a reference is but *how* it may
be used, here whether any other reference to it still exists. The
compiler proves, for designated references, that they are the
*only* reference to their target. That proof is the valuable
thing: an operation that would be unsafe in the presence of
aliasing becomes safe once the compiler has ruled the aliases out.
Freeing the target is the operation this lecture follows end to
end, and use-after-free and double-free are the bugs that fall to
it.

:::slide

## Where we are

- M10: GC eliminates use-after-free for **memory**.
- But "resource" is wider than "memory": file descriptors, DB
  connections, FFI-allocated buffers, mapped pages.
- The OCaml type system traditionally had nothing to say about
  these.
- This lecture: **uniqueness**.
  - the compiler proves a reference is the *only* one.
  - today's thread: `free` exactly once, checked at compile time.

:::

## The uniqueness axis, mechanically

OxCaml introduces an axis with two modes:

- **`aliased`** (the default): the value may have any number of
  other live references. Anything we do to it must respect that.
- **`unique`**: the value has no other live references. The
  compiler has *proven* this; we can do things that would be
  unsafe in the presence of aliasing.

The submoding is `unique ⊑ aliased`. A unique value can be used
anywhere an aliased value is expected, because "no aliases" is a
stronger guarantee than "may have aliases." The reverse coercion
is rejected: you cannot promote an `aliased` value to `unique`, no
matter what; the compiler has no evidence that other references do
not exist.

You write the mode after `@`, just like locality. A representative
signature, wrapped in a tiny module type so the toplevel can check
it directly:

```ocaml
module type Free_sig = sig
  type 'a t
  val free : 'a t @ unique -> unit
end
```

This signature says: `free` takes a `'a t` value at mode `unique`,
and returns `unit`. The reading is operational: hand `free` a
reference that is the only one to its target, and `free` will
deallocate the target. After the call, the reference is
*consumed*: the compiler bookkeeps that the caller's binding no
longer exists, and rejects any further use.

Uniqueness extends transitively. If a record is `unique`, the
parts you reach by `r.field` are also expected to be unique (with
one escape hatch we will see). This means uniqueness is *deep*:
you cannot hide an alias in a sub-component.

:::slide

## The uniqueness axis

| Mode | Meaning | Aliases? |
|---|---|---|
| **`aliased`** (default) | Other references may exist | Yes |
| **`unique`** | Compiler has proven no other references | No |

Submoding: `unique ⊑ aliased`. A unique reference can be passed
where aliased is expected. The reverse is rejected.

Uniqueness is *deep*: a unique record has unique parts (with one
escape hatch, `Modes.Aliased.t`).

:::

## What the proof licenses

Before the worked example, be clear about what "no other
references" actually buys. The proof licenses three privileges,
each unsafe under aliasing:

- **Free it.** If no other reference exists, deallocating the
  target cannot leave a dangling reference behind: there is
  nothing to dangle.
- **Move it.** Ownership can be handed to another part of the
  program outright. The receiver knows it now holds the only
  reference, with all the same privileges; no copy is needed.
- **Update it in place.** If nobody else can see the value,
  mutating it is unobservable from outside. A "functional" update
  (build a new record from an old one) can safely reuse the old
  memory instead of allocating; this is the optimisation
  direction the OxCaml designers are building on top of the same
  proof.

All three are one principle: aliasing is what makes these
operations dangerous, so a proof of no-aliasing makes them safe.
This lecture follows the first privilege, `free`, end to end; the
other two ride on exactly the same bookkeeping.

:::slide

## What "only reference" licenses

- **Free it**: no other reference exists, so none can dangle.
- **Move it**: hand over ownership outright, no copy.
- **Update it in place**: mutation nobody else can observe.
  - a functional update can reuse the old memory.
- One principle: aliasing is what made each unsafe.
- This lecture follows **`free`** end to end.

:::

## A safe memory-managed reference

The motivating example from the 2025-05-29 blog post is a
"manually managed" reference: a cell whose memory is *not* under
the GC's control, with explicit `alloc` and `free` operations. The
unsafe version of the interface looks innocent:

```ocaml
module type Unsafe_ref = sig
  type 'a t
  val alloc : 'a -> 'a t
  val free  : 'a t -> unit       (* nothing stops use-after-free *)
  val get   : 'a t -> 'a
  val set   : 'a t -> 'a -> unit
end
```

This is essentially the C-pointer API: explicit allocation,
explicit free. Nothing in the type stops you from calling `free`
twice, or calling `get` after `free`. The interface admits the
exact bugs M10 spent a lecture cataloguing.

Uniqueness lets us tighten the signatures:

```ocaml
module type Unique_ref = sig
  type 'a t
  val alloc : 'a -> 'a t @ unique
  val free  : 'a t @ unique -> unit
  val get   : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique
  val set   : 'a t @ unique -> 'a -> 'a t @ unique
end
```

Read each line carefully; it is the whole story.

- `alloc : 'a -> 'a t @ unique` mints a fresh reference and
  *guarantees* it is unique: no other references to it exist (it
  was just created).
- `free : 'a t @ unique -> unit` takes a unique reference and
  consumes it. After the call, the caller's binding cannot be
  used again.
- `get : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique` is
  the interesting one. To read the value, we *consume* the unique
  reference and hand the caller back two things: the contents
  wrapped in `Modes.Aliased.t` (so the reader can alias it freely),
  and a *fresh* unique reference to the same cell. The caller's
  original binding is gone; the new binding lives on. The
  `Modes.Aliased` wrap on the value is necessary because OxCaml's
  deep-uniqueness rule otherwise insists every component of a
  unique pair is itself unique, which would prevent the caller from
  copying the read-out value.
- `set : 'a t @ unique -> 'a -> 'a t @ unique` same shape: consume,
  install, return a fresh unique handle.

The pattern across all of these is: every operation takes the
unique reference, the original binding is consumed, and (except
for `free`) a fresh unique reference is returned to chain through.

The delivery vehicle should look familiar. This is the sealing
discipline from the modules material: an abstract `'a t` behind a
module type, the signature as the contract. The only new
ingredient is that the contract now carries modes as well as
types.

:::slide

## The `Unique_ref` signature

```ocaml
module type Unique_ref = sig
  type 'a t
  val alloc : 'a -> 'a t @ unique
  val free  : 'a t @ unique -> unit
  val get   : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique
  val set   : 'a t @ unique -> 'a -> 'a t @ unique
end
```

- Every operation consumes the unique reference.
- All but `free` return a fresh one: a **linear chain of
  ownership**.
- The familiar sealed-signature discipline.
  - the contract now carries modes as well as types.

:::

## The implementation, and what the compiler quietly checks

A perfectly innocent-looking implementation satisfies the
signature. The cell sits on the slide below so the deck carries
the whole story; the `open M` at its end brings `alloc`, `get`,
`set` and `free` into scope for the rest of the lecture.

:::slide

## The implementation

```ocaml
module M : Unique_ref = struct
  type 'a t = { mutable value : 'a }
  let alloc x = { value = x }
  let free _t = ()                       (* deallocation elided *)
  let get t =
    let a = Modes.Aliased.{ aliased = t.value } in
    a, t
  let set t x = t.value <- x; t
end

open M
```

- Compiler tracks each unique binding through assignments,
  matches, applications; rejects any aliasing of a unique value.
- Verifies the implementation matches the signature mode-by-mode.

:::

For a course of this size we are not chasing the actual `free`-the-
memory step; the OxCaml documentation has examples that wire into
real allocators. What matters for now is the *type discipline*: the
compiler verifies that the implementation respects uniqueness.

The `Modes.Aliased.{ aliased = t.value }` wrapper on the value
returned by `get` is the production-shaped escape hatch: it tells
the compiler "this field is aliased, even inside an otherwise
unique container." Without it the deep-uniqueness rule would
demand the value itself be unique, which is rarely what the caller
wants when reading.

A subtle test: change `set` to use `Fun.id` on the result. Same
behaviour, but `Fun.id` is a normal-mode function the compiler
cannot prove preserves uniqueness. Wrapping the variant in a
module ascription against the same signature makes the failure
concrete:

```ocaml skip
(* Press Run; the ascription fails because the rewritten set does
   not satisfy 'a t @ unique -> 'a -> 'a t @ unique. *)
module M_bad : Unique_ref = struct
  type 'a t = { mutable value : 'a }
  let alloc x = { value = x }
  let free _t = ()
  let get t =
    let a = Modes.Aliased.{ aliased = t.value } in
    a, t
  let set t x =
    t.value <- x;
    let t' = Fun.id t in    (* compiler cannot prove unique *)
    t'
end
```

The compiler rejects this with a message that the function does
not satisfy the signature: `'a t -> 'a -> 'a t` is not compatible
with `'a t @ unique -> 'a -> 'a t @ unique`. The lesson: the
compiler reads the implementation as carefully as it reads the
client.

## Correct usage: the ownership chain

A well-typed client looks like this:

```ocaml
let okay (r : int t @ unique) =
  let _v, r = get r in   (* old r consumed, new r bound *)
  let r = set r 20 in    (* old r consumed, new r bound *)
  free r                 (* old r consumed, nothing returned *)
```

Each line consumes the previous `r` and (except the last) binds a
fresh `r`. Pattern matching the pair from `get` is the standard
shadowing dance. By the end, `r` has been consumed by `free`; the
function has no live reference to the resource; no use-after-free
is possible because there is nothing left to use.

:::slide

## Correct usage shadows through

```ocaml
let okay (r : int t @ unique) =
  let _v, r = get r in
  let r = set r 20 in
  free r
```

Each operation:
- takes the current `r`,
- (except `free`) hands back a fresh one to shadow into the same name.

The shape is the *linear ownership chain*. After `free`, no `r`
exists.

:::

## Use-after-free: a compile error

Now the bad cases.

```ocaml skip
(* Press Run to see the use-after-free rejected at compile time. *)
let use_after_free (r : int t @ unique) =
  free r;
  get r
```

The compiler's response:

> Error: This value is used here, but it has already been used as
> unique:
> Line 3, characters 7-8.

Crisp. The first `free r` consumed the unique binding. By the time
we reach the second use (in `get r`), the original `r` is no
longer a live unique reference. The compiler refuses.

Double-free, the same way:

```ocaml skip
(* Press Run to see double-free rejected at compile time. *)
let double_free (r : int t @ unique) =
  free r;
  free r
```

> Error: This value is used here, but it has already been used as
> unique:
> Line 3, characters 7-8.

These errors are *static*. There is no runtime check, no flag, no
extra branch. The compiler's bookkeeping eliminated a whole class
of memory-safety bugs.

:::slide

## Use-after-free and double-free: type errors

```ocaml skip
let use_after_free (r : int t @ unique) =
  free r;
  get r           (* type error *)
```

```ocaml skip
let double_free (r : int t @ unique) =
  free r;
  free r          (* type error *)
```

Both rejected by the uniqueness bookkeeping, with the same shape
of error: "This value is used here, but it has already been used
as unique."

:::

## How the compiler tracks "already used"

A useful intuition. Each `unique` value has a single live
*owner* at any time. The owner is the binding that the compiler
believes has the unique reference. Operations like
`free`, `get`, `set` *transfer* ownership: they consume the input
owner and (in `get`'s and `set`'s case) introduce a new owner via
the returned value.

In the `okay` example, watch the ownership pass through:

```ocaml
let chain (r0 : int t @ unique) =
  let _v, r1 = get r0 in   (* ownership passed from r0 to r1 *)
  let r2 = set r1 20 in    (* passed from r1 to r2 *)
  free r2                  (* r2 consumed, no new owner *)
```

The shadowing names hide this, but the compiler is bookkeeping
exactly that chain. After the final `free`, there is no live
owner: the resource is gone, and any subsequent use of `r0`, `r1`,
or `r2` is a type error.

The same bookkeeping handles pattern destructuring, function calls
(which consume their unique arguments), record construction
(which consumes the fields), and so on. The 2025-05-29 blog post
has the full set of cases.

:::slide

## Ownership chains, conceptually

```ocaml
let chain (r0 : int t @ unique) =
  let _v, r1 = get r0 in  (* ownership: r0 -> r1, plus a value *)
  let r2 = set r1 20 in   (* r1 -> r2 *)
  free r2                 (* r2 consumed; no live owner *)
```

Each step *transfers* ownership of the unique handle. At the end
of `free`, no live handle exists.

:::

## The other side of the same coin: aliasing a unique reference

You can also see the asymmetry in the submoding rule. Take a
unique reference and pass it through a function that aliases it:

```ocaml
let dup r = (r, r)

let aliases () =
  let r = alloc 42 in
  dup r
```

The type of `aliases` is `unit -> int t * int t`. The two
components of the pair are at mode `aliased` (the default for the
pair type returned by `dup`). The compiler accepts the call to
`dup`, because `dup` requires its argument at mode `aliased`, and
the unique `r` can be coerced down (`unique ⊑ aliased`).

But now the two components are aliased. They can no longer be
passed to `free`, `get`, or `set`:

```ocaml skip
(* Press Run; once you alias a unique reference via `dup`, you
   cannot pass it to `free` any more. *)
let oops () =
  let r = alloc 42 in
  let a, _b = dup r in
  free a
```

Once you coerce a unique reference to aliased, you cannot get
uniqueness back. The library has lost the ability to safely free
the reference.

This is the *price* of allowing the submoding. Calling `dup` is
fine; you just lose the privileges of uniqueness afterwards. It is
on the programmer to keep the reference unique throughout its
useful life.

:::slide

## Aliasing destroys the uniqueness privilege

```ocaml skip
let dup r = (r, r)

let oops () =
  let r = alloc 42 in      (* r : int t @ unique *)
  let a, _b = dup r in     (* coerced to aliased *)
  free a                   (* error: aliased, expected unique *)
```

`unique ⊑ aliased` is a one-way street. You can lose uniqueness;
you cannot regain it.

:::

## A puzzle to end on: capturing a unique value in a closure

The machinery so far looks complete: unique references thread
through the program, every consuming operation is bookkept, and
both use-after-free and double-free die at compile time. To close
the lecture, here is a four-line program that puts a dent in that
completeness. The 2025-06-04 blog post opens with exactly this
scenario.

Suppose we have a unique reference and write a closure that frees
it:

```ocaml skip
(* Press Run and read the error message carefully. *)
let wat () =
  let t = alloc 42 in       (* t : int t @ unique *)
  let f () = free t in      (* closure captures t *)
  f ();                     (* OK: free t *)
  f ()                      (* uh oh: double-free? *)
```

Read it carefully. The closure `f` captures `t`. Calling `f` runs
`free t`. Calling `f` *twice* would run `free t` twice. That is a
double-free. The compiler must reject it.

But on what grounds? The unique value `t` is consumed *inside*
`f`'s body, not at the outer level. From the outer level's point
of view, `t` is referenced by `f`. The unique binding is
*captured*, not consumed. Nothing in this lecture's bookkeeping
covers that. And indeed the error the compiler produces is not a
uniqueness error at all:

> Error: This value is used here, but it is defined as once and
> has already been used:
> Line 5, characters 2-3.

"Defined as *once*." The error is not about `t`; it is about `f`,
and it names a mode this lecture has not introduced. The compiler
has quietly given the closure a mode on a *different axis*, one
that tracks how many times a value may be used in the future, and
rejected the second call on those grounds.

That axis is **linearity**, and it is the subject of the next
lecture. For now, take away the puzzle and its shape: uniqueness
alone is not enough; the moment a unique value hides inside a
closure, "no other references" stops being the property that
protects you, and "how many times can this be called" takes over.

:::slide

## A puzzle to end on

```ocaml skip
let wat () =
  let t = alloc 42 in
  let f () = free t in
  f ();
  f ()       (* rejected, but on what grounds? *)
```

- `f` captures the unique `t`.
- Capture *itself* does not consume `t`.
- Calling `f` twice would free `t` twice: must be rejected.
- The error: "defined as **once** and has already been used."
  - not a uniqueness error: a mode the next lecture explains.

:::

## Activity

:::quiz mcq id=M11-L02-q1
Given the `Unique_ref` signature from this lecture, which of these
clients fails to type-check? (Decide first; then press Run on each
cell to check.)

```ocaml
(* A *)
let a (r : int t @ unique) =
  let _v, r = get r in
  let _v, _r = get r in
  ()
```

```ocaml
(* B *)
let b (r : int t @ unique) =
  let r = set r 100 in
  free r
```

```ocaml skip
(* C *)
let c (r : int t @ unique) =
  let _v, _r = get r in
  free r
```

- [ ] Only A.
- [ ] Only B.
- [x] Only C.
- [ ] All three fail.

**Why:** A and B both follow the ownership chain: each operation
consumes the current `r` and binds a fresh one (or `free` consumes
without rebinding). C is the broken one. After
`let _v, _r = get r`, the *original* `r` has been consumed; the
new unique handle is `_r`, but the underscore tells the binding to
be discarded. The subsequent `free r` is the **original** `r`,
which has already been used as unique. The compiler rejects it.
:::

:::quiz mcq id=M11-L02-q2
Suppose we wrote a closure that *captures* (not consumes) a
unique reference:

```ocaml skip
let read_outside (r : int t @ unique) =
  let f () = get r in
  let _v, _r' = f () in
  let _v, _r' = f () in   (* called twice *)
  ()
```

What happens? (Press Run to check your prediction.)

- [x] The second call to `f` is rejected because `f` is implicitly
      `once`: it captured a unique value.
- [ ] Both calls succeed; the implementation is wrong.
- [ ] The compiler accepts both calls; `get` produces a fresh
      unique handle each time.
- [ ] The compiler accepts both calls; only `free` is restricted,
      not `get`.

**Why:** The capture of a unique value (`r`) into a closure
forces the closure's mode to `once`, exactly as in the `wat`
puzzle. The first call to `f` is fine; it consumes the captured
`r` and returns the fresh handle, which the caller's pattern then
discards. The second call is rejected because `f` is `once`,
regardless of what `f` does internally. Capture is not
consumption, but it is enough to downgrade the closure.
:::

:::solution

Q1: C is rejected. `a_ok` and `b_ok` thread the unique binding
correctly; `c_bad` calls `get r` (which consumes `r` and returns a
fresh handle), then underscores that fresh handle and calls `free r`
on the already-consumed original.

```ocaml
let a_ok (r : int t @ unique) =
  let _v, r = get r in let _v, _r = get r in ()
let b_ok (r : int t @ unique) =
  let r = set r 100 in free r
```

```ocaml skip
(* C: rejected. Run it. *)
let c_bad (r : int t @ unique) =
  let _v, _r = get r in free r
```

Q2: capturing (not consuming) a unique reference in a closure forces
the closure to `once`; capture alone downgrades it. That is the
bridge into the next lecture.

:::

## Common pitfalls

**Pitfall 1: "If I never alias a value, it must be unique."** No.
"Unique" is what the *compiler* has proven. If you write a
function whose signature does not say `@ unique`, the value will
not be unique inside the function, even if the caller's
implementation never aliases it. The signature is the contract.

**Pitfall 2: "Uniqueness handles all my closure problems."** No.
Closures over unique values become `once` automatically, but
*calling* the closure twice is the linearity rule, not the
uniqueness rule. Pay attention to the closure's *mode*, not just
its captured values.

**Pitfall 3: "`Modes.Aliased.t` defeats uniqueness."** Not really.
It is an escape hatch for *parts* of a unique value: the
container stays unique, but a designated field is allowed to be
aliased. This is the right tool for `get : 'a t @ unique -> 'a
Modes.Aliased.t * 'a t @ unique`, where the contents may need to
be shared with other code while the reference itself stays unique.

**Pitfall 4: "Uniqueness costs runtime."** It does not. The
checking is all at compile time. The compiled code is the same as
the unsafe version; the type checker has just proven it safe.

## What's next

The next lecture is **linearity**, the axis the `wat` error came
from. It gets treated on its own terms: a separate axis that
tracks *future* use rather than past aliasing, with its own modes
(`many` and `once`) and its own compile errors. It resolves the
closure puzzle properly, builds a file-handle API on the axis
that suits it, and takes up the question this lecture deferred:
when you design a resource API, which axis do you reach for?

After linearity, the module turns to the two concurrency axes,
contention and portability, and then the module closes with the
tutorial, where we design a resource-management API end to
end and walk through three attempts to misuse it. Each attempt
dies at compile time.

:::slide

## What's next

- Lecture 3: **linearity**. Future-use tracking, `once` and `many`.
  - resolves today's closure puzzle.
- Lecture 4: **contention**. Cross-domain access.
- Lecture 5: **portability**. Cross-domain crossing.
- Lecture 6: tutorial. A resource-management API combining the
  axes.

:::

## Reading

- **KC Sivaramakrishnan**, *Uniqueness for behavioural types*
  (2025-05-29):
  <https://kcsrk.info/ocaml/modes/oxcaml/2025/05/29/uniqueness_and_behavioural_types/>
- **KC Sivaramakrishnan**, *Linearity and uniqueness* (2025-06-04),
  the *Capturing unique values* section in particular:
  <https://kcsrk.info/ocaml/modes/oxcaml/2025/06/04/linearity_and_uniqueness/>
- **Jane Street blog**, *Oxidizing OCaml: ownership*:
  <https://blog.janestreet.com/oxidizing-ocaml-ownership/>
- **Marshall, Vollmer, Orchard**, *Linearity and Uniqueness: An
  Entente Cordiale* (ESOP 2022):
  <https://granule-project.github.io/papers/esop22-paper.pdf>

## Sources

The `Unique_ref` API, the worked client examples, and the
compiler-error blocks are adapted from the instructor's 2025-05-29
blog post and the CS6868 OxCaml handout (the instructor's own
teaching material, freely reusable). The closing closure-capture
puzzle draws on the 2025-06-04 post's *Capturing unique values*
section. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
