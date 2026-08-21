---
title: "Memory safety by construction"
lecture_no: 2
week: 10
duration_target_min: 27
concepts: [garbage collection, bounds checking, initialisation, tagged pointers, block headers, runtime representation]
keywords: [OCaml, GC, garbage collection, bounds checking, Invalid_argument, tagged pointers, block header, runtime, memory safety]
activity_question: "Write safe_nth; predict the OCaml analogue of a C use-after-free; and explain why the runtime uses the low bit of every value as a tag."
think_about_this: "Bounds checks on every array access are not free. They cost a comparison and a branch on every read. Yet OCaml programs are routinely within a small constant factor of C. Why does the cost not dominate, and where do compilers reclaim it?"
reading:
  - title: "Cornell CS3110, References and memory locations"
    url: https://cs3110.github.io/textbook/chapters/mut/refs.html
  - title: "Real World OCaml, Memory representation of values"
    url: https://dev.realworldocaml.org/runtime-memory-layout.html
  - title: "Leaking Space (Neil Mitchell, ACM Queue)"
    url: https://queue.acm.org/detail.cfm?id=2538488
---

# Memory safety by construction


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Memory safety by construction</h2>
<p class="title-slide-label">Module 10 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The previous lecture catalogued the four canonical memory-safety
bugs in C (use-after-free, buffer overflow, uninitialised read,
double-free) and why they dominate real-world CVEs. This lecture
makes the OCaml side precise. For each of the four bugs, we
identify *which* language feature rules it out, *where* in the
runtime the rule is enforced, and *what* the cost is. Then we
sketch the runtime infrastructure that makes these rules
implementable: tagged pointers, block headers, and what the garbage
collector actually does.

The point of this lecture is not "OCaml is safe, trust us." The
point is "OCaml is safe, here is the mechanism, the mechanism is
small enough to fit in one lecture, and you can run it in your
browser."

We close with the *honest boundary*: this story holds for the safe
fragment. Outside it (`Obj.magic`, FFI, `Marshal` with the wrong
type, races across domains) the guarantees weaken, which a later
lecture in this module walks in detail.

:::slide

## Framing

- Not "trust us, it is safe": here is the *mechanism*.
- One section per bug: which feature closes it, and how.
- Then the runtime sketch: tagged pointers, block headers, the GC.
- Small enough for one lecture, and runnable in your browser.

:::

## Use-after-free: ruled out by the GC

The C use-after-free pattern was: a program calls `free` on a
block, then later reads or writes through a pointer that still holds
the address of that block. The bug is *temporal*: the address is
"valid" in the sense that it is a real address; it just no longer
belongs to the program.

In OCaml the bug class is impossible because the bug *cannot be
written down*. Two things rule it out, working together.

**No `free` primitive.** OCaml's surface language has no `free`, no
`delete`, no `dispose`. The programmer never tells the runtime "this
block is now garbage." This is the same design choice as Java, C#,
Python, Go, and Haskell; in OCaml's case it has been the design
since the language's first release in 1996.

**Garbage collection.** Memory is reclaimed automatically, but only
after every reference to the block has gone out of scope. The GC
walks the *roots* (the stack, the registers, global variables) and
follows every pointer; any block that remains unreachable after that
walk is dead and can be reclaimed. By the time the GC reclaims a
block, no part of the program is holding a pointer to it.

These two together close the bug class structurally. If you cannot
free explicitly, you cannot free early. If the GC only frees blocks
nothing references, "after free" has no observable moment: there is
no time at which a live pointer refers to freed memory.

:::slide

## Use-after-free: closed

```ocaml
let buf = Bytes.create 64 in
Bytes.set buf 0 'h';
(* there is no free(buf) you can write *)
print_char (Bytes.get buf 0)
```

- No `free` primitive in the language.
- GC reclaims memory only when nothing reachable refers to it.
- "Live pointer to freed memory" is unreachable as a program state.

**Closes Chromium's largest single bug category (about 36
percent).**

:::

There is a subtlety worth naming, because it comes up in discussions
with C programmers. The GC reclaims based on *reachability*, not
*liveness*. A pointer can remain reachable long after the program
will never use it again; the GC will not collect the block until the
pointer itself becomes unreachable. This is a *space leak*: the
program uses more memory than it needs. The term is deliberately
distinct from C's *memory leak*. In C, leaked memory has become
unreachable without being freed, and can never be reclaimed; the
GC rules that failure out entirely. In a space leak the memory is
still reachable, and is reclaimed the moment the last reference is
dropped. A space leak is a performance bug, not a memory-safety
bug. It cannot become an arbitrary-code-execution exploit, because
the language still cannot read freed memory; it can only retain too
much memory for too long.

A tuple makes the gap concrete. Bind a pair of two lists, then use
only the first component from then on:

```ocaml
let pair = ([1; 2; 3], [4; 5; 6])
let first = fst pair
(* from here on, only [first] is ever used *)
let _ = List.length first  (* = 3 *)
```

The program never touches the second list again, so it is not
*live*. But it stays *reachable* through `pair` for as long as
`pair` is in scope, so the GC keeps it. A collector that knew the
future could free it; a reachability-based collector cannot tell.
Reachability over-approximates liveness, and the gap between the two
is exactly where space leaks live.

"OCaml has no use-after-free" does not mean "OCaml has perfect memory
hygiene." It means the specific UB pattern of UAF, and the security
consequences that follow from it, are eliminated.

:::slide

## Reachable is not the same as live

```ocaml
let pair = ([1; 2; 3], [4; 5; 6])
let first = fst pair
(* from here on, only [first] is ever used *)
let _ = List.length first  (* = 3 *)
```

- The GC reclaims by **reachability**, not liveness.
- The second list is never used again, yet `pair` keeps it
  reachable: a *space leak*.
- A space leak is a performance bug, not a safety bug.
  - it retains too much memory; it cannot read freed memory.
- **Reachability over-approximates liveness.**

:::

## Buffer overflow: ruled out by bounds checking

The C buffer-overflow pattern was: a program writes or reads beyond
the end of an allocated buffer. The write may corrupt adjacent
memory; the read may leak adjacent memory (the Heartbleed case). The
bug is *spatial*: the address is wrong by some number of bytes.

OCaml rules this class out by making every access to an indexed
structure go through a bounds check. The standard-library functions
`Array.get`, `Array.set`, `String.get`, `Bytes.get`, `Bytes.set`
all take an index, compare it against the structure's length, and
raise `Invalid_argument` if the index is out of range. There is no
unchecked alternative in the safe fragment. The indexing syntax
`a.(i)`, `s.[i]`, and `b.{i}` all desugar to these checked
accessors.

Let us see the check fire. The cell below indexes past the end of a
three-element array; the runtime raises `Invalid_argument` at the
offending access, and control transfers immediately to the nearest
handler, or to the top level. The out-of-bounds *memory* is never
touched. Change the `99` to `1` and re-run to see the in-range
access go through; change it to `-1` to see the check catch the
other side. There is no Heartbleed-shaped leak because there is no
point in time at which the runtime is willing to read bytes outside
the allocated region.

:::slide

## Buffer overflow: closed

```ocaml skip
let xs = [|10; 20; 30|]
let _ = xs.(99)   (* Invalid_argument "index out of bounds" *)
```

- Every `Array.get`, `String.get`, `Bytes.get` bounds-checks.
- `Invalid_argument` raised at the *offending access*.
  - the out-of-bounds bytes are never read.
- No unchecked accessor in the safe fragment.
- Change `99` to `1` and re-run: in range, no complaint.

**No Heartbleed: the read never crosses the boundary.**

:::

The bounds-checking cost is a comparison and a branch on each
access. The expectation might be that this dominates; in practice it
does not. Modern CPUs predict in-bounds branches with near-perfect
accuracy (the cost is around half a cycle in steady state), and the
compiler can sometimes eliminate the check entirely when it can
prove the index is in range. The remaining cost is a small
percentage in most workloads. It is also exactly what the previous
lecture's exploit walk-through was prevented from doing: the bounds
check is the moment Heartbleed would have died.

## Uninitialised read: ruled out by binding-time initialisation

The C uninitialised-read pattern was: a program declares a variable,
reads it before assigning, and gets whatever bytes were left over.
In the kernel cases, the leftover bytes were sometimes sensitive,
and the bug became a security incident.

OCaml rules this class out by *requiring an initial value at binding
time*. There is no equivalent of `int x;`. Every `let x = ...`
requires the right-hand side to evaluate to a value. There is no
syntactic shape that introduces a name without giving it a value.
For mutable storage the same rule applies: `ref` requires an initial
contents, and `Array.make n x` requires the fill value `x`. There is
no `Array.uninitialised n` in the safe library.

The closest analogue is `ref None`, which holds the well-typed value
`None : 'a option`; reading it returns `None`, which the type system
forces the programmer to handle. There is no path from `ref None` to
leaking a secret.

:::slide

## Uninitialised read: closed

```ocaml
let x = 42         (* a value is required *)
let r = ref None   (* even "empty" is the value None *)
```

- Every `let`, every `ref`, every `Array.make` requires a value.
- No syntactic shape introduces a name without one.
- `ref None` is the closest analogue, and `None` is itself
  well-typed: the reader must handle it.

:::

## Double-free: ruled out trivially

This one is the easiest. C's double-free requires the program to
call `free` twice on the same block. OCaml has no `free`. There is
no `free` to call once, let alone twice. The bug class is closed
because the operation does not exist. The same observation makes the
entire family of manual-memory hazards (use-after-free, double-free,
forgotten-free, freeing a pointer that was never allocated)
disappear: the GC owns deallocation, and the programmer cannot
participate in it.

:::slide

## Double-free: closed

- No `free` in the surface language.
  - the operation does not exist.
- All manual-memory hazards close together: UAF, double-free,
  forgotten-free, free-non-allocated.

:::

## Sketch of the runtime

The four "by-construction" arguments rely on the runtime to do real
work. Let us spend a few minutes on what is actually happening,
because the promise about the missing 63rd bit from the
[literals lecture](M02-L01-literals.html) pays off here.

### Tagged pointers

The runtime represents every value uniformly as a single machine
word. Some words are *immediate* values (small integers, booleans,
`()`); others are *pointers* to heap-allocated blocks. The runtime
must tell these apart at every step: the GC has to know which words
to follow, and primitives have to know how to interpret each
operand.

The trick is to use the low bit of every word as a *tag*: immediates
set it to `1`, pointers to `0`. Heap blocks are always allocated at
word-aligned addresses, so a pointer's low bit is naturally zero,
free to use as a tag. One bit test distinguishes an immediate from a
pointer. This is the choice that cost us the 63rd bit of integer
range; the benefit is a uniform representation, a simple GC, and the
categorical absence of the "is this word a pointer?" ambiguity that
makes C-level memory analysis so painful.

The 63-bit figure is a fact about the native compiler on 64-bit
hardware, not about the language. On 32-bit native targets the same
trick gives a 31-bit `int`: one word, one tag bit. And a backend
that does not need the trick can decline it: `js_of_ocaml`, the
compiler that turns OCaml into JavaScript (and the one running the
cells on this very page), represents `int` as a plain 32-bit
JavaScript integer with no tag bit at all, because JavaScript
values already carry their own type information. The runtime will
tell you which world you are in:

```ocaml
let _ = Sys.word_size  (* = 32 here; 64 in native code *)
let _ = Sys.int_size   (* = 32 here; 63 in native code *)
```

Run it here and both answers are 32: no bit lost to a tag. Compile
the same two lines natively on a 64-bit machine and they are 64 and
63: the missing bit is the tag.

:::slide

## Tagged values

<img src="/assets/diagrams/M10-tagged-pointer.svg" alt="Immediate vs pointer word, distinguished by the low bit" style="height: 440px;">

- Low bit `1` = immediate; `0` = pointer. One bit-test tells them
  apart.
- Cost: 63-bit `int`; benefit: a simple, uniform GC.

:::

:::slide

## Ask the runtime

```ocaml
let _ = Sys.word_size  (* = 32 here; 64 in native code *)
let _ = Sys.int_size   (* = 32 here; 63 in native code *)
```

- Native, 64-bit hardware: 64-bit words, 63-bit `int`.
  - the missing bit is the tag.
- Native, 32-bit hardware: 31-bit `int`. Same trick.
- This page runs as JavaScript (`js_of_ocaml`): 32-bit `int`, no
  tag bit.
  - JS values already carry their type.

:::

### Block headers

Every heap-allocated block has a small *header* word in front of it,
encoding the block's size (how many words follow), its *tag* (what
kind of content: tuple-like, string-like, closure, ...), and the GC
colour used during a sweep. The header is invisible to the surface
programmer. It is also the answer to "how does `Array.length` know
the length?": the size is in the header, so every block carries its
size with no extra per-array word.

:::slide

## Block headers

<img src="/assets/diagrams/M10-block-header.svg" alt="A heap block: header word then fields" style="height: 440px;">

- One header word per block: size, tag (kind), GC colour.
- Invisible to the surface programmer.
- This is why `Array.length` and bounds checks are O(1) with no
  extra storage.

:::

### What the GC does

The GC's job is to find and reclaim memory the program will not use
again. OCaml's GC is *generational*: it bets that most allocations
die young. New blocks go in a small *minor* heap (fast bump-pointer
allocation), collected often and cheaply; survivors are promoted to
a *major* heap, collected less often by mark-sweep-compact. The
conceptual model:

1. Allocate: bump a pointer in the minor heap, write the header,
   return the address.
2. Minor heap fills: walk roots, copy anything still reachable into
   the major heap, reclaim the rest of the minor heap wholesale.
3. Major heap accumulates: periodically mark every reachable block
   from the roots and reclaim the unmarked ones; compaction may
   defragment.

Reachability is central. A block is reachable if a root points at
it, or a reachable block points at it. The GC reclaims *only*
unreachable blocks, and no reachable block points at an unreachable
one, so at the moment a block is reclaimed nothing in the program
points at it. The C use-after-free pattern has no representation in
this model.

:::slide

## The GC, in one paragraph

<img src="/assets/diagrams/M10-gc-reachability.svg" alt="Roots reach live blocks; the rest is garbage" style="height: 440px;">

- Walk the **roots**; anything reachable is live, the rest is
  garbage.
- Garbage is reclaimed only when unreachable.
  - so no live pointer ever refers to freed memory.

:::

### Why the GC can move blocks

Tagged words and block headers together explain a superpower of
OCaml's GC: it can *move* blocks, to compact the heap or to promote
survivors out of the minor heap. Moving a block means rewriting
every pointer to it, and the runtime can do that only because the
tag bit lets it enumerate exactly which words are pointers. One more
property is needed, and OCaml has it by construction: there are no
*interior pointers*. An OCaml pointer always points at the first
field of a block, never into the middle of an object. So every
pointer determines exactly one block (its header sits one word
before the address), and after the block moves there is exactly one
correct new value to write. C has neither property: a word holding a
`long` is indistinguishable from one holding a `void *`, and
pointers into the middle of arrays and structs are everywhere, so a
C runtime can never relocate an object.

:::slide

## Why the GC can *move* blocks

<img src="/assets/diagrams/M10-moving-gc.svg" alt="Moving a live block and rewriting pointers; C cannot" style="height: 440px;">

- Moving a block means rewriting every pointer to it.
- No *interior pointers*: every pointer targets a block's start.
  - the header is one word before; the new value is unique.

:::

The total runtime overhead of the GC is typically a few percent of
CPU time in long-running workloads; the bounds-check overhead is
smaller. Together the safety overhead is a small fraction of the
program's runtime, and in exchange the four bug classes are
eliminated.

## A small exercise

:::quiz code id=M10-L02-q1
Write a function `safe_nth : 'a list -> int -> 'a option` that
returns `Some x` if position `n` is in range, and `None` otherwise.
The function should never raise an exception, even on negative
indices or indices past the end. Hint: walk the list, decrementing
the index; return `None` if the list runs out or the index is
negative.

```ocaml
let safe_nth xs n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (safe_nth [1; 2; 3] 0 = Some 1) "head";
  check (safe_nth [1; 2; 3] 2 = Some 3) "last";
  check (safe_nth [1; 2; 3] 3 = None)   "past end";
  check (safe_nth [1; 2; 3] 99 = None)  "way past";
  check (safe_nth [1; 2; 3] (-1) = None) "negative";
  check (safe_nth ([] : int list) 0 = None) "empty";
  print_endline "all tests passed"
```
:::

:::solution

A reference solution walks the list, decrementing the index, and
returns `None` on the empty list or a negative index.

```ocaml
let rec safe_nth xs n =
  if n < 0 then None
  else match xs with
    | [] -> None
    | x :: rest -> if n = 0 then Some x else safe_nth rest (n - 1)
```

This is the OCaml-flavoured version of bounds-checked indexing.
`List.nth` raises `Failure` out of bounds; if you want a non-raising
version you write one. Either way the out-of-bounds bytes are never
read; the only question is whether the boundary is reported as an
exception or as `None`.

:::

:::quiz mcq id=M10-L02-q2
A C program calls `free(p)`, and then a few microseconds later
another part of the program reads `*p`. What does the OCaml analogue
look like?

- [ ] The OCaml program also reads stale bytes, but the GC catches
  it later.
- [x] Safe OCaml has no `free`; reachable blocks stay live.
- [ ] The OCaml program raises a runtime exception "use after free".
- [ ] The OCaml program's behaviour is implementation-defined.

**Why:** OCaml has no explicit `free`. The GC reclaims a block only
after it becomes unreachable. The "free, then later access the freed
pointer" pattern requires a live reference to exist *after* the
free, which contradicts the GC's reclamation rule. The pattern is
not implementable in safe OCaml, and there is no "use after free"
exception because there is no moment at which a live reference points
at a freed block.
:::

:::quiz mcq id=M10-L02-q3
Why does the OCaml runtime use the low bit of every value as a tag,
even though it costs one bit of integer range?

- [ ] To accelerate integer arithmetic on x86.
- [ ] To distinguish signed from unsigned integers at runtime.
- [x] To distinguish pointers from immediate values.
- [ ] Backwards compatibility with 32-bit machines.

**Why:** OCaml represents every value uniformly as a single word.
The GC must walk every reachable word and decide whether to follow
it as a pointer; primitives must decide whether an operand is a heap
address or a boxed value. The low-bit tag (`1` for immediates, `0`
for pointers, heap allocations always aligned) means one bit test
suffices. The cost is a 63-bit `int`; the benefit is a uniform,
simple GC.
:::

## The honest boundary

The four arguments hold for the *safe fragment*: the surface
language and its standard library, excluding `Obj`, `Marshal` with
the wrong type, and FFI. Step outside and the guarantees weaken. The
unsafe operations are deliberately named (`Obj.magic` has "magic" in
the name; `Marshal.from_string` takes a type the runtime does not
check; FFI requires the keyword `external`), so a code review can
ban them outside specifically-audited modules. A later lecture in
this module walks that boundary in detail.

:::slide

## Honest boundary

- The four guarantees hold for the **safe fragment**: surface
  language + safe stdlib.
- Outside it (`Obj.magic`, `Marshal`, FFI) the guarantees weaken.
- The unsafe operations are syntactically named, so they are
  reviewable.

:::

## What's next

The [next lecture](M10-L03-data-races-are-ub.html) turns to a UB
category we have so far only named: data races, the bugs that appear
when a program runs on more than one core at once. Then a lecture on
[where OCaml itself has UB](M10-L04-where-ocaml-has-ub.html) (the
escape hatches, and resource safety beyond memory), and finally the
[tutorial](M10-L05-tutorial.html) that walks one real CVE end to end
and shows the same bug is structurally impossible in OCaml.

:::slide

## What's next

- Next: **data races are undefined behaviour.** What happens on
  many cores.
- Then: where OCaml itself has UB, and resource safety beyond
  memory.
- Finally: walk Heartbleed end to end.

:::

## Reading

- **Cornell CS3110**, *References and memory locations*:
  <https://cs3110.github.io/textbook/chapters/mut/refs.html>
- **Real World OCaml**, *Memory representation of values*:
  <https://dev.realworldocaml.org/runtime-memory-layout.html>
- **OCaml manual**, *The garbage collector*:
  <https://v2.ocaml.org/manual/intfc.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The runtime sketch (tagged pointers, block headers, GC)
is the standard exposition that appears in the OCaml manual, Cornell
CS3110, and Real World OCaml; we present the conceptual minimum the
rest of the module relies on. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
