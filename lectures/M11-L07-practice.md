---
title: "Practice: programming with modes"
lecture_no: 7
week: 11
duration_target_min: 0
concepts: [practice problems, OxCaml, modes, locality, uniqueness, linearity, contention, portability]
keywords: [OCaml, OxCaml, practice, modes, local, exclave, unique, once, contended, portable, stack allocation]
think_about_this: "On every other worksheet a wrong answer is a failed test. Here a wrong answer is often a *type error*: the compiler is the grader. For each problem ask not just 'does it run?' but 'will the compiler accept it, and if not, exactly which mode rule did I break?'"
reading:
  - title: "OxCaml documentation"
    url: https://oxcaml.org/documentation/
  - title: "Oxidizing OCaml: locality (Jane Street blog)"
    url: https://blog.janestreet.com/oxidizing-ocaml-locality/
---

# Practice: programming with modes

This is a *Practice* chapter, not a Tutorial. There are no slides
and there is no video; it is a worksheet. The
[tutorial](M11-L06-tutorial.html) walked through a worked example on
screen. Here you work the problems yourself, directly in the
browser, on the OxCaml toolchain.

Modes make this worksheet a little different. There are two kinds of
problem:

- **Complete the code.** A function is given with mode annotations
  already in its signature; you fill in a body that the compiler
  accepts and that passes the test cell (which prints `all tests
  passed`). Getting the modes wrong here shows up as a *type error*,
  not a failed assertion.
- **Predict the compiler.** A short snippet is given; you decide
  whether it type-checks and, just as important, *why*. Run the cell
  to confirm your reading. These are multiple-choice; the reasoning
  is in the answer.

The worksheet covers all five axes from the module: locality,
uniqueness, linearity, contention, and portability.

## Part 1: locality (complete the code)

Throughout Part 1 we use a small colour record. Run this cell first.

```ocaml
type rgb = { r : float; g : float; b : float }
```

## Problem 1: `brightness`

A `@ local` value cannot escape its region, but a plain `int`
computed from one can: `int` *mode-crosses* locality. Complete

```text
brightness : rgb @ local -> int
```

so that it returns how many of the three channels exceed `0.5` (a
number from `0` to `3`). The colour comes in `@ local`; the `int`
you return is global, and `c` itself never leaves the function.

:::quiz code id=M11-L07-q1
Implement `brightness`.

```ocaml
let brightness (c @ local) : int =
  failwith "not implemented"
```

```ocaml skip
let test () =
  let c = stack_ { r = 0.9; g = 0.1; b = 0.8 } in
  let n = brightness c in
  n
let () = assert (test () = 2); print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let brightness (c @ local) : int =
  (if c.r > 0.5 then 1 else 0)
  + (if c.g > 0.5 then 1 else 0)
  + (if c.b > 0.5 then 1 else 0)
```

We read the fields of the local `c` freely; reading does not let `c`
escape. The result is an `int`, which mode-crosses locality, so it
returns to the caller as an ordinary global value. The test allocates
its colour with `stack_` inside a function (a `stack_` value needs a
region, which a function body provides), then calls `brightness`.

:::

## Problem 2: `total`

Whole data structures can be local too. Complete

```text
total : int list @ local -> int
```

which sums a local list of integers. The list (its cons cells and
all) is local, but the `int` sum mode-crosses out.

:::quiz code id=M11-L07-q2
Implement `total` by recursion on the local list.

```ocaml
let rec total (xs : int list @ local) : int =
  failwith "not implemented"
```

```ocaml skip
let test () =
  let xs = stack_ [ 10; 20; 30 ] in
  let s = total xs in
  s
let () = assert (test () = 60); print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec total (xs : int list @ local) : int =
  match xs with
  | [] -> 0
  | x :: rest -> x + total rest
```

The recursion is the ordinary list sum; the only new thing is the
`@ local` on the parameter. Pattern-matching a local list yields
local pieces, but each element is an `int`, and the running sum is an
`int`, so nothing local ever needs to escape. The whole list can live
on the stack (`stack_ [ ... ]` in the test) with no heap traffic.

:::

## Problem 3: `channel_range`

To *return* something built locally, you allocate it in the caller's
region with `exclave_`. Complete

```text
channel_range : rgb @ local -> (float * float) @ local
```

which returns the pair `(smallest channel, largest channel)` of the
colour, allocated `@ local` so it lives in the caller's region. Use
`exclave_` on the tuple. The helpers `min3` and `max3` are provided.

:::quiz code id=M11-L07-q3
Implement `channel_range`. Build the result tuple with `exclave_`.

```ocaml
let min3 a b c = if a < b then (if a < c then a else c) else (if b < c then b else c)
let max3 a b c = if a > b then (if a > c then a else c) else (if b > c then b else c)

let channel_range (c @ local) : (float * float) @ local =
  failwith "not implemented"
```

```ocaml skip
let test () =
  let c = stack_ { r = 0.25; g = 0.75; b = 0.5 } in
  let lo, hi = channel_range c in
  lo = 0.25 && hi = 0.75
let () = assert (test ()); print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let channel_range (c @ local) : (float * float) @ local =
  exclave_ (min3 c.r c.g c.b, max3 c.r c.g c.b)
```

The tuple `(lo, hi)` is a fresh allocation. Without `exclave_` it
would be local to *this* function's region and could not be returned;
`exclave_` allocates it in the caller's region instead, so it is still
local (never a heap value) but outlives this call. The return type
`(float * float) @ local` is exactly what the caller receives. (Note
the result has to stay `@ local`: a tuple, unlike an `int`, does not
mode-cross locality.)

:::

## Part 2: locality (predict the compiler)

## Problem 4: a `stack_` value that tries to escape

:::quiz mcq id=M11-L07-q4
Will this definition compile?

```ocaml skip
type rgb = { r : float; g : float; b : float }
let make_red () : rgb = stack_ { r = 1.0; g = 0.0; b = 0.0 }
```

- [ ] Yes: `stack_` records can be returned like any other value.
- [x] No: the local record would escape through a global return.
- [ ] No: `stack_` may only be used on tuples, never on records.
- [ ] Yes, but only because `rgb` contains floats.

**Why:** `stack_` allocates in the *current* function's region, which
is torn down when the function returns. The return type `rgb` carries
no `@ local`, so the caller expects a global value, and the compiler
rejects the attempt to let a region-local value escape. Contrast
Problem 3: `channel_range` returns its fresh tuple with `exclave_`,
which allocates in the *caller's* region and is typed `@ local`, so
it is allowed to outlive the call. To return a heap value here
instead, just drop the `stack_`: a plain record literal allocates on
the heap at mode global.
:::

## Problem 5: why `brightness` is allowed

:::quiz mcq id=M11-L07-q5
`brightness` from Problem 1 takes a `@ local` colour and returns a
plain `int` to a caller that may keep it forever. Why is that not an
escape?

- [ ] Because reading a field secretly copies the whole record to the
      heap.
- [ ] Because the return type should really be `int @ local`, and the
      compiler is being lenient.
- [x] Because `int` mode-crosses locality: the returned `int` is a
      global value, and the local `c` itself never leaves the
      function.
- [ ] Because `@ local` only restricts writes, not reads or returns.

**Why:** locality is about whether a *value* can outlive its region.
An `int` is a self-contained, register-sized value that carries no
reference into the region, so it mode-crosses: a `local` and a
`global` `int` are interchangeable. `brightness` reads `c`'s fields
(allowed) and computes a fresh `int` (global); `c` is never returned
or stored, so nothing escapes. Records and lists do *not* mode-cross,
which is why Problems 3 and 4 had to think about regions but this one
did not.
:::

## Part 3: uniqueness and linearity

## Problem 6: aliasing a `unique` reference

Here is the signature of a uniqueness-tracked reference, like the one
from the [uniqueness lecture](M11-L02-uniqueness.html):

```ocaml
module type Unique_ref = sig
  type 'a t
  val alloc : 'a -> 'a t @ unique
  val get   : 'a t @ unique -> 'a Modes.Aliased.t * 'a t @ unique
  val set   : 'a t @ unique -> 'a -> 'a t @ unique
  val free  : 'a t @ unique -> unit
end
```

:::quiz mcq id=M11-L07-q6
Suppose `alloc`, `free`, etc. have the types above. Does this client
type-check?

```text
let r  = alloc 1 in
let r2 = r in          (* give the same reference a second name *)
free r;
free r2
```

- [ ] Yes: `r` and `r2` are two independent references.
- [x] No: aliasing `r` makes it no longer unique.
- [ ] No: `free` may only be called inside the module that defines
      `t`.
- [ ] Yes: `free` simply runs twice with no complaint.

**Why:** `alloc` hands back a value at mode `unique`, meaning the
compiler has proved there is exactly one reference to it. The moment
you write `let r2 = r`, there are two names for the same value, so it
is no longer unique; `free`, which demands `@ unique`, can accept at
most one of them. (Even without the alias, calling `free` twice on the
*same* name fails, because `free` consumes its argument.) Uniqueness
is the guarantee that lets `free` know it is releasing something no
one else still holds.
:::

## Problem 7: a linear file handle (complete the code)

This `Handle` enforces a *linear* protocol with the `@ once` mode:
each operation consumes the handle and hands back a fresh one, and
`close` consumes it for good. Run this cell first.

```ocaml
module Handle : sig
  type t
  val open_ : string -> t @ once
  val write : t @ once -> string -> t @ once
  val read  : t @ once -> string * t @ once
  val close : t @ once -> unit
end = struct
  type t = { mutable buf : string }
  let open_ _ = { buf = "" }
  let write t s = t.buf <- s; t
  let read t = (t.buf, t)
  let close _ = ()
end
```

Complete `echo` so that it opens a handle, writes `"hello"`, reads it
back, closes the handle, and returns what it read. You must thread the
fresh handle returned by each step into the next.

:::quiz code id=M11-L07-q7
Implement `echo : unit -> string`.

```ocaml
let echo () : string =
  failwith "not implemented"
```

```ocaml skip
let () = assert (echo () = "hello"); print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let echo () : string =
  let t = Handle.open_ "scratch" in
  let t = Handle.write t "hello" in
  let s, t = Handle.read t in
  Handle.close t;
  s
```

Each step rebinds `t` to the handle the previous step returned;
because `t` is `@ once`, you cannot reuse an earlier `t` once it has
been consumed. Shadowing the name `t` at each line is the idiomatic
way to thread a linear value: the old binding is gone, and only the
freshest handle is in scope. If you tried to call `Handle.read t`
again after `Handle.close t`, the compiler would reject it.

:::

## Problem 8: using a handle after it is consumed

:::quiz mcq id=M11-L07-q8
Using the `Handle` from Problem 7, does this compile?

```ocaml skip
let oops () =
  let t = Handle.open_ "f" in
  let s, _ = Handle.read t in   (* the fresh handle is thrown away *)
  Handle.close t;               (* ...then we reuse the old t *)
  s
```

- [ ] Yes: `read` does not really consume `t`.
- [ ] Yes: `close` works on any handle, used or not.
- [x] No: `read t` consumed `t`; its replacement was discarded.
- [ ] No: tuple destructuring may not discard a linear component with `_`.

**Why:** `read : t @ once -> string * t @ once` consumes its argument
and returns a *new* handle as the second component. Binding that
second component to `_` throws the only live handle away. The
subsequent `Handle.close t` reaches back to the original `t`, which
has already been used once, and `@ once` forbids a second use. The fix
is to keep the returned handle (`let s, t = Handle.read t in`) and
close *that*, exactly as in Problem 7.
:::

## Part 4: contention and portability

## Problem 9: writing through a `@ contended` value

:::quiz mcq id=M11-L07-q9
A value shared with another domain arrives `@ contended`. Does this
compile?

```ocaml skip
type account = { id : int; mutable balance : int }
let deposit (a @ contended) n = a.balance <- a.balance + n
```

- [ ] Yes: writing a `mutable` field is always allowed.
- [x] No: contended mutable fields cannot be accessed.
- [ ] No: `account` must be declared `mutable` as a whole.
- [ ] Yes, as long as `n` is positive.

**Why:** the `contended` mode marks a value that another domain may be
touching concurrently. Reading or writing a `mutable` field could then
race, so the compiler forbids both on a `@ contended` value: `a.balance
<- ...` is rejected. (Reading the *immutable* `id` field would be fine,
since immutable data cannot race.) To mutate shared state safely you
reach for an `Atomic.t`, whose operations are synchronised and so are
allowed even on a contended value.
:::

## Problem 10: a `portable` closure that captures a `ref`

:::quiz mcq id=M11-L07-q10
A `@ portable` function is one safe to send to another domain. Does
this compile?

```ocaml skip
let make_counter () =
  let r = ref 0 in
  let (next @ portable) () = incr r; !r in
  next
```

- [ ] Yes: the closure is small and obviously thread-safe.
- [ ] No: `ref` is not allowed inside any function.
- [x] No: captured refs are contended in portable closures.
- [ ] Yes: `incr` is atomic, so capturing `r` is fine.

**Why:** portability is what makes data-race freedom compositional. A
`portable` closure may run on another domain, so anything it *captures*
from the enclosing scope is seen as `@ contended` (Problem 9): mutating
the captured `r` with `incr` is therefore rejected. A pure closure such
as `fun x y -> x + y`, which captures nothing mutable, is portable
without complaint. This is why `Domain.Safe.spawn` demands a thunk that
is both `@ once` (linearity: run at most once) and `@ portable`
(no racy captures): the two modes together rule out building a data
race from type-checked parts. The race-free way to share a mutable
counter across domains is an atomic counter, not a captured `ref`.
:::
