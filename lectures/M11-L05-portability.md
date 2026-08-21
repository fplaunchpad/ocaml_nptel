---
title: "Portability: data-race freedom across domains"
lecture_no: 5
week: 11
duration_target_min: 20
concepts: [portability, portable, nonportable, Domain.Safe.spawn, data race, capture, contended, Portable.Atomic, gensym]
keywords: [OCaml, OxCaml, portability, portable, nonportable, Domain, Atomic, data race, gensym]
activity_question: "A closure captures a [Buffer.t] and appends to it; why does annotating it [@ portable] get it rejected? And why does OxCaml ship [Portable.Atomic] when the standard library already has [Atomic]?"
think_about_this: "OCaml today lets you build a closure that captures a mutable [ref] and hand it to [Domain.spawn]. The compiler is happy; the race happens at runtime, on the bad input. What information would the compiler need to refuse that spawn?"
reading:
  - title: "OxCaml documentation, modes"
    url: https://oxcaml.org/documentation/modes/
  - title: "CS6868 OxCaml handout, Part 2 (KC Sivaramakrishnan)"
    url: https://github.com/kayceesrk/cs6868_s26
---

# Portability: data-race freedom across domains


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Portability: data-race freedom across domains</h2>
<p class="title-slide-label">Module 11 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous lecture met **contention**: once a value is shared
across domains, its mutable fields are off-limits (no writes, and
no reads either), unless the access goes through a synchronised
type like an atomic.

But contention alone does not finish the data-race story. It
governs how a *shared* value may be touched; it does not say
which values become shared in the first place. That is the other
half of a race, ingredient 2 from the previous lecture's
four-ingredient analysis: "a shared memory location."

The **portability** axis closes that half. It asks "can this
value safely cross a domain boundary?" If a closure would let two
domains race on captured mutable state, the answer is no, and the
type checker rejects any attempt to send it to another domain.
The race never reaches runtime, because the program never
compiles. By the end of this lecture the two axes click together
into a two-step argument that makes data-race freedom a
compile-time guarantee.

:::slide

## The other half: crossing the boundary

- Previous lecture's contention: how may a *shared* value be
  accessed?
- This lecture's portability: which values may become shared
  at all?
  - about (usually, function) values *crossing* domain
    boundaries.
- Contention attacked race ingredient 3.
  - portability attacks ingredient 2.
- Together: a two-step argument that rules races out at compile
  time.

:::

:::slide

## Where we are

- M10 defined the data race and left it a runtime hazard.
- M11-L01 to L03: the resource axes. Locality, uniqueness,
  linearity.
- M11-L04: **contention**. Cross-domain access.
- This lecture (M11-L05): **portability**. Cross-domain
  crossing.

:::

## The motivating example: a parallel gensym race

The cleanest motivation is a small systems chore: generating
unique symbols. A sequential `gensym` is a one-liner: hold a
counter in a `ref`, increment on every call, format the result.
You have built this closure before: it is
[the ticket dispenser](M07-L01-references.html) from the
imperative half of the course, with a prefix glued on.

```ocaml
let gensym =
  let count = ref 0 in
  fun prefix ->
    count := !count + 1;
    prefix ^ "_" ^ string_of_int !count

let _ = gensym "x" (* = "x_1" *)
let _ = gensym "y" (* = "y_2" *)
```

Sequential, this is fine. The counter is incremented on every
call; the calls cannot overlap; every result is unique.

Now move to two domains. Each domain calls `gensym` concurrently
in a hot loop. All four ingredients from the previous lecture's
recall are present:

1. two domains running in parallel,
2. a shared memory location: the `count` ref,
3. both domains write: each call does `count := !count + 1`,
4. nothing orders the accesses: no join, no lock, no atomic;
   `count` is a plain `ref`.

The runtime behaviour: lost updates, duplicate symbols, occasional
crashes if the runtime is unlucky. Standard OCaml will compile the
program and let you find out the hard way.

```ocaml
(* In OCaml 5 today, this compiles, and on a multicore machine it
   races at runtime. (This browser toplevel is single-domain, so
   the interleaving cannot manifest here; the point is that the
   vanilla API accepts the program.) *)
[@@@alert "-do_not_spawn_domains"]
[@@@alert "-unsafe_multidomain"]
let d1 = Domain.spawn (fun () -> for _ = 1 to 1_000 do ignore (gensym "x") done)
let d2 = Domain.spawn (fun () -> for _ = 1 to 1_000 do ignore (gensym "y") done)
let () = Domain.join d1; Domain.join d2
```

:::slide

## The gensym race

```ocaml
let gensym =
  let count = ref 0 in
  fun prefix ->
    count := !count + 1;
    prefix ^ "_" ^ string_of_int !count
```

- The ticket-dispenser closure from the imperative half, plus a
  prefix.
- Sequential: fine.
- Two domains calling `gensym` in parallel: classic data race
  on `count`.
- All four ingredients present: two domains, shared `ref`, two
  writers, nothing ordering the accesses.
- Vanilla OCaml compiles it. The race fires at runtime.

:::

## The portability axis

OxCaml's **portability** axis was named in the previous lecture;
now it gets developed. Two modes:

- **`nonportable`** (the default): the value is not safe to send
  to another domain.
- **`portable`**: the value is safe to send to another domain. A
  `portable` function is one that can be safely called from any
  domain.

The submoding is `portable ⊑ nonportable`. A `portable` value can
be used anywhere a `nonportable` value is expected ("safe to ship"
is a stronger promise than "not safe to ship"). The reverse is
rejected.

The critical constraint, and the bridge to the previous lecture:
**inside a `portable` function, all captured values from the
outer scope are treated as `contended`.** If the function runs on
another domain, the original domain might be touching the
captured values at the same moment; treating the captures as
contended is exactly the right level of paranoia. Capturing is
fine; what the contention rules then forbid is touching the
captures' mutable parts.

:::slide

## The portability axis

| Mode | Meaning |
|---|---|
| **`nonportable`** (default) | Not safe to send to another domain |
| **`portable`** | Safe to call from any domain |

Submoding: `portable ⊑ nonportable`.

- **The capture rule**: inside a `portable` function, all
  captured values are treated as **`contended`**.
  - the original domain might be touching them right now.
  - the contention rules then police the captures.

:::

## A pure closure is portable

A pure function captures nothing the rules can object to. Press
Run:

```ocaml
let test_portable () =
  let (f @ portable) = fun x y -> x + y in
  f 1 2

let () = Printf.printf "test_portable () = %d\n" (test_portable ())
```

Capturing a `ref` and *mutating* it is what falls afoul. Press
Run and read the error carefully; it points at the captured `r`
inside the portable closure:

```ocaml skip
(* Press Run; the mutation of the captured ref is rejected. *)
let test_nonportable () =
  let r = ref 0 in
  let (counter @ portable) () = incr r; !r in
  counter ()
```

The error says the captured `r` is `contended` (the capture rule
at work), but `incr` needs it `uncontended`. The two requirements
collide, so the closure cannot be portable. This is the previous
lecture's Rule 1, recruited to police closures.

And the racy `gensym` is exactly this shape: its closure captures
`count : int ref` and mutates it on every call. If the closure
ran on another domain, the original domain might still call
`gensym` directly. Both domains would write to `count`. So
`gensym` is `nonportable`.

:::slide

## A pure closure is portable

```ocaml
let test_portable () =
  let (f @ portable) = fun x y -> x + y in
  f 1 2

let () = Printf.printf "test_portable () = %d\n" (test_portable ())
```

- Captures nothing mutable: nothing the contention rules can
  object to.
- The `@ portable` annotation is checked, and passes.

:::

:::slide

## Capturing a mutable `ref`: rejected

```ocaml skip
(* Press Run; the mutation of the captured ref is rejected. *)
let test_nonportable () =
  let r = ref 0 in
  let (counter @ portable) () = incr r; !r in
  counter ()
```

- Captured `r` is treated as **`contended`** (the capture rule).
  - `incr` needs it `uncontended`.
  - the two requirements collide.

`gensym` is the same shape: it captures and mutates `count`.
Therefore nonportable.

:::

## `Domain.Safe.spawn` requires `portable`

OxCaml's parallel primitives bake the portability discipline into
their signatures. The relevant entry point is `Domain.Safe.spawn`.
Rather than quoting the documentation, ask the toplevel itself;
press Run:

```ocaml
let spawn = Domain.Safe.spawn
(* val spawn : (unit -> 'a) @ once portable -> 'a Domain.t *)
```

Read the reported signature carefully. The argument is a thunk
`unit -> 'a`, with *two* mode annotations. `portable` is this
lecture's subject: the thunk must be safe to hand to another
domain. And `once` is an old friend from the linearity lecture:
the spawned thunk will be run at most one time, so the API
demands no more than that. Two axes, one signature, each doing
its own job.

Vanilla OCaml has `Domain.spawn` without this annotation, which is
why the gensym race can compile today. OxCaml's `Domain.Safe.spawn`
adds the portability constraint, and the type checker enforces it.

Try to spawn the racy gensym, and the compiler stops you:

```ocaml skip
(* OxCaml refuses this at compile time; press Run. *)
let _ = Domain.Safe.spawn (fun () -> gensym "x")
(* Error: The value "gensym" is "nonportable" but is expected to
   be "portable" because it is used inside the function ... which
   is expected to be "portable". *)
```

The error is precise: `gensym` is nonportable, because it captures
a `ref` it mutates; the closure handed to `Domain.Safe.spawn` is
expected to be portable; the constraint cannot be satisfied. No
race fires because the program does not compile.

:::slide

## `Domain.Safe.spawn`'s signature

```ocaml
let spawn = Domain.Safe.spawn
(* val spawn : (unit -> 'a) @ once portable -> 'a Domain.t *)
```

```ocaml skip
(* Press Run; OxCaml refuses the racy spawn. *)
let _ = Domain.Safe.spawn (fun () -> gensym "x")
(* Error: The value "gensym" is "nonportable" but is
   expected to be "portable" ... *)
```

- The thunk must be `portable` (and `once`: run at most one time).
- The vanilla `Domain.spawn` lacks the annotations.
  - that is why the race compiles today.

:::

## Ruling out data races: the two-step argument

The two axes now click together. Consider the scenario the
previous lecture warned about:

```text
Domain 1                    Domain 2
--------                    --------
t.mood <- Happy             t.mood <- Sad      <- DATA RACE
```

The mode system prevents this with a two-step argument:

1. **Portability** ensures that any closure crossing a domain
   boundary is `portable`, which means it treats its captured
   values as `contended`.
2. **Contention** ensures that `contended` values cannot have
   their mutable fields read or written.

Step 1 guards the only door a value has into another domain; step
2 disarms whatever walks through it. Together, the two rules make
data-race freedom a compile-time guarantee: there is no way to
assemble the racy picture above out of typechecked parts.

:::slide

## Ruling out data races: the two-step argument

```text
Domain 1                    Domain 2
--------                    --------
t.mood <- Happy             t.mood <- Sad      <- DATA RACE
```

1. **Portability**: closures crossing a domain boundary are
   `portable`.
   - so they treat captured values as `contended`.
2. **Contention**: `contended` values cannot have mutable fields
   read or written.

Two rules, one guarantee: the racy picture cannot be assembled
from typechecked parts.

:::

## Captures vs parameters

A subtle but important point. Portability constrains *what a
closure captures from its enclosing scope*. It does **not** force
*parameters* into any particular mode.

A `portable` function can still take a parameter at
`@ uncontended` and mutate it inside the body, because parameters
are supplied fresh at each call. The function itself does not
capture them; the caller hands them in. This split matters
because parallel APIs hand callbacks an explicit token (a
scheduler handle, a slice, a parallel-context tag), and that
token can carry whatever mode the API specifies even though the
callback is portable.

A small example, with the loop split out of the enclosing scope:

```ocaml
let factorial_portable n =
  let a = ref 1 in
  let rec (loop @ portable) (a @ uncontended) i =
    if i > 0 then begin
      a := !a * i;
      loop a (i - 1)
    end
  in
  loop a n;
  !a
```

Here `loop` is portable: it captures nothing from outside. It
accepts `a` as a parameter at mode `@ uncontended` and mutates it
freely; the caller (the outer function) holds `a` with full
rights and passes it in. This split is the way to write portable
callbacks that still need to read or write to a mutable
accumulator.

:::slide

## Captures vs parameters

```ocaml
let factorial_portable n =
  let a = ref 1 in
  let rec (loop @ portable) (a @ uncontended) i =
    if i > 0 then begin
      a := !a * i;
      loop a (i - 1)
    end
  in
  loop a n;
  !a
```

- Portability constrains **captures**, not **parameters**.
  - `loop` captures nothing.
  - `a` arrives fresh at each call, at its declared mode.
- This is how parallel APIs hand tokens into a portable callback.

:::

## The first working program: `Portable.Atomic`

Now the payoff: a gensym that two domains can share, with the
compiler's blessing. OxCaml ships `Portable.Atomic` (from the
`portable` library), an atomic that **crosses both the contention
and portability axes**: since its operations synchronise, it can
be used freely where either mode is expected. The stdlib `Atomic`
from the previous lecture predates the mode system, and its
signatures carry none of these annotations; in OxCaml code, reach
for `Portable.Atomic`.

One packaging detail before the cell. We wrap the counter and
`gensym` in a small module:

```ocaml skip
[@@@alert "-do_not_spawn_domains"]

module Gen = struct
  open Portable
  let count = Atomic.make 0
  let gensym prefix =
    Atomic.incr count;
    prefix ^ "_" ^ string_of_int (Atomic.get count)
end

let d  = Domain.Safe.spawn (fun () -> Gen.gensym "y")
let s1 = Gen.gensym "x"
let s2 = Domain.join d
let () = Printf.printf "%s %s\n" s1 s2
(* x_2 y_1 here: the spawned thunk ran first and drew 1.
   The x/y split varies with timing. *)
```

Two domains, a shared atomic counter, no race; the compiler
verified all of that before anything ran. The toplevel reports
`module Gen : sig ... end @@ portable`: mode inference noticed
that every value inside is portable and marked the whole module
portable, so `Gen.gensym` can be read out of it at portable mode
by the spawned closure.

Why the module wrap, instead of `let (gensym @ portable) = ...`
at the top level? A quirk of the toplevel: a bare `let` lands in
the implicit toplevel module, which itself sits at the default
`nonportable` mode. When `Domain.Safe.spawn` later reads `gensym`
back out of that module, it sees a nonportable binding and
refuses, even though the closure was verified portable at its
binding site. Wrapping in `module Gen` gives the closure a
portable home. In a real `.ml` file the whole compilation unit is
a module that mode inference can mark portable wholesale, so this
dance is not necessary.

:::slide

## The first working program: `Portable.Atomic`

```ocaml skip
module Gen = struct
  open Portable
  let count = Atomic.make 0
  let gensym prefix =
    Atomic.incr count;
    prefix ^ "_" ^ string_of_int (Atomic.get count)
end
```

- Crosses both contention **and** portability.
  - its operations synchronise, so either mode's demands are met.
- The stdlib `Atomic` predates modes: no annotations.
- Wrap in a module: inference marks it `@@ portable`.

:::

## Activity

:::quiz mcq id=M11-L05-q1
We try to annotate a logging function as portable. (Predict the
verdict, then press Run.)

```ocaml skip
let (f @ portable) =
  let log = Buffer.create 16 in
  fun x ->
    Buffer.add_string log (string_of_int x ^ "; ");
    x + 1
```

Why does the compiler refuse?

- [ ] It returns an `int`, which is not a portable type.
- [x] It mutates a captured, therefore contended, `Buffer.t`.
- [ ] It uses `string_of_int`, which is not a portable function.
- [ ] Functions defined at the top level are always nonportable.

**Why:** Portability is determined by what a closure *captures*
from its enclosing scope. `f` captures `log`, a mutable buffer,
and `Buffer.add_string` writes through it. Inside a portable
closure the captured `log` is treated as `contended` (the capture
rule), and the contention rules forbid touching a contended
value's mutable parts. The return type, the helper calls, and
the top-level position are not the issue. The compiler points at
`log` in its diagnostic.
:::

:::quiz mcq id=M11-L05-q2
A team replaces a `ref` counter with a stdlib `Atomic.t`, and the
runtime race is gone. Porting the code to OxCaml, they
swap it again, for `Portable.Atomic`. What does the second swap
buy?

- [ ] A faster compare-and-swap instruction.
- [x] Its signatures carry the required mode annotations.
- [ ] Nothing; the two modules are aliases.
- [ ] Protection against integer overflow of the counter.

**Why:** Both atomics synchronise at runtime; the runtime
behaviour is the same. The difference is what the *type checker*
can see. `Portable.Atomic` is the modes-aware atomic: its
signatures carry the annotations that let it cross the contention
and portability axes, so portable closures can capture it and
`Domain.Safe.spawn` accepts the result. The stdlib `Atomic`
predates the mode system; nothing in its signatures tells the
checker its operations synchronise.
:::

:::solution

Q1 is rejected: the closure captures a mutable `Buffer.t` and writes
to it inside the body. A portable closure's captures are treated as
`contended`, and a contended value's mutable parts cannot be touched.

```ocaml skip
(* Q1: rejected. Run it. *)
let (f @ portable) =
  let log = Buffer.create 16 in
  fun x ->
    Buffer.add_string log (string_of_int x ^ "; ");
    x + 1
```

Q2: the runtime behaviour of the two atomics is the same; the swap
buys the *annotations*. `Portable.Atomic`'s signatures tell the
checker its operations synchronise, so it crosses both the
contention and portability axes; the stdlib `Atomic` predates modes
and tells the checker nothing.

:::

## Common pitfalls

**Pitfall 1: "Atomics make my closure portable."** The runtime
race is fixed by any atomic. What the checker accepts depends on
the annotations it can see: the stdlib `Atomic` predates modes
and carries none, while `Portable.Atomic` declares that its
operations synchronise. In OxCaml code, use `Portable.Atomic`.

**Pitfall 2: "Portability bans captures."** It does not ban
them; it disciplines them. A portable closure's captures are
treated as `contended`, so any use that needs more (a write, a
read of a mutable field, a call that demands an uncontended
argument) is rejected. Immutable captures sail through, because
there is nothing mutable to race on.

**Pitfall 3: "Portability and contention are the same axis."**
They are not. Contention (the previous lecture) tracks how a
value may be accessed once shared; portability tracks whether a
value may cross a domain boundary at all. The two-step argument
needs both: portability guards the door, contention disarms what
walks through it.

**Pitfall 4: "I can mutate a parameter inside a portable
closure."** Yes; portability constrains captures, not parameters.
A `@ portable` function can take an `@ uncontended` parameter
and mutate it freely: parameters are supplied fresh at each call.

:::slide

## What portability buys you

- Race ingredient 2 (shared mutable location) becomes a
  compile-time check.
- `Domain.Safe.spawn` refuses closures that capture
  thread-local mutable state.
- With the previous lecture's contention axis, all four race
  ingredients are covered: data-race freedom at compile time.
- No race detector, no test sweep, no production firefight.
  - cost: zero. The runtime is exactly what you would write by
    hand.

:::

## What's next

The module closes with the tutorial: a bracketed
resource-management API built from the resource axes, attacked
three ways, and compared against a production OxCaml signature
that uses every axis the module taught.

:::slide

## What's next

- Lecture 6: tutorial. A bracketed resource-management API,
  designed, implemented, and attacked.

:::

## Reading

- **OxCaml documentation**, the modes overview:
  <https://oxcaml.org/documentation/modes/>
- **CS6868 OxCaml handout** (KC Sivaramakrishnan), Part 2
  (Modes and Data-Race Freedom):
  <https://github.com/kayceesrk/cs6868_s26>
- **OxCaml ICFP 2025 tutorial**, the hands-on activities
  (act01..act03 trace the gensym race exactly):
  <https://github.com/oxcaml/tutorial-icfp25>

## Sources

The gensym example, the portability capture rule and its
`test_portable` / `test_nonportable` demos, the two-step
data-race argument, the captures-versus-parameters example, and
the `Portable.Atomic` "first working program" are adapted from
the CS6868 OxCaml handout and slides, Part 2 (the instructor's
own teaching material, freely reusable). The framing as a sequel
to the contention lecture is original to this course. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
