---
title: "Where OCaml itself has UB"
lecture_no: 4
week: 10
duration_target_min: 24
concepts: [Obj.magic, Marshal, FFI, unsafe fragment, escape hatch, resource safety, file descriptor, fun_protect, finalisers]
keywords: [OCaml, Obj.magic, Marshal, FFI, external, Ctypes, unsafe, resource safety, file descriptor, with_open_text, fun_protect, finaliser]
activity_question: "Critique a Marshal-from-disk read; identify which construct is not in the safe fragment; the fun_protect cleanup guarantee; why the GC is not the fd-leak defence; and write save_and_restore_ref with fun_protect."
think_about_this: "If the safe fragment rules out the four memory bugs, why does the language ship Obj.magic at all, and why does the garbage collector not just close your leaked file descriptors for you?"
reading:
  - title: "OCaml manual, Module Obj"
    url: https://v2.ocaml.org/api/Obj.html
  - title: "OCaml manual, Module Marshal"
    url: https://v2.ocaml.org/api/Marshal.html
  - title: "Real World OCaml, Foreign Function Interface"
    url: https://dev.realworldocaml.org/foreign-function-interface.html
---

# Where OCaml itself has UB


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Where OCaml itself has UB</h2>
<p class="title-slide-label">Module 10 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The earlier lectures made the safe story precise: in the *safe
fragment*, the four canonical memory bugs are ruled out by
construction, and even data races stay memory-safe. This lecture is
the honest boundary, in two parts.

First, the *escape hatches*. Every memory-safe language ships at
least one explicit escape from its own guarantees, and OCaml is no
exception. The hatches exist for good reasons; they are also where,
if you push hard enough, you can crash the runtime and reproduce the
bug classes the rest of the language excludes. The design question
is not "should they exist?" but "how small and how obvious can the
unsafe surface be, so a code reviewer spots it instantly?"

Second, *resource safety*. Memory is not the only thing a program
holds: file descriptors, sockets, locks, and connections all have
the same acquire/use/release lifecycle, and the same leak /
double-release / use-after-release bugs. The garbage collector does
not manage these. We will see the idiom OCaml uses today, and where
it runs out.

:::slide

## Two halves of the honest boundary

- The **escape hatches**: where OCaml itself admits UB.
  - `Obj.magic`, `Marshal` with the wrong type, the FFI.
- **Resource safety**: memory is only half the story.
  - file descriptors, sockets, locks: acquire / use / release.
- Principle throughout: keep the unsafe core small and auditable.

:::

## The principle of the small escape hatch

Every memory-safe language ships an explicit escape from its own
guarantees: Rust has `unsafe`, Java has `sun.misc.Unsafe`, C# has
the `unsafe` block, Haskell has `unsafePerformIO` and `unsafeCoerce`,
Go has the `unsafe` package. The escape exists because some
operations (interfacing with C, implementing collection primitives,
mapping memory) genuinely require it. The design goal is to make the
escape *small*, *syntactically loud*, and *auditable*. OCaml's are
each named to be obvious: the module is `Obj`, with one function
literally called `magic`; serialisation is `Marshal`; the C-binding
keyword is `external`. None hide what they do.

:::slide

## The small-escape-hatch principle

| Language | Escape hatch |
| --- | --- |
| Rust | `unsafe { ... }` |
| Java | `sun.misc.Unsafe` |
| Haskell | `unsafePerformIO`, `unsafeCoerce` |
| Go | `unsafe` package |
| **OCaml** | `Obj.magic`, `Marshal`, `external` |

- Each is syntactically loud and rare in review.
- Grep-ability is the audit story.

:::

## `Obj.magic`: arbitrary type casts

The `Obj` module exposes the runtime's view of values. The one
function that matters here is:

```text
val Obj.magic : 'a -> 'b
```

The signature is the whole story: it takes a value of any type `'a`
and returns the same bytes claiming any type `'b`. The runtime does
nothing; the type system is simply fooled. If the representations of
`'a` and `'b` coincide, the result behaves; if they do not, the
result is a value whose bytes do not correspond to any valid `'b`,
and operations on it read out of bounds, follow garbage pointers, and
crash the runtime.

```text
let x : int = 42
let l : int list = Obj.magic x
let _ = List.hd l   (* segfault, garbage read, or random data *)
```

The immediate `42` is not a pointer to a cons cell, but `List.hd`
dereferences it as one. The *runtime invariant* the GC relies on
(every pointer points at a valid block with a valid header) has been
broken, silently, by one line. This block is shown statically rather
than as a runnable cell: the cells on this page run as JavaScript,
where values carry their own type information (recall the
`js_of_ocaml` discussion of tagged words), so the native failure
mode does not reproduce; what it does instead is quietly break this
page's OCaml runtime. Compile the three lines natively and you get
the segfault.

:::slide

## `Obj.magic`, the all-purpose footgun

```text
let l : int list = Obj.magic (42 : int)
let _ = List.hd l   (* derefs the immediate 42 as a pointer *)
```

- Takes any value, returns the same bytes claiming any type.
- The runtime is unchanged: it just lies to the type system.
- A wrong cast breaks the GC's invariants: segfault or garbage.
  - (natively; shown statically here, the JS runtime fails
    differently.)

:::

### Why does this exist?

Two historical reasons. *Low-level FFI helpers*: before the FFI grew
its current type-safe surface, some C interfaces manipulated values
at the byte level, and `Obj` was the lower layer. *GADT emulation*:
before OCaml gained GADTs (in 2012), heterogeneous collections were
faked by type-erasing through `Obj.magic` and recovering the type at
the use site. Modern OCaml uses GADTs or first-class modules for the
same patterns. A few legitimate uses remain in high-performance
library and runtime code; application code should never need it.

:::slide

## Why `Obj.magic` exists at all

- Pre-GADT type-system gaps: heterogeneous collections.
- Low-level FFI helpers and runtime-library plumbing.
- Modern application code should never need it.
  - if you are reaching for it, try a GADT or first-class module.

:::

## `Marshal`: serialisation without type checks

`Marshal` serialises any OCaml value to bytes and back. Read the
deserialise signature carefully:

```text
val Marshal.from_string : string -> int -> 'a
```

It returns a value of type `'a`, where `'a` is whatever the caller
writes down, and the runtime *does not check* that the bytes actually
encode that type. This is structurally the same as `Obj.magic`. If
the bytes came from an `int list` and you read them as a `string`,
the runtime hands you a value the type system believes is a `string`;
any string operation misbehaves.

```text
let bytes = Marshal.to_string [1; 2; 3] []
let s : string = Marshal.from_string bytes 0
(* s : string, but the bytes encode [1; 2; 3]. Any use misbehaves. *)
```

(Shown statically for the same reason as the `Obj.magic` block: in
this page's JavaScript runtime the mistyped read does not crash the
way native code does; it just breaks the page's toplevel.)

:::slide

## `Marshal.from_string` is unchecked

```text
let bytes = Marshal.to_string [1; 2; 3] []
let s : string = Marshal.from_string bytes 0
(* s : string, but the bytes encode [1; 2; 3] *)
```

- The runtime returns the bytes; the type annotation is a lie.
- Wrong type at deserialise = the `Obj.magic` bug class.
- The format carries no type tag the reader checks.

:::

### Version skew is the practical hazard

The clean failure (reading `int list` bytes as `string`) is easy to
avoid. The hazard that bites in production is *version skew*: a
producer and consumer of marshalled values are deployed separately,
the producer's type definition evolves (a field added, a constructor
reordered), and the consumer reads the new bytes at the old offsets.
The result looks like the consumer's type but is garbage, and crashes
on access. This is why production OCaml uses `Marshal` only within a single
release of one binary (a value may be written at one point and read
back at another, but both sides share the exact same type
definitions), and tagged formats (JSON via `yojson` or `jsont`, or a
binary format with an explicit version field) at any boundary that
crosses a release.

:::slide

## When to use, when not

| Use case | `Marshal`? | Alternative |
| --- | --- | --- |
| Cache within one release of one binary | Yes | (nothing simpler) |
| Database, persisted across upgrades | **No** | `yojson`, `jsont` |
| Network between independent programs | **No** | JSON, Protobuf |
| Long-term storage | **No** | tagged format with a version |

Tagged formats turn a version mismatch into a parse error, not a
crash.

:::

## FFI: calling into C

OCaml's foreign function interface binds an OCaml name to a C symbol
with the `external` keyword:

```text
external my_c_function : int -> int -> int = "caml_my_c_function"
```

The compiler emits the call and *trusts* the C side to follow the
runtime's conventions; it cannot check that the C code obeys them.
This is the single largest unsafe surface in real OCaml programs:
every binding to a database client, a codec, or a crypto library is
FFI. The OCaml side is type-safe; the C side is C, with all the UB of
the first three lectures in play.

One specific hazard deserves a sentence. The GC may *move* OCaml
values during collection, so a C function holding a pointer to an
OCaml value across an allocation point must *register* it with the
runtime (the `CAMLparam` / `CAMLlocal` macros), or the GC leaves it
dangling. A forgotten registration is a use-after-free no OCaml-side
discipline can prevent. This is why production code keeps the C
surface small: thin stubs, safe OCaml wrappers over them, and tools
like `ctypes` that generate the glue.

:::slide

## FFI: the C boundary

```text
external my_c_function : int -> int -> int = "caml_my_c_function"
```

- `external` names a C symbol; the compiler trusts the stub.
- The C side is C: all C-style UB is in play there.
- The GC may move values; C must register pointers (`CAMLparam`).
- Mitigation: thin stubs, safe OCaml wrappers, `ctypes`.

:::

## OCaml's unsafe surface, in one slide

:::slide

## OCaml's unsafe surface

| Feature | What it lets you do | Audit story |
| --- | --- | --- |
| `Obj.magic` | Arbitrary type cast | Grep; should be empty in app code |
| `Marshal.from_string` | Read bytes as any type | Grep; ban at boundaries |
| `external` (FFI) | Call C | Concentrate in small stubs |
| Races across domains | Weakly-defined reads | See the data-race lecture |

Everything else is safe by construction. Four constructs, all named
and grep-able: there is no fifth hidden hatch.

:::

The contrast with C is the whole point. In C, *every* pointer
operation, *every* memcpy, *every* uninitialised local is a potential
bug, with no safe fragment to retreat to. OCaml's unsafe fragment is
a small, named, syntactically loud subset; the rest is safe.

## Memory safety is half the story

The four bug classes were about memory. Real programs also hold
*resources* that are not memory: file descriptors, sockets, database
connections, mutex locks. Each has the same acquire/use/release
lifecycle as `malloc`/`free`, and the same three bugs. A file
descriptor is a small integer the kernel hands you, backed by a
per-process table entry with a hard, finite limit (often 1024 on
Linux). The contract is `open` then `close`; a long-running server
that leaks one descriptor per request dies with "too many open
files."

:::slide

## The resource-safety bug zoo

<img src="/assets/diagrams/M10-resource-lifecycle.svg" alt="Resource lifecycle and its three bugs" style="height: 440px;">

- **Leak**: acquire, never release (like a memory leak).
- **Double-close**: release twice (like double-free).
- **Use-after-close**: use after release (like use-after-free).

:::

## Open and close, by hand

A file descriptor is opened and closed *explicitly*. `open_in path`
hands you an `in_channel`; you read from it; you call `close_in ic`
yourself when you are done. The compiler does not track the
channel's lifetime. It *trusts you* to do three things: call `close`
on every path out of the function (including the paths where an
exception is raised), call it *exactly once*, and *never* use the
channel after closing it. Miss the first and you leak the
descriptor; break the second and you double-close; break the third
and you read from a closed handle. These are memory's leak,
double-free, and use-after-free again, now for a resource the GC
does not manage.

```text
let ic = open_in "data.txt" in
let line = input_line ic in   (* if this raises, close_in never runs *)
close_in ic                   (* you call this yourself, exactly once *)
```

:::slide

## Open and close, by hand

```text
let ic = open_in "data.txt" in
let line = input_line ic in
close_in ic        (* you call this yourself *)
```

- A file descriptor is a resource: `open_in` ... `close_in`.
- The compiler trusts you to:
  - call close on every exit path, even when the body raises;
  - call it exactly once;
  - never use the channel after close.
- Miss one: leak, double-close, or use-after-close.

:::

## Watching the lifecycle

The next example deliberately removes all real file I/O. Its purpose is
to isolate the *lifecycle*—open, use, close—so each failure is visible
without filenames, operating-system errors, or buffered input getting
in the way. To *see* these bugs rather than just describe them, we use a
tiny stand-in for a file handle. It prints each step, and raises if you
misuse it, modelling exactly the discipline the real `In_channel` API
trusts you to keep:

```ocaml
type handle = { mutable closed : bool }

let my_open () = print_endline "open"; { closed = false }

let use h =
  if h.closed then failwith "use after close" else print_endline "use"

let my_close h =
  if h.closed then failwith "double close"
  else (print_endline "close"; h.closed <- true)
```

The happy path, written by hand, is easy:

```ocaml
let () =
  let h = my_open () in
  use h;
  my_close h           (* prints: open, use, close *)
```

The danger is everywhere *off* that path. If `use h` had raised, the
`my_close h` line would never run, leaking the handle. A second
`my_close h` prints `close` and then raises `double close`. A `use h`
after `my_close h` raises `use after close`. The compiler flags none
of these; the three obligations are entirely on you.

:::slide

## A handle we can watch

```ocaml
type handle = { mutable closed : bool }
let my_open () = print_endline "open"; { closed = false }
let use h =
  if h.closed then failwith "use after close" else print_endline "use"
let my_close h =
  if h.closed then failwith "double close"
  else (print_endline "close"; h.closed <- true)
```

- A stand-in for a file descriptor: open / use / close, each printed.
- Misuse raises, like a real closed channel.

:::

:::slide

## By hand: you carry the obligations

```ocaml
let () =
  let h = my_open () in
  use h;
  my_close h           (* open, use, close *)
```

- The happy path is easy; the danger is the off-paths:
  - a raise before `my_close` leaks the handle;
  - a second `my_close` raises `double close`;
  - `use` after `my_close` raises `use after close`.
- The compiler checks none of these.

:::

## The combinator

OCaml's idiom for resources is *higher-order-function scoping*:
instead of handing you `open` and `close` separately, you wrap the
acquire / use / release in a *combinator*. The building block is a
function that runs some `work`, then runs a `finally` cleanup on
the way out, whether `work` returns or raises. We can define it
ourselves in three lines, with `match ... with exception`:

```ocaml
let fun_protect finally work =
  match work () with
  | x -> finally (); x
  | exception e -> finally (); raise e
```

The `| x ->` arm runs after a normal return; the `| exception e ->`
arm runs if `work ()` raised, running the cleanup and re-raising.
Either way `finally` runs *exactly once*. Now `with_handle` is a
one-liner: open, hand the handle to `f`, and let `fun_protect`
close it on every exit path.

```ocaml
let with_handle f =
  let h = my_open () in
  fun_protect (fun () -> my_close h) (fun () -> f h)
```

The handle is named only inside `f`, and `my_close` runs exactly
once, on both the normal and the exceptional path. (The standard
library ships this same combinator; `In_channel.with_open_text`
is the file-specific version, opening a channel and closing it on
the way out.)

:::slide

## The combinator

```ocaml
let fun_protect finally work =
  match work () with
  | x -> finally (); x
  | exception e -> finally (); raise e

let with_handle f =
  let h = my_open () in
  fun_protect (fun () -> my_close h) (fun () -> f h)
```

- `fun_protect` runs `finally` *exactly once*: on a normal return,
  and on an exception (then re-raises).
- `with_handle`: open, run `f`, close on every exit path.
- The handle is named only inside `f`.

:::

The payoff: `close` runs even when the callback raises.

```ocaml
let () = with_handle (fun h -> use h)    (* open, use, close *)

let () =
  try with_handle (fun h -> use h; failwith "boom")
  with Failure _ -> ()                   (* open, use, close *)
```

The second call's body raises after `use`, yet `close` still prints:
the `finally` fired on the way out. Because the user never writes
`close` and never names the handle outside `f`, all three obligations
are discharged by construction.

:::slide

## Using it: all three bugs gone

```ocaml
let () = with_handle (fun h -> use h)    (* open, use, close *)

let () =
  try with_handle (fun h -> use h; failwith "boom")
  with Failure _ -> ()                   (* open, use, close *)
```

- **Leak**: close runs on every exit, including exceptions.
- **Double-close**: you never call close; the combinator does, once.
- **Use-after-close**: the handle is out of scope after the callback.

:::

## You can still leak it

The guarantee is only as strong as the *scoping*. Nothing stops the
callback from stashing the handle somewhere that outlives the call:
a global `ref`, say. The combinator still closes the handle on the
way out, as promised, but you are left holding a closed one:

```ocaml skip
let escaped = ref None
let () = with_handle (fun h -> escaped := Some h)   (* open, close *)

let () =
  match !escaped with
  | Some h -> use h   (* Exception: Failure "use after close" *)
  | None -> ()
```

The combinator did its job; the leak came from letting the handle
*escape* its scope. Runtime scoping cannot prevent this. A stronger
*type system*, one that tracks whether a value is allowed to escape,
can reject `escaped := Some h` at compile time. That is the kind of
guarantee a later module builds toward.

:::slide

## You can still leak it

```ocaml skip
let escaped = ref None
let () = with_handle (fun h -> escaped := Some h)   (* open, close *)

let () =
  match !escaped with
  | Some h -> use h   (* Failure "use after close" *)
  | None -> ()
```

- Stash the handle in a global `ref`: it outlives its scope.
- The combinator still closed it.
  - so now we use an already-closed handle.
- Runtime scoping cannot stop this.

:::

## Where it breaks down

The escaping handle we just wrote is the simplest case the
combinator cannot cover; there are others. The combinator fits only
when the resource's lifetime nests inside one function call. *Handles
that escape*: a server accepts a socket and hands it to a worker
pool, so the socket must outlive the accept. *Complex lifetimes*: a
buffer shared between two parallel readers, a connection pinned
across a multi-call transaction, a lock taken in one function and
released in another. None fit "open here, close here."

And the GC is not the answer. OCaml channels do install a finaliser
as a safety net, but finalisers are *not prompt* (the GC runs on
memory pressure, not file-descriptor pressure, so a program leaking
descriptors but few bytes hits the limit first), run in *unspecified
order*, and *cannot fail meaningfully* (a failing `close` has nowhere
to report). They are a net, not the discipline.

The common case is closed at *runtime*; the cases it cannot (escaping
handles, complex lifetimes, shared buffers) are exactly the ones a
later module addresses by lifting this discipline into the *type
system*, so the compiler enforces what the programmer today must
remember to wrap.

:::slide

## Where it breaks down

- The escape above is one shape; sockets, shared buffers, and
  cross-call locks are others.
- The GC is not the fix: finalisers are not prompt, unordered, and
  cannot report errors.
- A later module lifts this discipline into the *type system*.
  - the compiler enforces what you must remember to wrap today.

:::

## Activity

:::quiz mcq id=M10-L04-q1
A teammate reviewing OCaml code sees this line, where `raw_bytes`
is a `string` read from a configuration file on disk:

```text
let parsed : Config.t = Marshal.from_string raw_bytes 0
```

What is the most accurate critique?

- [ ] The type annotation `Config.t` is unnecessary.
- [x] If the on-disk format ever diverges from the current `Config.t`
  (across versions), the read succeeds but the value may crash the
  program on any access. Use a tagged format like JSON.
- [ ] `Marshal.from_string` is slow; prefer `Marshal.from_bytes`.
- [ ] The offset `0` is wrong.

**Why:** the issue is version skew. `Marshal.from_string` returns the
bytes claiming the type the caller wrote. Configuration on disk
crosses a version boundary; if the producer's and consumer's
`Config.t` differ, the bytes are read at the wrong offsets and the
value crashes on access. A tagged format detects the mismatch
instead. The other options are minor or incorrect.
:::

:::quiz mcq id=M10-L04-q2
Which of the following is *not* part of OCaml's safe fragment?

- [ ] `Array.get`, which raises `Invalid_argument` out of bounds.
- [ ] `ref` cells used by a single domain at a time.
- [x] `Obj.magic`, which asserts any type for any value.
- [ ] `List.map`, which traverses a list and produces a new one.

**Why:** `Obj.magic` is the canonical escape hatch: it performs no
runtime check and lies to the type system, and a wrong cast crashes
the program. The other three are squarely in the safe fragment:
bounds-checked access, single-domain `ref` (no race possible), and
pure traversal.
:::

:::quiz mcq id=M10-L04-q3
Given `fun_protect finally work` as defined above, what is
guaranteed about `finally`?

- [ ] It runs only when `work` returns normally.
- [ ] It runs only when `work` raises.
- [x] It runs exactly once: on normal return *and* when `work`
  raises (after which the exception is re-raised).
- [ ] It runs zero times if `work` loops forever.

**Why:** "exactly once, on either exit" is the whole point of
`fun_protect`. The `| x ->` arm runs `finally` and returns the
result; the `| exception e ->` arm runs `finally` and re-raises.
(If `work` never returns, no exit happens, so no cleanup happens,
but that is a different bug.)
:::

:::quiz mcq id=M10-L04-q4
Why are the GC and finalisers *not* the primary defence against
file-descriptor leaks, even though `In_channel` installs a finaliser?

- [ ] Finalisers are a recent addition most code has not adopted.
- [x] The GC runs on *memory* pressure, not *resource* pressure: a
  program leaking descriptors but few bytes hits "too many open
  files" before the GC fires; finalisers also run in unspecified
  order and cannot report cleanup errors.
- [ ] Finalisers are unsafe and disabled by default.
- [ ] Finalisers only work on values that escape their function.

**Why:** finalisers are not prompt (GC is triggered by memory, file
descriptors are a separate limited resource), run in unspecified
order, and cannot fail meaningfully. They are a safety net; the
discipline is the combinator.
:::

:::quiz code id=M10-L04-q5
Implement `save_and_restore_ref : 'a ref -> (unit -> 'b) -> 'b` that
snapshots `r`, calls `f ()`, and unconditionally restores the
snapshot to `r` before returning, whether `f` returned or raised.
Use the `fun_protect` combinator from earlier in this lecture.

```ocaml
let save_and_restore_ref r f =
  failwith "not implemented"
```

```ocaml skip
let () =
  let counter = ref 0 in
  let result =
    save_and_restore_ref counter (fun () ->
      counter := 100; assert (!counter = 100); 42)
  in
  assert (result = 42);
  assert (!counter = 0);
  (try save_and_restore_ref counter (fun () ->
       counter := 999; failwith "boom")
   with Failure _ -> ());
  assert (!counter = 0);
  print_endline "all tests passed"
```
:::

:::solution

A reference solution snapshots the value, then restores it in the
`finally`:

```ocaml
let save_and_restore_ref r f =
  let saved = !r in
  fun_protect (fun () -> r := saved) f
```

The snapshot is taken before `fun_protect` runs the body; on either
exit the cleanup fires and `r` is restored. No path through the body
forgets to restore. This is the same shape as `with_handle`:
snapshot, work that may raise, undo on the way out.

:::

## What's next

The [tutorial](M10-L05-tutorial.html) closes the module by walking
one famous CVE, Heartbleed, end to end: the bug in OpenSSL, the
exploit, the one-line fix, and the OCaml equivalent where the same
bug class is structurally impossible. It is where the whole safety
picture (memory, data races, the honest boundary, resources) lands on
one concrete case.

:::slide

## What's next

- Tutorial: walk **Heartbleed** end to end. The OpenSSL bug, the
  exploit, the fix, and why the OCaml version cannot have it.

:::

## Reading

- **OCaml manual**, *Module `Obj`*: <https://v2.ocaml.org/api/Obj.html>
- **OCaml manual**, *Module `Marshal`*:
  <https://v2.ocaml.org/api/Marshal.html>
- **Real World OCaml**, *Foreign Function Interface*:
  <https://dev.realworldocaml.org/foreign-function-interface.html>
- **OCaml manual**, *Interfacing C with OCaml*:
  <https://v2.ocaml.org/manual/intfc.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The descriptions of `Obj.magic`, `Marshal`, the FFI,
and `In_channel` follow the relevant chapters of the OCaml manual
and Real World OCaml; we summarise the safety-relevant subset. The
`fun_protect` combinator is our own three-line definition of the
standard resource-cleanup pattern. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
