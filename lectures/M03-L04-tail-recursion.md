---
title: "Tail recursion and accumulators"
lecture_no: 4
week: 3
duration_target_min: 25
concepts: [tail call, tail-recursive functions, accumulator pattern, stack frames]
keywords: [OCaml, tail recursion, accumulator, stack overflow, optimization]
activity_question: "Take the [power : int -> int -> int] function from the recursion lecture and rewrite it tail-recursively with an accumulator. Same signature; same answers; constant stack."
think_about_this: "Why does the compiler need to *recognize* a tail call, instead of optimizing every recursive call? What does a non-tail call need to keep on the stack that a tail call doesn't?"
reading:
  - title: "Cornell CS3110, Tail recursion"
    url: https://cs3110.github.io/textbook/chapters/basics/functions.html
---

# Tail recursion and accumulators


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tail recursion and accumulators</h2>
<p class="title-slide-label">Module 3 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: tail recursion

- Naive recursive functions crash on big inputs: *stack overflow*.
  - Each call keeps a frame to finish work after the return.
- The fix: rewrite so the recursive call is the *last* step.
  - The compiler then reuses the frame: constant stack space.
- The tool: the *accumulator pattern*, one extra parameter.
- After this lecture: recursion as cheap as a C `for` loop.

:::

The naive `factorial` and `sum_up_to` we wrote in
[the recursion lecture](M03-L02-recursion.html#a-first-recursive-function)
work fine for small inputs and crash with a stack overflow for
big ones.
The crash is not a bug in OCaml; it is a fundamental consequence
of how function calls use memory. This lecture shows what is going
wrong, introduces the technique that fixes it, and walks through
the rewrite on several standard functions.

The technique has two names. *Tail recursion* refers to the shape of
the recursive function. *Tail-call optimisation* (often abbreviated
TCO) refers to what the compiler does with such a function. The two
work together: you write your recursion in a particular form, and
the compiler turns that form into a constant-space loop. Neither
half works alone. The compiler cannot rewrite arbitrary recursive
functions to be tail-recursive; you cannot avoid stack overflows by
wishing.

The cost to you is small: an extra parameter (the *accumulator*) and
an inner helper. The benefit is large: your recursive functions stop
crashing on big inputs and they run as fast as the equivalent `for`
loop in C. The technique is standard across functional languages
(Scheme, Haskell, ML, F#) and appears in mainstream ones with
caveats: [GCC](https://gcc.gnu.org/) and
[Clang](https://clang.llvm.org/) eliminate tail calls in C code
when optimisation is enabled; among JavaScript engines, only
JavaScriptCore (Safari) implements the proper tail calls the
language standard calls for; Java does not do it at all.

## What a stack overflow looks like

The simplest recursion that demonstrates the problem is summing the
integers from `1` to `n`. We saw the naive version in
[the recursion lecture](M03-L02-recursion.html#recursion-on-numbers-summing):

```ocaml
let rec sum_up_to n =
  if n = 0 then 0
  else n + sum_up_to (n - 1)
```

`sum_up_to 10` works. `sum_up_to 1_000` works. Push the input
high enough and it crashes. Run this cell and watch:

```ocaml skip
let _ = sum_up_to 1_000_000  (* Stack overflow! *)
```

The error is `Stack overflow during evaluation (looping
recursion?)`. It is not a looping recursion; the recursion
terminates correctly, each step reducing `n` by one. The problem
is that each call needs its own stack frame, and a million frames
is more than any environment will give us. Exactly where the
limit falls depends on the environment: the in-browser toplevel
on this page gives up after a few thousand frames, and native
OCaml lasts longer but falls over too; a million exceeds them
all. To understand why each call needs a frame,
look at the body of the recursive case: `n + sum_up_to (n - 1)`.
After the recursive call returns, we still need to do an addition:
take its result and add `n` to it. To do that addition, we have to
remember `n` across the call. That memory has to live somewhere;
the standard place is the stack.

This crash is common enough to have named a landmark of the
internet: the programming question-and-answer site
[Stack Overflow](https://en.wikipedia.org/wiki/Stack_Overflow),
founded in 2008, takes its name from exactly this failure. The
rest of this lecture is about avoiding it.

:::slide

## What a stack overflow looks like

```ocaml skip
let rec sum_up_to n =
  if n = 0 then 0
  else n + sum_up_to (n - 1)

let _ = sum_up_to 1_000_000  (* Stack overflow! *)
```

- Crashes: `Stack overflow during evaluation`.
- Each call needs a stack frame to remember "what to do with the result".
- Body `n + sum_up_to (n - 1)`: must remember `n` across the call.
- A million frames: the stack runs out long before the base case.
  - Exact limit varies by environment (in-browser: a few
    thousand frames).

:::

Picture the stack during `sum_up_to 5`. We push a frame for
`sum_up_to 5`, which calls `sum_up_to 4`; we push a frame for
that, which calls `sum_up_to 3`; another frame; another; another.
By the time we hit the base case `sum_up_to 0 = 0`, the stack has
*six* frames. Each frame holds a copy of `n` (5, 4, 3, 2, 1, 0
respectively) and a "return-here-and-add" instruction. As
`sum_up_to 0` returns 0, the stack unwinds: frame for `n = 1`
returns `1 + 0 = 1`; frame for
`n = 2` returns `2 + 1 = 3`; and so on, building up `15` at the
top.

For `n = 5` the stack of six frames is fine. For `n = 1_000_000`,
the stack runs out. The operating system (or, in the browser, the
JS engine) imposes a stack size limit; the browser's is the
strictest, typically room for a few thousand frames. Each frame
is some tens of bytes; enough frames, and we crash.

The problem is not specific to OCaml. Try the equivalent recursive
sum in Python, in Java, in C: they all crash for large `n`. Python
even crashes faster, because its recursion limit defaults to about
1000 (you have to explicitly raise it). The difference is that in
those languages, the natural way to compute a sum is a `for` loop,
which uses no stack at all; in OCaml, the natural way is recursion,
so we run into the stack limit a lot sooner unless we are careful.

## What is a tail call?

The fix is to rewrite the function so that the recursive call has
*nothing left to do after it returns*. Such a call is in *tail
position*.

The crisp definition: a function call is in tail position if its
value is the immediate result of the enclosing function, with no
further computation between the call returning and the function
returning. The recursive call to `sum_up_to` in
`n + sum_up_to (n - 1)` is *not* in tail position: after it
returns, we have to do an addition before we can return ourselves.
The recursive call in `sum_up_to (n - 1)` *would* be in tail
position, if we wrote a function that does nothing but recur.

:::slide

## A tail call is a recursive call with nothing left to do

- A call is **in tail position** if its result is the final result.
- Nothing happens after the call returns.

```ocaml
let rec f n = if n = 0 then 0 else f (n - 1)    (* tail call *)
let rec g n = if n = 0 then 0 else 1 + g (n - 1)  (* NOT tail call *)
```

- In `f`, the call's result is returned directly: no stack frame needed.
- In `g`, we still need `1 + ...` after; the frame must persist.

:::

The key question for any recursive call is: *is the recursive call
the very last thing this function does in this branch?* If yes, it
is in tail position. If after it returns we still need to add, or
multiply, or cons, or compare, or anything else, it is not. Note
that "the last expression in the source code" is not quite the same
as "in tail position." The position is about *the order in which
operations happen*, not where they appear on the page.

A useful mental test: replace the recursive call with a placeholder
(say, the literal `42`) and look at what would happen. In `f`, the
function returns `42` directly. The call is in tail position. In
`g`, the function would compute `1 + 42 = 43` and return that.
There is computation after the call. The call is not in tail
position.

## The optimisation

The compiler can recognise tail calls. When it does, it generates
code that *reuses* the current stack frame for the call, instead of
allocating a new one. The old frame's contents (parameters, return
address) are overwritten with the new call's contents; control
transfers to the callee without growing the stack.

:::slide

## OCaml optimizes tail calls

- Compiler **reuses** the current stack frame for a tail call.
- This is **tail-call optimization** (TCO).
- Tail-recursive functions use *constant* stack space.
- Enabled automatically; just write recursion in tail form.

:::

This optimisation, named in a [classic 1977 paper by Guy
Steele](https://dl.acm.org/doi/pdf/10.1145/800179.810196), is what
makes recursion in functional languages competitive with iteration.
Without it, every recursive call grows the stack; with it, a
tail-recursive function runs in constant stack space, the same as a
`for` loop.

The optimisation is enabled by the OCaml compiler automatically. You
do not pass a flag. You do not annotate the function. The compiler
inspects the structure of each recursive call and, if it sees that
the call is in tail position, emits the frame-reusing code. The
*programmer's* job is just to *write* the recursion in tail form;
the *compiler's* job is to recognise it and optimise.

## The accumulator pattern

The most common way to make a non-tail-recursive function
tail-recursive is the *accumulator pattern*. The idea: move the work
that was happening *after* the recursive call to happen *before*
it. To do that, you add an extra parameter (the accumulator) that
carries the partial result down through the recursion. When you hit
the base case, the accumulator holds the answer; just return it.

For `sum_up_to`, the work after the recursive call is "add `n`."
Instead, we will add `n` *to a running total* on the way down, and
the base case will return that running total directly.

```ocaml
let sum_up_to n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc + n) (n - 1)
  in
  go 0 n

let _ = sum_up_to 40_000  (* = 800020000 *)
```

No stack overflow this time, even though the non-tail version
would crash at this depth. The recursive call no longer
needs an enclosing frame, so each call reuses the caller's
instead of pushing a new one. We use `40_000` in the browser because
its JavaScript-backed OCaml runtime has 31-bit integers; the sum to
one million (`500000500000`) exceeds that range. Native 64-bit OCaml
can represent that result as an `int`, and `Int64` is the portable
choice when the required range must be explicit. The stack-space
lesson is unchanged: the tail-recursive loop runs in constant stack.

:::slide

## The accumulator pattern

- Move the work *before* the recursive call; carry a running total.

```ocaml
let sum_up_to n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc + n) (n - 1)
  in
  go 0 n

let _ = sum_up_to 40_000  (* = 800020000; within browser int range *)
```

- **No stack overflow**: the non-tail version crashes at this depth.
- Tail call: recursive call is the *final* expression.
- Browser OCaml uses 31-bit ints; use `Int64` for larger sums.

:::

The structure has three parts worth naming:

- An outer function, `sum_up_to n`, with the original API. The caller
  does not know or care about the accumulator.
- An inner helper, `go`, with an extra parameter `acc` (idiomatic
  shorthand for "accumulator"). The helper does the real recursion.
- An initial call `go 0 n` that supplies the starting accumulator.
  For sums, that is `0`; for products (and powers) it would be
  `1`. In general, the initial accumulator is whatever the base
  case of the original function returned.

This is the standard shape, and we will use it constantly. We
will use it again in
[the local-and-mutual-recursion lecture](M03-L05-local-and-mutual.html)
(where the local-helper pattern gets its own treatment) and
throughout [Module 6](M06-L04-fold.html), where `List.fold_left`
packages exactly this pattern.

## Tracing through it

Walking through `sum_up_to 4`, which calls `go 0 4`:

:::slide

## Walking through it

`sum_up_to 4` calls `go 0 4`.

```
go 0 4  =>  go (0+4) 3  =>  go 4 3
go 4 3  =>  go (4+3) 2  =>  go 7 2
go 7 2  =>  go (7+2) 1  =>  go 9 1
go 9 1  =>  go (9+1) 0  =>  go 10 0
go 10 0 =>  10                          (base case hit)
```

- New accumulator computed *before* the recursive call.
- At `n = 0`, accumulator holds the full sum.
- Same loop a C program would write, without mutation.

:::

Each line in the trace is one tail call. Because each call is in
tail position, the previous frame is overwritten in place: there is
never more than one frame for `go` on the stack at a time. By the
time we hit `go 10 0`, the accumulator holds `4 + 3 + 2 + 1 = 10`,
and we return it.

The trace also makes clear that this is the same computation a
procedural language would do as a loop:

```c
int sum_up_to(int n) {
  int acc = 0;
  for (int i = n; i > 0; i--) acc += i;
  return acc;
}
```

The C version and the tail-recursive OCaml version compile to nearly
identical assembly: same register usage, same loop structure, same
number of instructions. You should think of tail recursion as "the
functional way to write a `for` loop." The shape is recursive; the
behaviour is iterative.

## Factorial, tail-recursive

The same rewrite works for `factorial`. The base case of the original
returned `1`; that is our initial accumulator. The work after the
recursive call was a multiplication by `n`; that becomes a
multiplication into the accumulator on the way down.

```ocaml
let factorial n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc * n) (n - 1)
  in
  go 1 n

let _ = factorial 10  (* = 3628800 *)
```

:::slide

## Factorial, tail-recursive

```ocaml
let factorial n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc * n) (n - 1)
  in
  go 1 n

let _ = factorial 10  (* = 3628800 *)
```

- Running product passed as `acc`; base returns `acc`.
- Caveat: `factorial 100` overflows OCaml's `int`.
- For arbitrary precision: `Zarith`.

:::

Same pattern, slightly different glue: the operator is `*` instead
of `+`, and the initial accumulator is `1` (the identity for
multiplication) instead of `0` (the identity for addition). Compare
the two tail-recursive versions side by side and you will see they
are almost the same function; only the operator differs. This will
become familiar by Module 6, where we generalise the pattern to
`List.fold_left`.

One caveat worth noting: `factorial 100` does not overflow the stack
(thanks to TCO), but it *does* overflow OCaml's `int`. The
mathematical result of `100!` is a 158-digit number, far beyond the
range of any 63-bit integer. Multiplications silently wrap around,
and you get a garbage value. For arbitrary-precision arithmetic, the
[Zarith](https://github.com/ocaml/Zarith) library gives you `Z.t`,
which can hold integers of any size. We do not need it in this
course; just know it exists.

Not every recursive function admits this rewrite cleanly. We will
see one such case (`map`) in
[the `List.map` lecture](M06-L02-map.html#tail-recursion-and-listmap),
once we have the right vocabulary to discuss the two-pass
workaround.

## A heuristic for spotting tail calls

The heuristic for whether a call is in tail position: *after the
call returns, is there any computation left in the function?* If
yes, not tail; if no, tail.

:::slide

## A heuristic for spotting tail calls

After the call returns, is there *any* computation left?

- Yes: **not** a tail call.
- No: tail call.

:::

:::slide

## Tail-call heuristic: three examples

```ocaml
let rec a n = if n = 0 then 0 else a (n - 1) + 1
let rec b n = if n = 0 then 0 else 1 + b (n - 1)
let rec c n = if n = 0 then 0 else if n > 100 then c (n - 100) else c (n - 1)
```

- `a`: not tail (adds `1` *after* the call).
- `b`: not tail (the `+` runs *after* the call returns).
- `c`: tail; both branches' recursive calls are final.

:::

Try the heuristic on each:

- `a n`: the recursive call is `a (n - 1)`, and after it we add `1`.
  Not tail.
- `b n`: the recursive call is `b (n - 1)`, evaluated *after* the
  `1`, but the addition is the outermost operation, performed *after*
  the call returns. Not tail. (Note that the textual position is
  misleading here; `1` appears first in source but the recursive call
  must return *before* the `+` can run.)
- `c n`: both branches end in a bare recursive call. The "work" is
  in the test (which happens *before* the call). Both calls are in
  tail position.

A subtle case: what about `if` expressions? In `if test then e1 else
e2`, the calls inside `e1` and `e2` are in tail position relative to
the whole `if` if and only if the `if` itself is in tail position.
So `if n = 0 then 0 else f (n - 1)` has `f (n - 1)` in tail position
(if the `if` is at the top of the function). Compare:
`(if n = 0 then 0 else f (n - 1)) + 1`: now neither branch is in
tail position, because there is an addition after the `if`.

## Activity

:::slide

## Activity

Recall `power` from
[the recursion lecture](M03-L02-recursion.html#worked-example-power):

```ocaml
let rec power x n =
  if n = 0 then 1
  else x * power x (n - 1)
```

Not tail-recursive (the `*` runs after the call). Rewrite it
with an accumulator so that it is.

:::

Before reading on, do the rewrite yourself. The shape is the
`factorial` one we did above: outer function with the original
signature, inner helper with an extra `acc` parameter, base case
returns `acc`.

:::solution

:::slide

## Activity solution

```ocaml
let power x n =
  let rec go acc n =
    if n = 0 then acc
    else go (acc * x) (n - 1)
  in
  go 1 n
```

- Outer function keeps the `int -> int -> int` signature.
- Inner `go` carries an accumulator; `x` stays the same each call.
- Starting accumulator: `1` (what `power x 0` returned).
- Recursive case: fold `* x` into `acc` *before* recursing.

:::

:::

Three questions to ask when you turn an `O(n)`-stack function into
a tail-recursive one:

1. *What is the running result?* This is the value the function
   computes incrementally as it walks the input. Make it a new
   parameter, conventionally `acc`.
2. *What is its starting value?* Whatever the original function
   would have returned in the base case. For `sum_up_to`, that is
   `0`; for `factorial` and `power`, `1`; for `sum_of_squares`,
   `0`.
3. *What happens to it at each step?* Whatever the original
   function did *after* the recursive call. Apply it to `acc`
   *before* recursing, so the recursive call sits in tail position.

The first two answers go into the outer wrapper (call the helper
with the starting value); the third answer reshapes the recursive
case. The base case just returns `acc`.

By the end of Module 4 this rewrite will be muscle memory. By the
end of Module 6, you will rarely write it by hand, because
`List.fold_left` packages exactly this pattern.

## A small code challenge

:::quiz code id=M03-L04-q2
Write a tail-recursive `sum_of_squares : int -> int` that returns
`1*1 + 2*2 + ... + n*n` for non-negative `n`. `sum_of_squares 0 = 0`.

```ocaml
let sum_of_squares n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sum_of_squares 0 = 0)    "zero";
  check (sum_of_squares 1 = 1)    "one";
  check (sum_of_squares 3 = 14)   "small: 1 + 4 + 9";
  check (sum_of_squares 5 = 55)   "five: 1 + 4 + 9 + 16 + 25";
  print_endline "all tests passed"
```
:::

:::solution

`let sum_of_squares n = let rec go acc n = if n = 0 then acc else
go (acc + n * n) (n - 1) in go 0 n`. Initial accumulator is `0`
(the identity for addition); per-step work adds `n * n` into the
accumulator before recursing.

:::

:::quiz mcq id=M03-L04-q1
Which of these recursive calls is in tail position?

```ocaml
let rec h n =
  if n = 0 then 0
  else if n mod 2 = 0 then h (n - 1) else 1 + h (n - 1)
```

- [ ] Both calls to `h (n - 1)`.
- [ ] Only the one in the odd branch, inside `1 + h (n - 1)`.
- [x] Only the one in the even branch (no `1 +` after).
- [ ] Neither.

**Why:** in the even branch, `h (n - 1)` is the result of the
function directly; the call sits in tail position. In the odd
branch, `1 + h (n - 1)`: the `+ 1` runs *after* the recursive call
returns, so the call is not in tail position. The function counts
the odd integers from `1` to `n`; the point of the question is the
*shape* of the two recursive calls, not what the function computes.
:::

## What's next

:::slide

## What's next

Lecture 5: **local functions and mutual recursion**.

- The `go`-inside-a-function pattern, made explicit.
- Functions that refer to each other.

:::

We have used the `let rec go ... in` pattern twice in this
lecture (in `sum_up_to` and `factorial`) without explaining what it
does. The next lecture,
[M03-L05](M03-L05-local-and-mutual.html), is about that pattern:
*local* function definitions, scoped to inside another function.
It also covers *mutual recursion*, two or more functions that call
each other, which uses a related piece of syntax.

## Reading

- **Cornell CS3110**, *Tail recursion*: the textbook treatment, with
  the same recipe and more worked examples:
  <https://cs3110.github.io/textbook/chapters/basics/functions.html>
- Guy Steele, *Debunking the "expensive procedure call" myth, or,
  procedure call implementations considered harmful, or, LAMBDA:
  The Ultimate GOTO* (1977): the original tail-call optimisation
  paper.
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
