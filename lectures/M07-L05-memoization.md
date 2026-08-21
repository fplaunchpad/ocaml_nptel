---
title: "Memoization"
lecture_no: 5
week: 7
duration_target_min: 22
concepts: [memoization, caching, hash tables, tying the recursive knot, dynamic programming, purity]
keywords: [OCaml, memoization, Hashtbl, fib, edit distance, dynamic programming, purity]
activity_question: "Write the binomial coefficient in open-recursion form: [binom_open : (int * int -> int) -> int * int -> int] using the identity C(n,k) = C(n-1,k-1) + C(n-1,k). Then build [binom_memo = memo_rec binom_open]. Confirm [binom_memo (30, 15) = 155117520] runs instantly even though the naive version would explode."
think_about_this: "Memoization trades memory for time and only works when the function is *pure*: same input, same output, no side effects. What goes wrong if you memoize a function that reads a file? A function that updates a counter? A function that returns the current time?"
reading:
  - title: "Cornell CS3110, Memoization"
    url: https://cs3110.github.io/textbook/chapters/ds/memoization.html
---

# Memoization


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Memoization</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The [previous lecture](M07-L04-streams-and-laziness.html) ended
on a small puzzle. `Lazy.t` was faster than a plain thunk for
streams because forcing a `Lazy.t` runs the body *once* and
caches the result. That trick (compute on first call, save the
answer, return the saved answer on every subsequent call) has a
name: **memoization**. It is one of the oldest tricks in
functional programming, and it has uses well beyond streams.

This lecture lifts memoization to a general technique. We write
a `memo` combinator that wraps any function with a cache; we
apply it to a slow expensive function and watch the second call
become free; we tackle the trickier case of memoizing *recursive*
functions (which needs a small reshuffling of how the recursion
is written); we use the recursive form to make a naive O(2^n)
Fibonacci run in linear time, and a naive edit-distance function
run in polynomial time. We close on the catch that ties this
lecture and the previous one together: memoization only works for
*pure* functions.

:::slide

## This lecture: memoization

- The `Lazy.t` trick last lecture: compute on first call, save
  the answer, return the saved answer next time.
- That trick has a name: *memoization*.
- Lift it from streams to a general technique:
  - A `memo` combinator that wraps any function with a cache.
  - A `memo_rec` variant that handles *recursive* functions.
- Worked examples
  - naive O(2^n) Fibonacci becomes linear.
  - naive edit distance becomes polynomial.
- The catch: memoization only works for *pure* functions.

:::

## A small helper for timing

To see speedups we need to *measure* them. A short helper:

```ocaml
let time_it f =
  let t0 = Sys.time () in
  let r = f () in
  let dt = (Sys.time () -. t0) *. 1000. in
  Printf.printf "  time = %.1f ms\n%!" dt;
  r
```

`time_it` takes a thunk, runs it, prints the elapsed time in
milliseconds, and returns the result. `Sys.time ()` returns the
*processor* time the program has used so far, in seconds (as a
float); the difference between two readings, scaled by `1000.`,
is the elapsed milliseconds. Processor time is not the wall
clock, but for a single-threaded pure computation the two track
each other closely, and `Sys.time` works in the browser cells.
The `%!` in the format string flushes the output buffer so the
timing line appears immediately.

The slow timing demos in this lecture are *not* run when the
page loads (each costs a second or more); click **Run** on a
timing cell to reproduce the numbers on your own machine.

## The `memo` combinator

A memoized version of `f` should behave just like `f` on every
input. On the *first* call with a given argument it computes the
answer and stashes it in a table; on every subsequent call with
the same argument it returns the stashed answer without
recomputing. The table is a [`Hashtbl`](https://v2.ocaml.org/api/Hashtbl.html)
keyed by the argument, holding the answer as the value.

```ocaml
let memo f =
  let cache = Hashtbl.create 16 in
  fun x ->
    match Hashtbl.find_opt cache x with
    | Some y -> y
    | None ->
      let y = f x in
      Hashtbl.add cache x y;
      y
```

`val memo : ('a -> 'b) -> 'a -> 'b = <fun>`. The type signature
is identical to the function's own type: the wrapper hides the
cache and looks like a regular function from the outside.

A few things worth noticing in the implementation:

- The cache is created *once*, inside the call to `memo`, and
  captured by the returned closure. Every call to the returned
  function shares the same cache.
- The `16` passed to `Hashtbl.create` is only an initial-size hint,
  not a capacity limit. The table grows automatically as entries are
  added; choosing `16` merely avoids starting from an empty allocation.
- `Hashtbl.find_opt` returns `Some y` for a hit and `None` for a
  miss. We pattern-match on it; the hit returns the cached value,
  the miss computes-then-caches.
- The cache lives behind a [`ref`](M07-L01-references.html)-like
  internal: `Hashtbl.add` mutates it. Without the imperative
  toolkit from earlier in this module, we could not write this.

:::slide

## The `memo` combinator

```ocaml
let memo f =
  let cache = Hashtbl.create 16 in
  fun x ->
    match Hashtbl.find_opt cache x with
    | Some y -> y
    | None ->
      let y = f x in
      Hashtbl.add cache x y;
      y
```

- Wraps any `'a -> 'b` with a per-argument cache.
- Hashtbl: `find_opt` for lookup, `add` for insert.
- `Hashtbl.create 16`: initial-size hint, not a 16-entry limit.
- Cache lives inside the closure; every call shares it.
- Type unchanged from outside: `('a -> 'b) -> 'a -> 'b`.

:::

## Memoizing an expensive identity

We need a function that is *deterministic but slow*. The
canonical slow-but-pure function is naive recursive Fibonacci,
which recomputes overlapping subproblems exponentially many
times:

```ocaml
let rec fib n = if n < 2 then 1 else fib (n - 1) + fib (n - 2)
```

`fib 37` does tens of millions of additions: a clearly
measurable fraction of a second in the browser. We use it as the
slow body of an identity-like function that returns its argument
after doing that work:

```ocaml
let slow_id x = let _ = fib 37 in x
```

```ocaml skip
let _ = time_it (fun () -> slow_id 10)   (* = 10, slow *)
let _ = time_it (fun () -> slow_id 10)   (* = 10, slow AGAIN *)
```

Two calls with the same argument; both run `fib 37`; both take
roughly the same time. `slow_id` does not know it has been asked
the same question twice.

Now wrap it:

```ocaml
let memo_id = memo slow_id
```

```ocaml skip
let _ = time_it (fun () -> memo_id 10)   (* = 10, slow: cache miss *)
let _ = time_it (fun () -> memo_id 10)   (* = 10, fast: cache hit *)
let _ = time_it (fun () -> memo_id 20)   (* = 20, slow: different key *)
let _ = time_it (fun () -> memo_id 10)   (* = 10, fast: still cached *)
```

The first call to `memo_id 10` runs `slow_id 10` (and hence
`fib 37`) and caches the result. The second call hits the cache
and returns *instantly*. Different inputs (`10` vs `20`) each get
one slow miss followed by free hits.

:::slide

## Memoizing a slow function: the setup

```ocaml
let rec fib n = if n < 2 then 1 else fib (n - 1) + fib (n - 2)
let slow_id x = let _ = fib 37 in x

let memo_id = memo slow_id
```

- `fib 37` is the slow, pure body.
- `slow_id` returns its argument after doing that work.
- `memo_id` is `slow_id` wrapped with a per-argument cache.

:::

:::slide

## Memoizing a slow function: miss vs hit

```ocaml skip
let _ = time_it (fun () -> memo_id 10)   (* = 10, slow: miss *)
let _ = time_it (fun () -> memo_id 10)   (* = 10, fast: hit *)
let _ = time_it (fun () -> memo_id 20)   (* = 20, slow: new key *)
let _ = time_it (fun () -> memo_id 10)   (* = 10, fast: cached *)
```

- First call per key: cache miss, runs the body (`fib 37`).
- Repeat call with same key: cache hit, returns instantly.
- New key (`20`): another miss.
- Cache persists across calls (it lives in the closure).

:::

## Where plain `memo` actually pays off

Is plain `memo` (without the recursive machinery we build next)
useful on its own? Yes. Memoizing a *one-off* call is pointless:
you pay the work once either way. But `memo` earns its keep
whenever an *expensive pure function is called repeatedly with
arguments that repeat*: the same lookup inside a loop, the same
sub-expression evaluated many times, the same key queried over
and over. The cache turns "once per call" into "once per
*distinct* argument."

Suppose we answer a batch of queries, and the batch has
duplicates. We compare mapping the raw `slow_id` against mapping
a *freshly memoized* copy (`memo slow_id`, evaluated once by
`List.map` so the whole batch shares one cache):

```ocaml skip
let queries = [10; 20; 10; 20; 10; 20; 10; 20]

(* without memo: 8 slow runs *)
let _ = time_it (fun () -> List.map slow_id queries)
   (* = [10; 20; ...] *)

(* with a fresh memo: 2 slow runs (for 10 and 20), 6 cache hits *)
let _ = time_it (fun () -> List.map (memo slow_id) queries)
   (* = [10; 20; ...] *)
```

The plain version runs the slow body once per list element,
eight times. The memoized version runs it only for the two
*distinct* keys; the other six lookups are free. The speedup is
the ratio of total calls to distinct arguments, which grows as
the duplication grows. That is the everyday reason to reach for
`memo`.

(We write `memo slow_id` *inside* the `List.map` so each run
gets its own fresh cache; reusing the earlier `memo_id`, whose
cache already holds `10` and `20`, would make the comparison
read as zero slow runs.)

:::slide

## Where plain `memo` pays off: repeated arguments

```ocaml skip
let queries = [10; 20; 10; 20; 10; 20; 10; 20]

let _ = time_it (fun () -> List.map slow_id queries)
   (* 8 slow runs *)
let _ = time_it (fun () -> List.map (memo slow_id) queries)
   (* 2 slow runs + 6 cache hits *)
```

- Memoizing a *one-off* call is pointless; you pay once either way.
- The win: an expensive pure function called **repeatedly** with
  **repeating** arguments.
- `memo` turns "once per call" into "once per *distinct*
  argument".
- Speedup ratio = total calls / distinct arguments.

:::

## The wrinkle with recursive functions

Now the more interesting case. We used naive `fib` above as a
black-box slow function; this time we want to memoize `fib`
*itself*. Recall its definition:

```ocaml
let rec fib n = if n < 2 then 1 else fib (n - 1) + fib (n - 2)
```

`fib 25` is fine. `fib 35` takes seconds. `fib 40` takes minutes.
The reason: `fib n` calls `fib (n-1)` and `fib (n-2)`; each of
those calls `fib (n-2)`, `fib (n-3)`, `fib (n-3)`, `fib (n-4)`;
the recursion tree branches and recomputes overlapping
subproblems exponentially many times.

This *should* be the classic case for memoization. The same
arguments come up over and over; if we cached each, the total
work would drop to O(n). Try the obvious:

```ocaml skip
let memo_fib_outer = memo fib
let _ = time_it (fun () -> memo_fib_outer 35)   (* slow: cache empty *)
let _ = time_it (fun () -> memo_fib_outer 35)   (* fast: outer hit *)
let _ = time_it (fun () -> memo_fib_outer 34)   (* slow: not cached *)
```

The first call is still exponential; only the *outer* call to
`memo_fib_outer 35` is cached. The internal recursive calls go
back to the original `fib`, not the memoized version. The
problem: `fib`'s body says `fib (n-1) + fib (n-2)`; the names
`fib` inside the body are bound at definition time, to the
non-memoized version.

:::slide

## Memoizing recursive `fib`: the obvious attempt

```ocaml skip
let rec fib n = if n < 2 then 1 else fib (n - 1) + fib (n - 2)
let memo_fib_outer = memo fib

let _ = time_it (fun () -> memo_fib_outer 35)   (* slow *)
let _ = time_it (fun () -> memo_fib_outer 35)   (* fast *)
let _ = time_it (fun () -> memo_fib_outer 34)   (* slow again! *)
```

- First call: slow (full recursion).
- Repeat the **same** arg: fast (outer hit).
- A new nearby arg (`34`): slow *again*, even though `fib 34` was
  computed inside `fib 35`.

:::

:::slide

## Why the obvious attempt fails

```ocaml
let rec fib n =
  if n < 2 then 1
  else fib (n - 1) + fib (n - 2)
(* the two recursive calls above name the ORIGINAL fib, *)
(* not memo_fib_outer                                   *)
```

- `memo` only caches the *outer* call.
- `fib`'s body says `fib (n-1) + fib (n-2)`; those names are
  bound at definition time, to the non-memoized `fib`.
- The inner recursion never touches the cache, so the first
  call is still exponential.

:::

To fix this we have to rewrite `fib` so the recursive call site
is *abstracted out*: instead of calling itself by name, it calls
a function we pass in. This is called *open recursion*.

```ocaml
let fib_open self n =
  if n < 2 then 1 else self (n - 1) + self (n - 2)
```

`val fib_open : (int -> int) -> int -> int = <fun>`. The first
argument is the "recursive call" function; the second is the
input. `fib_open` does not call itself by name at all: where the
closed `fib` wrote `fib (n - 1)`, the open version writes `self
(n - 1)`. To recover the ordinary recursive `fib` you would pass
`fib_open` a `self` equal to `fib` itself, which is exactly what
`let rec` does automatically.

The trick: we get to *choose* what `self` is. If `self` is the
memoized version, every internal call hits the cache too. That
choice is what plain `memo fib` could not make, and it is what
`memo_rec` (next) will make for us.

:::slide

## Open recursion: abstract out the recursive call

```ocaml
(* closed: the body names itself *)
let rec fib n =
  if n < 2 then 1 else fib (n - 1) + fib (n - 2)

(* open: the body calls `self`, supplied by the caller *)
let fib_open self n =
  if n < 2 then 1 else self (n - 1) + self (n - 2)
```

- `fib_open : (int -> int) -> int -> int`: takes its own
  recursive call as the parameter `self`.
- It never names `fib`; it calls whatever `self` it is handed.
- The point: hand it a `self` that goes *through the cache*, and
  every recursive call is memoized, not just the outer one.

:::

## Tying the recursive knot

The classical trick (this is subtle; read it twice). We want a
function `f` such that `f n = fib_open f n`, but where every
call to `f` first checks the cache. We build it in three steps:

1. Create a [`ref`](M07-L01-references.html) holding a *dummy*
   function. We will fill in the real one in step 3.
2. Define the memoized function. When it needs to recurse, it
   reads from the ref and calls *that*. Inside the body, the ref
   does not yet hold the real function; that is fine, because
   the read happens *when the function is called*, not when it
   is defined.
3. Update the ref to point at the memoized function we just built.

```ocaml
let memo_rec f_open =
  let dummy _ = assert false in        (* never actually called *)
  let self_ref = ref dummy in
  let f_memo = memo (fun x -> f_open !self_ref x) in
  self_ref := f_memo;
  f_memo
```

`val memo_rec : (('a -> 'b) -> 'a -> 'b) -> 'a -> 'b = <fun>`.

Reading it carefully:

- `dummy` is a placeholder that crashes if called; `self_ref`
  starts pointing at it. By the time anything actually calls
  through the ref, we will have replaced it (step 3).
- `f_memo` is `memo` applied to a function that takes `x`, looks
  up the current value of `self_ref`, and calls `f_open` with
  that as the recursive function. The `!self_ref` dereference
  happens *at call time*, by which point the ref has been
  updated.
- The last step writes `f_memo` itself into the ref. Now
  `!self_ref` returns the memoized function, and the open
  recursion in `f_open` becomes a recursion through the cache.

The `ref` is being used to tie a recursive knot between two
definitions that cannot be written with plain `let rec` (because
`memo` does not have the right shape for `let rec` to recurse
through it).

:::slide

## `memo_rec`: tying the knot

```ocaml
let memo_rec f_open =
  let dummy _ = assert false in        (* never actually called *)
  let self_ref = ref dummy in
  let f_memo = memo (fun x -> f_open !self_ref x) in
  self_ref := f_memo;
  f_memo
```

- Step 1: ref holds `dummy`, a placeholder.
- Step 2: build `f_memo` so each call reads ref, then calls
  `f_open` with it as the recursive function.
- Step 3: write `f_memo` into the ref. The knot is tied.
- Open recursion + ref + `memo` = self-memoizing recursion.

:::

It looks like a magic trick the first time you see it. The two
things to keep straight:

1. **Open recursion is a rewrite.** Instead of `fib` calling
   itself by name, it takes its own recursive call as a
   parameter (`self`). This is a mechanical edit.
2. **The ref is the trick.** OCaml's `let rec` cannot tie the
   knot for us because `memo` sits in the middle, and `memo` is
   not transparent to `let rec`. The ref lets us refer to the
   final function from inside the function's body, after the
   fact.

## Memoized Fibonacci

The payoff:

```ocaml
let fib_memo = memo_rec fib_open

let _ = time_it (fun () -> fib_memo 30)  (* = 1346269 *)
let _ = time_it (fun () -> fib_memo 30)  (* = 1346269, all cached *)
let _ = time_it (fun () -> fib_memo 35)  (* = 14930352 *)
```

This one is cheap enough to run live on the page. `fib_memo 30`
is fast: the recursive structure visits each
sub-Fibonacci once, caches it, and the work collapses to O(n).
The repeated call is faster still: every node is already cached.
`fib_memo 35` is also fast: it only computes the few nodes not
already in the cache (35, 34, 33, ..., 31), then reuses the
sub-results from the earlier call.

Compare against the naive `fib`: where the naive function
exploded at `n = 35`, the memoized one is fast even for `n` in
the hundreds (subject to integer overflow: `fib` exceeds the
native 63-bit `int` around `n = 90`, and the browser's 32-bit
`int` much sooner, around `n = 45`).

:::slide

## Memoized fib

```ocaml
let fib_memo = memo_rec fib_open

let _ = time_it (fun () -> fib_memo 30)  (* = 1346269 *)
let _ = time_it (fun () -> fib_memo 30)  (* = 1346269, cached *)
let _ = time_it (fun () -> fib_memo 35)  (* = 14930352 *)
```

- First `fib_memo 30`: O(n), each subproblem computed once.
- Repeat `fib_memo 30`: instant (already cached).
- `fib_memo 35`: only the new nodes; rest reused from `30`.
- **Naive**: exponential. **Memoized**: linear after the first call.

:::

## A dynamic-programming case: edit distance

Memoization is the engine behind most of dynamic programming.
The name "dynamic programming", by the way, means nothing: its
inventor Richard Bellman admitted in his autobiography that he
chose it at RAND in the 1950s because the Secretary of Defense,
Charles Wilson, was openly hostile to "research", and Bellman
needed a name "not even a Congressman could object to".
"Dynamic" sounded impressive, "programming" meant planning, and
the funding survived. The technique, as you are about to see, is
just memoized recursion
([Dreyfus's retelling](https://pubsonline.informs.org/doi/10.1287/opre.50.1.48.17791)
has the full story).

*Edit distance* (also known as
[Levenshtein distance](https://en.wikipedia.org/wiki/Levenshtein_distance))
between two strings is the minimum number of single-character
insertions, deletions, or substitutions needed to turn one into
the other. The recurrence:

$$
d(s, t) =
\begin{cases}
|t| & \text{if } |s| = 0 \\
|s| & \text{if } |t| = 0 \\
\min \{ d(s', t)+1,\ d(s, t')+1,\ d(s', t') + c \} & \text{otherwise}
\end{cases}
$$

where `s'` and `t'` are `s` and `t` with their last characters
dropped, and `c` is `0` if the last characters of `s` and `t`
agree (no substitution) or `1` otherwise.

:::slide

## Edit distance: the problem

The **edit distance** (Levenshtein distance) between two strings
is the fewest single-character **inserts, deletes, or
substitutions** that turn one into the other.

$$
d(s, t) =
\begin{cases}
|t| & |s| = 0 \\
|s| & |t| = 0 \\
\min \{ d(s', t)+1,\ d(s, t')+1,\ d(s', t') + c \} & \text{otherwise}
\end{cases}
$$

- `s'` and `t'` are `s` and `t` with the last character dropped.
- `c = 0` if the last chars match, else `1`.
- `d("kitten", "sitting") = 3`. The **three-way** branch is what
  makes the naive recursion exponential, and what memoization
  collapses.

:::

A direct translation:

```ocaml
let rec edit_dist (s, t) =
  let ls = String.length s and lt = String.length t in
  if ls = 0 then lt
  else if lt = 0 then ls
  else
    let s' = String.sub s 0 (ls - 1) in
    let t' = String.sub t 0 (lt - 1) in
    let c = if s.[ls - 1] = t.[lt - 1] then 0 else 1 in
    min (edit_dist (s', t) + 1)
      (min (edit_dist (s, t') + 1) (edit_dist (s', t') + c))
```

`edit_dist ("kitten", "sitting")` is `3`. But try
`edit_dist ("kitten 4.08", "sitting 4.08")` and the call takes
*forever*: the recursion tree branches three ways and revisits
the same prefix pairs over and over.

The same fix from `fib`. Rewrite in open-recursion form, then
hit with `memo_rec`:

```ocaml
let edit_dist_open self (s, t) =
  let ls = String.length s and lt = String.length t in
  if ls = 0 then lt
  else if lt = 0 then ls
  else
    let s' = String.sub s 0 (ls - 1) in
    let t' = String.sub t 0 (lt - 1) in
    let c = if s.[ls - 1] = t.[lt - 1] then 0 else 1 in
    min (self (s', t) + 1)
      (min (self (s, t') + 1) (self (s', t') + c))

let edit_dist_memo = memo_rec edit_dist_open

let _ = time_it (fun () ->
  edit_dist_memo ("kitten", "sitting"))             (* = 3 *)
let _ = time_it (fun () ->
  edit_dist_memo ("kitten 4.08", "sitting 4.08"))   (* = 3 *)
```

Both runs now finish quickly. The memoized version computes
each `(s', t')` pair at most once; the total work is proportional
to the number of distinct sub-pairs, which is O(|s| * |t|). This
is *exactly* the dynamic-programming table you may have seen
filled in row by row in an algorithms class. The recursive
formulation plus memoization gives the same complexity without
the bookkeeping.

:::slide

## Memoized edit distance

```ocaml
let edit_dist_open self (s, t) =
  let ls = String.length s and lt = String.length t in
  if ls = 0 then lt
  else if lt = 0 then ls
  else
    let s' = String.sub s 0 (ls - 1) in
    let t' = String.sub t 0 (lt - 1) in
    let c = if s.[ls - 1] = t.[lt - 1] then 0 else 1 in
    min (self (s', t) + 1)
      (min (self (s, t') + 1) (self (s', t') + c))

let edit_dist_memo = memo_rec edit_dist_open
```

- Same recurrence as the naive version, but in open form.
- `memo_rec` makes each `(s, t)` pair compute at most once.
- Naive: exponential in `|s| + |t|`. Memoized: O(|s| * |t|).
- This is dynamic programming, top-down.

:::

:::slide

## Edit distance: timing the payoff

```ocaml
let _ = time_it (fun () ->
  edit_dist_memo ("kitten", "sitting"))             (* = 3 *)
let _ = time_it (fun () ->
  edit_dist_memo ("kitten 4.08", "sitting 4.08"))   (* = 3 *)
```

- Both return in a few ms (each `(s', t')` pair computed once).
- The *naive* `edit_dist` on the longer pair would run
  effectively forever: three-way branching, no cache.
- Memoized = the DP table, filled top-down on demand.

:::

## Memoization presumes purity

A caveat that ties memoization to laziness and to functional
programming generally. The whole trick (cache the answer; on a
repeat call, return the cached answer) is *only sound* if the
function is **pure**: same input, same output, no side effects.

What happens if we memoize a function with side effects?

```ocaml
let counter = ref 0
let next () = incr counter; !counter
```

Without memoization, `next ()` returns `1, 2, 3, ...` on
successive calls. Suppose we memoize it. `Hashtbl.find_opt`
would key on `()`; the first call returns `1` and stashes it;
every subsequent call returns the cached `1` without running
the body. The side effect of incrementing the counter is *lost*
on every cache hit.

Or a function that reads a file:

```text
let read_config () =
  (* read and parse config.json from disk *)
  ...
```

Memoizing this freezes the answer the first time you call it.
If the file changes on disk later, the cached version does not
notice. That might be what you want (a deliberate "cache this
once and don't re-read") or it might be a bug (you wanted to
pick up changes). The point is that the cache cannot tell the
difference, because the function's *input* did not change; only
the world did.

The same caveat applies to lazy values from the
[previous lecture](M07-L04-streams-and-laziness.html). A
`Lazy.t` runs its body once and caches the result; if the body
has side effects, those run once and then never again. We saw
this on the slide for `lazy (print_endline "running"; ...)`: the
print happened only on the first force.

:::slide

## Memoization presumes purity

- Same input, same output, no side effects.
- **Caches break side effects**: bodies do not re-run.
- Counter function: `incr counter` skipped on every cache hit.
- File-reading function: cached answer frozen against disk changes.
- Same caveat as `Lazy.t`: print/IO inside `lazy` runs once.
- Pure code = safe to memoize. Effectful code = caller beware.

:::

OCaml does not track purity in the type system. (Haskell does;
that is one of its defining features.) Memoizing in OCaml is a
*you-the-author* judgement: you have to know your function is
pure before you wrap it. The compiler will not catch a memoized
side-effecting function for you; the program will just behave
strangely.

## A quick check

:::quiz mcq id=M07-L05-q1
What does `memo` do on the *first* call with a new argument?

- [ ] Skips the call body and returns a default.
- [x] Runs the body, stashes the result in the cache, returns it.
- [ ] Throws because the cache is empty.
- [ ] Computes the result twice for safety.

**Why:** A cache *miss* (the `None` branch of `find_opt`) runs
the wrapped function, stores the result in the hashtable, and
returns it. Subsequent calls with the same argument hit the
cache and skip the body.
:::

:::quiz mcq id=M07-L05-q2
Why does `let memo_fib = memo fib` *not* speed up the recursive
`fib`?

- [ ] `memo` only works on non-recursive functions.
- [ ] The hashtable cannot hold integer keys.
- [x] Its recursive calls still invoke the original `fib`.
- [ ] The wrapper builds a fresh cache for each recursive call.

**Why:** `fib`'s body says `fib (n - 1) + fib (n - 2)`. Those
internal `fib`s are bound at definition time to the unmemoized
function; only the *outermost* call goes through the cache. To
fix this we rewrite `fib` in open-recursion form (taking `self`
as a parameter) and use `memo_rec` to tie the knot.
:::

## Activity

:::slide

## Activity

Use `memo_rec` to build a fast binomial-coefficient function.

1. Write `binom_open self (n, k)` in open-recursion form, using
   the identity `C(n, k) = C(n-1, k-1) + C(n-1, k)` with base
   cases `C(n, 0) = 1` and `C(n, n) = 1`.
2. Define `binom_memo = memo_rec binom_open`.
3. Check that `binom_memo (30, 15) = 155117520` returns instantly
   (the naive recursion would explore O(2^n) calls).

:::

:::quiz code id=M07-L05-q3
Fill in the open-recursion binomial and the memoized version.
Keep the argument as a tuple `(n, k)` so the hashtable can key on
the pair.

```ocaml
let memo f =
  let cache = Hashtbl.create 16 in
  fun x ->
    match Hashtbl.find_opt cache x with
    | Some y -> y
    | None -> let y = f x in Hashtbl.add cache x y; y

let memo_rec f_open =
  let dummy _ = assert false in
  let self_ref = ref dummy in
  let f_memo = memo (fun x -> f_open !self_ref x) in
  self_ref := f_memo;
  f_memo

let binom_open self (n, k) =
  failwith "not implemented"

let binom_memo = memo_rec binom_open
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (binom_memo (5, 0) = 1) "C(5, 0)";
  check (binom_memo (5, 5) = 1) "C(5, 5)";
  check (binom_memo (5, 2) = 10) "C(5, 2)";
  check (binom_memo (10, 5) = 252) "C(10, 5)";
  check (binom_memo (30, 15) = 155117520) "C(30, 15) instantly";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let binom_open self (n, k) =
  if k = 0 || k = n then 1
  else self (n - 1, k - 1) + self (n - 1, k)

let binom_memo = memo_rec binom_open

let _ = binom_memo (30, 15)  (* = 155117520, instant *)
```

- Base cases `k = 0` and `k = n` close the recursion.
- The two `self` calls overlap: `C(n-1, k-1)` and `C(n-1, k)`
  share `C(n-2, k-1)`.
- `memo_rec` collapses the overlap to one call per `(n, k)`.

:::

:::

## What's next

That closes this module's small detour through laziness, streams,
and memoization. The
[next lecture](M07-L06-module-basics.html) starts the second
half of the module: OCaml's *module system*, the unit of code
organisation at scale. Modules group related definitions,
provide namespacing, and (with signatures) hide internals. The
standard library you have been using all course is itself a tree
of modules; we finally meet the language feature that builds it.

:::slide

## What's next

Lecture 6: **module basics**.

- OCaml's module system: how code is organised at scale.
- `module Name = struct ... end`: grouping definitions.
- Namespacing, dot access, `open`.
- The basis for signatures (Lecture 7) and functors (Lecture 8).

:::

## Reading

- **Cornell CS3110**, *Memoization*:
  <https://cs3110.github.io/textbook/chapters/ds/memoization.html>
- **Real World OCaml**, *Memoization and dynamic programming*:
  <https://dev.realworldocaml.org/imperative-programming.html#scrollNav-4>

## Sources

This lecture follows the structure and worked examples of
**IIT Madras CS3100**, *Streams, Laziness and Memoization*
(KC Sivaramakrishnan, Monsoon 2020). The `memo` combinator,
the `memo_rec` knot-tying construction, and the Fibonacci /
edit-distance demonstrations are drawn directly from the source
lecture; prose is freshly authored for the NPTEL format. The
edit-distance code is adapted from Real World OCaml's
*Imperative programming* chapter (which itself credits the
standard dynamic-programming presentation).
