---
title: "Streams and laziness"
lecture_no: 4
week: 7
duration_target_min: 22
concepts: [recursive values, infinite data, thunks, streams, lazy values, lazy streams, sieve of Eratosthenes, lazy Fibonacci]
keywords: [OCaml, stream, thunk, lazy, Lazy.force, lazy_t, sieve, Fibonacci]
activity_question: "Write [take_while : ('a -> bool) -> 'a stream -> 'a list] that returns the longest prefix of [s] whose elements satisfy [p]. Verify with [take_while (fun x -> x < 5) (from 0) = [0; 1; 2; 3; 4]]."
think_about_this: "A thunk and a [lazy] value both delay evaluation. What is the one thing [lazy] gives you that a plain [unit -> 'a] does not? When would that one thing matter, and when would it not?"
reading:
  - title: "Cornell CS3110, Sequences and lazy evaluation"
    url: https://cs3110.github.io/textbook/chapters/ds/sequence.html
---

# Streams and laziness


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Streams and laziness</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

We have spent the course building *finite* data: a list with `n`
elements, a tree with so many nodes, an array of a fixed length.
But many problems are naturally described by *infinite* sequences:
the primes, the Fibonacci numbers, the input lines from a socket,
the moves available from every position in a game tree. We do not
want all of them at once (we cannot fit them in memory); we just
want the first few, on demand.

OCaml is a strict language. `let xs = 1 :: heavy_computation ()`
runs `heavy_computation ()` immediately, even if we never look at
the tail. To represent something infinite we need to *delay*
evaluation: keep the head, hold off on the tail until somebody
asks. This lecture builds the *stream*, the standard functional
data structure for that, in two steps. First a stream backed by a
thunk (a `unit -> 'a` function); then a stream backed by a
[`Lazy.t`](https://v2.ocaml.org/api/Lazy.html), which adds *memoization*
so each tail is computed at most once.

:::slide

## This lecture: streams and laziness

- Finite data so far; many problems want *infinite* sequences:
  primes, Fibonacci, input lines, game-tree moves.
- OCaml is strict: `1 :: heavy ()` runs `heavy ()` immediately.
- Need to *delay* the tail until somebody asks.
- Build the *stream*, the standard functional answer, in two
  steps:
  - Stream backed by a thunk (`unit -> 'a`).
  - Stream backed by `Lazy.t`, which adds memoization.
- Recursive values, the sieve of Eratosthenes, and lazy
  Fibonacci along the way.

:::

## Recursive values

OCaml lets you write `let rec f x = ...` for recursive *functions*.
A less-discussed feature: `let rec` works for *values* too, as long
as the recursive occurrence is hidden behind a constructor.

```ocaml
let rec ones = 1 :: ones
```

OCaml accepts this. The toplevel reports
`val ones : int list = [1; <cycle>]`: the value is an infinite
list whose tail is itself, represented at runtime by a single
cons cell that points back to itself. Even though the list is
*conceptually infinite*, it uses *finite* memory.

```ocaml
let rec zero_ones = 0 :: 1 :: zero_ones
```

`val zero_ones : int list = [0; 1; <cycle>]`. Two cons cells, the
second pointing back at the first.

:::slide

## Recursive values

```ocaml
let rec ones = 1 :: ones
let rec zero_ones = 0 :: 1 :: zero_ones
```

- `val ones : int list = [1; <cycle>]`.
- `val zero_ones : int list = [0; 1; <cycle>]`.
- Recursive *value*, not just recursive function.
- Infinite list, *finite* memory: the tail cell loops back.

:::

The catch: this is a *cyclic* list, not a stream. The only way
the cycle exists is that the recursive occurrence sits behind a
constructor (`::`); the structure was built once, in finite
memory, and any traversal will eventually loop. That is enough
for some uses (a circular buffer of fixed shape) but useless for
most others. Try to convert `zero_ones` to a string with
`List.map string_of_int zero_ones` and the call diverges: `List.map`
is strict and walks the list, the list is infinite, the call
never returns.

```text
(* List.map string_of_int zero_ones  (diverges, do not run) *)
```

We need a data structure where each tail is computed *only on
demand*.

## Infinite data structures, properly

The fix: make the tail a *function* of type `unit -> 'a stream`,
not a fully-built `'a stream`. Calling the function "forces" the
tail; not calling it leaves the rest of the structure unbuilt.
This is the trick at the heart of streams.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
```

A stream has a head (a value) and a *thunk* for the tail (a
zero-argument function that, when called, returns the next
stream node). There is no `Nil` constructor: every stream is
infinite. (You can add a `Nil` if you want finite streams; we
omit it for simplicity.)

The recursive definition of `zero_ones` becomes:

```ocaml
let rec zero_ones = Cons (0, fun () -> Cons (1, fun () -> zero_ones))
```

The toplevel reports
`val zero_ones : int stream = Cons (0, <fun>)`. The tail is a
function value, displayed as `<fun>`; it has not been called yet.

Two small accessor functions. `hd` returns the head; `tl` *forces*
the thunk and returns the next node.

```ocaml
let hd (Cons (x, _)) = x
let tl (Cons (_, xs)) = xs ()
```

`hd zero_ones` gives `0` without forcing anything beyond the
outer cons. `tl zero_ones` calls the tail thunk, which builds
the second node `Cons (1, ...)` and returns it.

:::slide

## Streams: type definition + accessors

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)

let hd (Cons (x, _)) = x
let tl (Cons (_, xs)) = xs ()

let rec zero_ones =
  Cons (0, fun () -> Cons (1, fun () -> zero_ones))

let _ = hd zero_ones        (* = 0 *)
let _ = hd (tl zero_ones)   (* = 1 *)
```

- Head: an `'a` value.
- Tail: a **thunk** `unit -> 'a stream`. Not evaluated yet.
- `hd` returns the head; `tl` *forces* the thunk.
- No `Nil`: streams are infinite.

:::

## Consuming a stream

A stream is infinite, but you almost always want a *finite
prefix* of it: the first 10 primes, the first 30 Fibonacci
numbers. The `take` function is the bridge between the infinite
stream world and the finite list world.

```ocaml
let rec take n s =
  if n = 0 then []
  else hd s :: take (n - 1) (tl s)
```

`take` walks the stream, forcing one tail per element, building
up a list of length `n`. The first `n` nodes get computed; the
rest stay as thunks.

```ocaml
let _ = take 10 zero_ones   (* = [0; 1; 0; 1; 0; 1; 0; 1; 0; 1] *)
```

A companion, `drop`, throws away the first `n` elements and
returns the rest of the stream:

```ocaml
let rec drop n s =
  if n = 0 then s
  else drop (n - 1) (tl s)
```

`drop 1 zero_ones` gives a stream whose first element is `1`.

:::slide

## Consuming a stream

```ocaml
let rec take n s =
  if n = 0 then []
  else hd s :: take (n - 1) (tl s)

let rec drop n s =
  if n = 0 then s else drop (n - 1) (tl s)

let _ = take 10 zero_ones
   (* = [0; 1; 0; 1; 0; 1; 0; 1; 0; 1] *)
let _ = hd (drop 3 zero_ones)    (* = 1 *)
```

- `take n s`: first `n` elements as a list.
- `drop n s`: stream with the first `n` elements skipped.
- Both force exactly `n` tails.

:::

## Higher-order functions on streams

The shapes you saw on lists in the
[higher-order-functions module](M06-L02-map.html) carry
over almost line-for-line. `map` applies a function to every
element; `filter` keeps only the elements satisfying a predicate;
`zip` walks two streams in lockstep.

```ocaml
let rec map f s = Cons (f (hd s), fun () -> map f (tl s))

let rec filter p s =
  if p (hd s) then Cons (hd s, fun () -> filter p (tl s))
  else filter p (tl s)

let rec zip f s1 s2 =
  Cons (f (hd s1) (hd s2), fun () -> zip f (tl s1) (tl s2))
```

Notice the shape: each builds a `Cons` whose tail is a thunk that
recurses. The recursion is *not* eager; it happens one tail at a
time, when the consumer asks for more.

```ocaml
let zero_ones_str = map string_of_int zero_ones
let _ = take 6 zero_ones_str   (* = ["0"; "1"; "0"; "1"; "0"; "1"] *)
```

The mapped stream
is itself infinite; we extract a finite prefix with `take`.

A subtlety in `filter`: if no element of the stream satisfies the
predicate, `filter` will spin forever looking for one. (Streams
are infinite; there is no "end" to give up at.) Use `filter` only
when you know matching elements occur regularly.

:::slide

## `map`: transform every element

```ocaml
let rec from n = Cons (n, fun () -> from (n + 1))

let rec map f s = Cons (f (hd s), fun () -> map f (tl s))

let _ = take 5 (map (fun x -> x * x) (from 1))
   (* = [1; 4; 9; 16; 25] *)
```

- One `Cons` cell built per forced step; the tail is a fresh
  thunk that maps the next step.
- Recursion is *demand-driven*: nothing happens until `take`
  forces.

:::

:::slide

## `filter`: keep elements satisfying a predicate

```ocaml
let rec filter p s =
  if p (hd s) then Cons (hd s, fun () -> filter p (tl s))
  else filter p (tl s)

let _ = take 5 (filter (fun x -> x mod 3 = 0) (from 1))
   (* = [3; 6; 9; 12; 15] *)
```

- If the head fails the predicate, `filter` keeps walking
  *without* producing a cons.
- Dangerous case: no element ever satisfies `p` -> `filter`
  diverges, since the stream has no end to stop at.

:::

:::slide

## `zip`: pair up two streams under a function

```ocaml
let rec zip f s1 s2 =
  Cons (f (hd s1) (hd s2), fun () -> zip f (tl s1) (tl s2))

let _ = take 5 (zip (+) (from 1) (from 100))
   (* = [101; 103; 105; 107; 109] *)
```

- Walks both streams in lockstep, combining each pair with `f`.
- Same shape as `zip` on lists; only the tail wrapping
  changes.

:::

## Primes by the sieve of Eratosthenes

A famous use of streams: produce the infinite stream of primes
using the [sieve of Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes).

The idea:

- Start with the stream `[2; 3; 4; 5; 6; 7; ...]`.
- The head is `2`: a prime.
- Filter out every multiple of `2` from the tail.
- The new head is `3`: a prime.
- Filter out every multiple of `3` from the tail.
- Repeat.

Each step contributes one prime and produces a smaller (still
infinite) stream of candidates.

First we need a stream of natural numbers from `n` upward:

```ocaml
let rec from n = Cons (n, fun () -> from (n + 1))
```

Then the sieve itself:

```ocaml
let rec sieve s =
  let p = hd s in
  Cons (p, fun () -> sieve (filter (fun x -> x mod p <> 0) (tl s)))

let primes = sieve (from 2)
let _ = take 10 primes   (* = [2; 3; 5; 7; 11; 13; 17; 19; 23; 29] *)
```

A clean expression of an algorithm that is awkward to state with
finite data. The recursion is exactly the recurrence: "the
primes are `p` followed by the primes of (`tl s` with multiples
of `p` removed)."

:::slide

## Primes: sieve of Eratosthenes

```ocaml
let rec sieve s =
  let p = hd s in
  Cons (p, fun () ->
    sieve (filter (fun x -> x mod p <> 0) (tl s)))

let primes = sieve (from 2)
let _ = take 10 primes
   (* = [2; 3; 5; 7; 11; 13; 17; 19; 23; 29] *)
```

- Head is the next prime; filter its multiples; recurse.
- Stream lets the recursive case stay open-ended.

:::

## Lazy values

A `unit -> 'a` thunk is the cheapest way to delay evaluation, but
it has one cost: every time you force it, the body runs again. We
can see this directly by putting a `print_endline` in the body
and forcing the thunk twice:

```ocaml
let t () = print_endline "running thunk"; 10 + 20
let _ = t ()    (* prints "running thunk"; = 30 *)
let _ = t ()    (* prints "running thunk" AGAIN; = 30 *)
```

The string `running thunk` prints *twice*: the body ran on each
force. For a pure, cheap body that is harmless; for an expensive
computation it is wasteful, and for an effect you wanted to
happen once it is a bug.

OCaml has a built-in primitive for *memoized* delay: the `lazy`
keyword. `lazy e` constructs a value of type `'a Lazy.t` that
wraps the expression `e` *unevaluated*. The first time the value
is forced (with `Lazy.force`), `e` runs and the result is
*cached* (this caching is what "memoization" means); every
subsequent force returns the cached value without re-running `e`.

```ocaml
let v = lazy (print_endline "running lazy"; 10 + 20)
```

`val v : int Lazy.t = <lazy>`. Notice nothing has printed: the
expression has not run.

```ocaml
let _ = Lazy.force v   (* prints "running lazy"; = 30 *)
```

The result and a
"has been forced" flag are stored inside the `Lazy.t`.

```ocaml
let _ = Lazy.force v   (* prints NOTHING; = 30 *)
```

The body did
not run again: the cached value is reused. That is the whole
difference between a thunk (recomputes) and a `lazy` value
(memoizes).

:::slide

## The thunk's one cost: it reruns every time

```ocaml
let t () = print_endline "running thunk"; 10 + 20

let _ = t ()     (* prints "running thunk"; = 30 *)
let _ = t ()     (* prints "running thunk" AGAIN; = 30 *)
```

- A `unit -> 'a` thunk recomputes its body on **every** force.
- The print fires *twice*: the work is redone each time.
- Fine if the body is cheap and pure; wasteful otherwise.

:::

:::slide

## `lazy`: delay, then cache

```ocaml
let v = lazy (print_endline "running lazy"; 10 + 20)
(* val v : int Lazy.t = <lazy>   nothing printed yet *)
```

- `lazy e` wraps `e` *unevaluated*. Type: `'a Lazy.t`.
- Constructing it runs nothing.

:::

:::slide

## `Lazy.force`: run once, then it's cached

```ocaml
let _ = Lazy.force v   (* prints "running lazy"; = 30 *)
let _ = Lazy.force v   (* prints NOTHING;        = 30 *)
```

- First `Lazy.force`: runs the body, **caches** the result.
- Every later force: returns the cached value, no re-run (the
  print fires only once).
- Caching the result of a computation like this is called
  **memoization**: the one thing `lazy` gives you that a plain
  thunk does not.

:::

The `lazy` keyword is syntactic sugar; internally,
[`'a Lazy.t`](https://v2.ocaml.org/api/Lazy.html) is a small
mutable record (the cache lives in a [`ref`](M07-L01-references.html)
slot inside). Forcing reads the slot; if empty, it runs the body
and fills it. This is *the* simplest example of memoization, and
we will return to it as a general technique in the
[next lecture](M07-L05-memoization.html).

## Lazy streams

We can replace the `(unit -> 'a stream)` thunk in the stream type
with `'a stream Lazy.t`. Each tail is now memoized: forced once,
cached, and reused.

```ocaml
type 'a lstream = LCons of 'a * 'a lstream Lazy.t

let lhd (LCons (x, _)) = x
let ltl (LCons (_, t)) = Lazy.force t
```

(The `l` prefix is just to keep this type distinct from the
thunk-based `stream` in this lecture.)

Higher-order functions look almost the same; only the tail
wrapping changes from `fun () -> ...` to `lazy ...`.

```ocaml
let rec ltake n s =
  if n = 0 then [] else lhd s :: ltake (n - 1) (ltl s)

let rec lzip f s1 s2 =
  LCons (f (lhd s1) (lhd s2),
         lazy (lzip f (ltl s1) (ltl s2)))
```

:::slide

## Lazy streams

```ocaml
type 'a lstream = LCons of 'a * 'a lstream Lazy.t

let lhd (LCons (x, _)) = x
let ltl (LCons (_, t)) = Lazy.force t

let rec ltake n s =
  if n = 0 then [] else lhd s :: ltake (n - 1) (ltl s)

let rec lzip f s1 s2 =
  LCons (f (lhd s1) (lhd s2),
         lazy (lzip f (ltl s1) (ltl s2)))

let rec lfrom n = LCons (n, lazy (lfrom (n + 1)))
let _ = ltake 5 (lfrom 0)   (* = [0; 1; 2; 3; 4] *)
```

- Tail is `Lazy.t`, not `unit -> ...`.
- Each tail is computed at most once.
- `ltake` / `lzip` are the lazy versions of `take` / `zip` from
  earlier.

:::

## Fibonacci as a stream

A neat trick: the Fibonacci sequence
`1, 1, 2, 3, 5, 8, 13, 21, ...` satisfies `f(n) = f(n-1) + f(n-2)`.
If `fibs` is the sequence, then `tl fibs` is the same sequence
shifted by one. Zipping `fibs` with `tl fibs` element-wise under
`+` gives the sequence shifted by *two*. Prepending `1; 1` to
that shifted sum recovers `fibs`. With the *thunk*-based stream
(`Cons` / `zip` / `tl` from earlier), this is a one-liner:

```ocaml
let rec fibs =
  Cons (1, fun () ->
    Cons (1, fun () -> zip (+) fibs (tl fibs)))

let _ = take 10 fibs
   (* = [1; 1; 2; 3; 5; 8; 13; 21; 34; 55] *)
```

The definition is *recursive*: `fibs` refers to itself inside its
own body. The thunk wrapping is what makes this safe: the inner
references to `fibs` and `tl fibs` are inside delayed
expressions, so they are not forced when `fibs` is being
constructed.

It produces the right answer, but it is *exponentially slow*.
Each `tl fibs` rebuilds the shifted stream from scratch, and the
`zip` forces both `fibs` and `tl fibs` again at every step, so
the `n`th element costs roughly `f(n)` thunk-forces, the same
exponential blow-up as the naive recursive `fib`.

:::slide

## Fibonacci as a thunk stream: correct but slow

```ocaml
let rec fibs =
  Cons (1, fun () ->
    Cons (1, fun () -> zip (+) fibs (tl fibs)))

let _ = take 10 fibs
   (* = [1; 1; 2; 3; 5; 8; 13; 21; 34; 55] *)
```

- `fibs = 1, 1, (fibs + tl fibs)`: the recurrence as a stream.
- Self-referential, but the `fun () -> ...` keeps it from looping
  at construction time.
- *But*: every `tl` re-forces the prefix. `take 30 fibs` is
  exponential, same blow-up as naive `fib`.

:::

## Fixing the blow-up with a lazy stream

Swap the thunk-based stream for the *lazy* stream (`LCons` /
`lzip` / `ltl`). The definition is identical in shape; only the
tail wrapping changes from `fun () -> ...` to `lazy ...`. We name
it `lfibs` to keep it distinct from the thunk-based `fibs`:

```ocaml
let rec lfibs =
  LCons (1, lazy (
    LCons (1, lazy (lzip (+) lfibs (ltl lfibs)))))

let _ = ltake 10 lfibs
   (* = [1; 1; 2; 3; 5; 8; 13; 21; 34; 55] *)
```

Now each `lfibs` node is forced *once* and memoized. The `lzip`
on the right re-reads already-computed nodes instead of
rebuilding them, so `ltake 30 lfibs` is *linear*. This is the
payoff of memoization: same code shape, exponential to linear,
just by replacing the thunk with a `lazy`.

:::slide

## Fixing the blow-up: lazy stream

```ocaml
let rec lfibs =
  LCons (1, lazy (
    LCons (1, lazy (lzip (+) lfibs (ltl lfibs)))))

let _ = ltake 10 lfibs
   (* = [1; 1; 2; 3; 5; 8; 13; 21; 34; 55] *)
```

- Same shape as the thunk version; tail wrapping is `lazy ...`.
- Each node forced **once** and memoized; reused on every later
  step.
- `ltake 30 lfibs` is now **linear**, not exponential.

:::

## Timing the difference

The exponential-vs-linear claim is easy to *see*. A tiny helper
times a thunk and returns its result alongside the elapsed
milliseconds. `Sys.time` reports the *processor* time the
program has used, not the wall clock; for a single-threaded
pure computation like this the two track each other closely,
and `Sys.time` works in the browser cells too.

```ocaml
let time_it f =
  let t0 = Sys.time () in
  let r = f () in
  (r, (Sys.time () -. t0) *. 1000.)
```

Now race the two streams at a largish prefix. Both compute the
same 30 Fibonacci numbers; only the cost differs:

```ocaml skip
(* thunk stream: recomputes the prefix exponentially *)
let _ = time_it (fun () -> take 30 fibs)    (* = (..., 100s of ms) *)

(* lazy stream: each node memoized, linear *)
let _ = time_it (fun () -> ltake 30 lfibs)  (* = (..., ~0 ms) *)
```

The thunk version takes hundreds of milliseconds (and roughly
doubles for each extra element); the lazy version is effectively
instant. These two cells are not run when the page loads; click
**Run** on each to see the gap on your own machine.

:::slide

## Timing it: thunk vs lazy

```ocaml
let time_it f =
  let t0 = Sys.time () in
  let r = f () in
  (r, (Sys.time () -. t0) *. 1000.)
```

```ocaml skip
let _ = time_it (fun () -> take 30 fibs)   (* slow: ~100s of ms *)
let _ = time_it (fun () -> ltake 30 lfibs) (* fast: ~0 ms *)
```

- `time_it f` returns `(result, CPU milliseconds)`; `Sys.time`
  is processor time, close to wall-clock for pure code.
- Thunk `fibs`: exponential, hundreds of ms at a 30-element prefix.
- Lazy `lfibs`: linear, effectively instant.
- Click **Run**: these are not run on page load.

:::

## A quick check

:::quiz mcq id=M07-L04-q1
What does `take 4 (map (fun x -> x * x) (from 1))` evaluate to?

- [ ] `[0; 1; 4; 9]`
- [x] `[1; 4; 9; 16]`
- [ ] `[1; 2; 3; 4]`
- [ ] diverges

**Why:** `from 1` is the infinite stream `1, 2, 3, 4, ...`.
`map (fun x -> x * x)` squares every element, producing
`1, 4, 9, 16, ...`. `take 4` returns the first four as a list.
:::

:::quiz mcq id=M07-L04-q2
Why does `lazy` give you something a plain `unit -> 'a` thunk
does not?

- [ ] `lazy` is faster to construct than a thunk.
- [x] `lazy` caches the result; a thunk re-runs the body on each force.
- [ ] `lazy` works for infinite values; thunks do not.
- [ ] `lazy` is statically checked; thunks are not.

**Why:** Both delay evaluation. The unique thing `lazy` adds is
*memoization*: the first force runs the body and stashes the
result; subsequent forces return the cached value. A thunk has no
cache; calling it twice runs the body twice.
:::

## Activity

:::slide

## Activity

Write `take_while : ('a -> bool) -> 'a stream -> 'a list` that
returns the longest prefix of `s` whose elements satisfy `p`.
The result is a *list*, not a stream: it terminates as soon as
`p` returns `false`. Verify with `take_while (fun x -> x < 5)
(from 0) = [0; 1; 2; 3; 4]`.

:::

:::quiz code id=M07-L04-q3
Write `take_while : ('a -> bool) -> 'a stream -> 'a list`. It
walks the stream and collects elements until the predicate
returns `false`. If the predicate never returns `false`, the
walk never terminates; callers must make sure it eventually
does.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec from n = Cons (n, fun () -> from (n + 1))

let rec take_while p s =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take_while (fun x -> x < 5) (from 0) = [0; 1; 2; 3; 4])
    "first five naturals";
  check (take_while (fun x -> x < 0) (from 10) = [])
    "predicate fails at the head";
  check (take_while (fun x -> x mod 7 <> 0) (from 1)
         = [1; 2; 3; 4; 5; 6])
    "stops at first multiple of 7";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let rec take_while p s =
  if p (hd s) then hd s :: take_while p (tl s)
  else []

let _ = take_while (fun x -> x < 5)  (from 0)   (* = [0;1;2;3;4] *)
let _ = take_while (fun x -> x < 0)  (from 10)  (* = []          *)
```

- Forces the head, then the tail (only if the predicate still
  holds): laziness preserved.
- Terminates on an infinite stream **only** if `p` eventually
  fails; caller's job to guarantee that.

:::

:::

## What's next

The [next lecture](M07-L05-memoization.html) generalises the
caching trick that makes `Lazy.t` faster than a plain thunk. We
write a `memo` combinator that wraps any function with a cache,
time a memoized Fibonacci against the naive recursive one, and
use the same idea to make a slow recursive edit-distance
function fast. We close with the catch that ties memoization,
laziness, and streams together: all three presume *purity*: a
function that does I/O cannot be safely cached.

:::slide

## What's next

Lecture 5: **memoization**.

- The general technique behind `Lazy.t`'s caching.
- A `memo` combinator for any pure function.
- Memoized Fibonacci, memoized edit distance.
- Memoization presumes purity: side effects do not replay.

:::

## Reading

- **Cornell CS3110**, *Sequences and lazy evaluation*:
  <https://cs3110.github.io/textbook/chapters/ds/sequence.html>
- **Real World OCaml**, *Lazy values*:
  <https://dev.realworldocaml.org/imperative-programming.html#scrollNav-3>

## Sources

This lecture follows the structure and worked examples of
**IIT Madras CS3100**, *Streams, Laziness and Memoization*
(KC Sivaramakrishnan, Monsoon 2020). The stream type, the
sieve of Eratosthenes example, the lazy Fibonacci derivation,
and the framing of thunks vs `Lazy.t` are drawn directly from
the source lecture; prose is freshly authored for the NPTEL
format.
