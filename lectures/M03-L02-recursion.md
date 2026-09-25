---
title: "Recursion"
lecture_no: 2
week: 3
youtube_id: n2hC3scjECs
duration_target_min: 25
concepts: [recursion, base case, recursive case, structural recursion, termination]
keywords: [OCaml, recursion, recursive functions, base case, factorial, list length]
activity_question: "Write a recursive function [count_up : int -> int -> unit] that prints each integer from [lo] up to [hi] (inclusive). What is the base case, and how does the recursive call differ from [count_down]?"
think_about_this: "Every recursive function needs a base case. What goes wrong if you forget one? What goes wrong if you have one but the recursive call never approaches it?"
reading:
  - title: "Cornell CS3110, Recursion"
    url: https://cs3110.github.io/textbook/chapters/basics/functions.html
---

# Recursion


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Recursion</h2>
<p class="title-slide-label">Module 3 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: recursion

- A *recursive* function calls itself.
- In OCaml, recursion replaces most uses of `for` / `while` loops.
- Every recursive function has the same three-part shape:
  - one or more *base cases* (direct answer, no recursion);
  - a *recursive case* on a smaller input;
  - termination: the smaller input approaches a base case.
- Recursion in OCaml is cheap; the compiler is good at it.
- Tail recursion (next lecture) makes it efficient.

:::

A recursive function is one that calls itself. In a language without
mutable loop variables, recursion is the main way to "do something N
times" or "walk through a structure." This lecture is about how to
write a recursive function correctly: when to recur, where the base
case goes, why termination matters, and how to think about the whole
thing without getting dizzy.

You have written `for` loops and `while` loops in C, Java, or Python.
In OCaml you will write very few. The closest thing is a `for` loop,
which exists in the language (we cover it in
[the arrays-and-mutation lecture](M07-L02-arrays-and-mutation.html#ocamls-for-and-while-loops))
but is rarely used because mutable state is rarely the natural way
to express a computation. Almost everything that would be a loop
in C is a recursive function in OCaml. That sounds expensive
(function calls? for a loop?), but recursion in OCaml is cheap,
and the compiler is good at translating the natural recursive
style into efficient code. We will see how later in
[the tail-recursion lecture](M03-L04-tail-recursion.html). For now,
the goal is to get comfortable writing recursive functions in the
first place.

## A first recursive function

The classic example is factorial. `0!` is `1`; `n!` for positive
`n` is `n * (n-1)!`. Translated directly:

```ocaml
let rec factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial 5  (* = 120 *)
```

:::slide

## A first recursive function

```ocaml
let rec factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial 5  (* = 120 *)
```

Three things to notice:

- The keyword `rec`: without it, `factorial` isn't in scope in its body.
- The **base case** `if n = 0 then 1`: without one, recursion never stops.
- The **recursive case** `n * factorial (n - 1)`: refers back to the
  function on a *smaller* argument.

:::

Result: `int = 120`, the factorial of 5. Three things to notice in
the definition:

**The `rec` keyword.** OCaml writes `let rec` to introduce a
recursive function. Without `rec`, the name `factorial` is not in
scope inside its own body, and the compiler reports `Unbound value
factorial`. The next slide explains why this is the default.

**The base case.** `if n = 0 then 1`: when the input has the
smallest shape (here, zero), the function returns a direct answer
without recursing. Every recursive function needs at least one
base case. Without one, the function calls itself forever, exhausts
the stack, and crashes.

**The recursive case.** `else n * factorial (n - 1)`: the function
defines its answer in terms of its answer on a *smaller* input.
The smaller input is closer to the base case. The recursive case
trusts that the function works on the smaller input, and combines
that result with the current value to produce the answer for the
current input.

This three-part shape (one or more base cases, plus a recursive
case that reduces toward them) is *every* recursive function you
will write. The pieces vary; the shape does not. Module 3 is
largely about getting fluent with this shape.

## Why `let rec` and not just `let`?

If you forget `rec`, you get a perplexing error. Try:

```text
let factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)
```

:::slide

## Why `let rec` and not just `let`?

```text
let factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)
```

- OCaml rejects: `Unbound value factorial`.
- Inside a plain `let f = ...`, the name `f` isn't yet in scope.
- `let rec` brings the name into scope inside the body.
- Use `let rec` when the function refers to itself.

:::

OCaml rejects this: *"Error: Unbound value factorial."* The reason
is a deliberate choice in the language design. Inside the body of
a plain `let factorial = ...`, the name `factorial` is *not yet in
scope*. References to `factorial` inside the body mean the outer
`factorial` (if any), not the one being defined.

This is the same rule we used for shadowing in
[the let-bindings lecture](M02-L02-let-bindings.html#shadowing): `let x = x + 1`
means "the new `x` is the old `x` plus one." If `let` brought the
new name into scope eagerly, this would mean something different
(an infinite loop trying to reference itself). The default for
`let` is "right-hand side sees the outer scope."

`let rec` overrides this: it says "yes, the name *is* in scope
inside the body too, because the function needs to call itself."
The keyword is a small but important signal: any reader sees `let
rec` and knows this function is recursive, before reading the body.

## Recursion on lists

Lists are the workhorse data structure of every ML-family language,
and recursion on lists is the workhorse pattern. Here is the
classic: count the elements of a list.

```ocaml
let rec length xs =
  match xs with
  | [] -> 0
  | _ :: rest -> 1 + length rest

let _ = length [10; 20; 30; 40]  (* = 4 *)
```

:::slide

## Recursion on lists

```ocaml
let rec length xs =
  match xs with
  | [] -> 0
  | _ :: rest -> 1 + length rest

let _ = length [10; 20; 30; 40]  (* = 4 *)
```

- Base case `[] -> 0`: empty list has length 0.
- Recursive case `_ :: rest -> 1 + length rest`: strip head, recur.
- Uses pattern matching (full coverage in Module 5).

:::

The function uses `match ... with`, which we
will study in detail in [Module 5](M05-L01-basic-patterns.html).
For now, read it as a multi-way branch on the *shape* of the input:

- `[] -> 0`: if the list is empty, return 0.
- `_ :: rest -> 1 + length rest`: if the list has a head element
  (which we don't care about, denoted `_`) and a tail `rest`,
  return 1 plus the length of `rest`.

The `::` is the *cons* constructor: every non-empty list is some
element followed by another list. The pattern `_ :: rest` matches
any non-empty list and binds `rest` to the tail.

This shape (one base case for the empty list, one recursive case
that strips one element and recurs on the rest) is so common it
has a name: *structural recursion on lists*. Most list functions
in OCaml's standard library are written this way:
[`List.map`](M06-L02-map.html), `List.length`,
[`List.filter`](M06-L03-filter.html),
[`List.fold_left`](M06-L04-fold.html). We will revisit all of
them in Module 6.

## Recursion on numbers, counting down

We can also recurse on integers. Here is a function that prints
`n`, `n-1`, ..., 0, in order:

```ocaml
let rec count_down n =
  if n < 0 then ()
  else begin
    print_endline (string_of_int n);
    count_down (n - 1)
  end

let _ = count_down 5  (* prints 5 4 3 2 1 0, one per line *)
```

:::slide

## Recursion on numbers, counting down

```ocaml
let rec count_down n =
  if n < 0 then ()
  else begin
    print_endline (string_of_int n);
    count_down (n - 1)
  end

let _ = count_down 5  (* prints 5 4 3 2 1 0, one per line *)
```

- Base case `n < 0`: do nothing.
- Recursive case: print `n`, then recur on `n - 1`.
- `begin ... end`: sequenced block (more in Module 7).

:::

Run it; you should see `5`, `4`, `3`, `2`, `1`, `0`, each on its
own line. The base case is `n < 0`: do nothing, return `()`. The
recursive case prints the current number and recurs on one less.

The `begin ... end` brackets are just sugar for `(...)`: they
group multiple statements into one expression. Here, "print, then
recur" is the sequenced body. We need the bracketing because the
sequencing `;` would otherwise be ambiguous with the `else`
branch. `begin/end` is the more readable form in OCaml; plain
parens work too. (Side effects and sequencing get full treatment
in [the references lecture](M07-L01-references.html) of Module 7;
for this lecture, just trust the brackets do what you would
expect.)

## Recursion on numbers, summing

Here is a recursive sum function:

```ocaml
let rec sum_up_to n =
  if n = 0 then 0
  else n + sum_up_to (n - 1)

let _ = sum_up_to 10  (* = 55 *)
```

:::slide

## Recursion on numbers, summing

```ocaml
let rec sum_up_to n =
  if n = 0 then 0
  else n + sum_up_to (n - 1)

let _ = sum_up_to 10  (* = 55 *)
```

- Each step reduces `n` by one until zero.
- Closed form `n * (n + 1) / 2` is faster.
- Recursion here to illustrate the pattern.

:::

Result: `55` (which is `10 + 9 + ... + 1 + 0`). There is a
closed-form expression for this sum, `n * (n + 1) / 2`, which is
constant-time rather than linear-time; in real code you would use
the closed form. The recursive version exists to illustrate the
pattern.

This is the cleanest demonstration of the recursive shape on
numbers: base case is zero (the sum of nothing is zero); recursive
case is "the sum up to `n` is `n` plus the sum up to `n-1`."

## Termination: the thing that can go wrong

The most important property of a recursive function is that it
*terminates*: every recursion eventually hits a base case. Here is
a function that does not:

```text
let rec bad n = bad (n + 1)
```

:::slide

## Termination

Every recursive function must **terminate**: hit a base case.

```text
let rec bad n = bad (n + 1)
```

- Type-checks; runs forever; stack overflows.

For termination, every recursive call must move *closer* to a base case.

- `factorial (n - 1)` is closer to `0`.
- `length rest` is shorter than `length xs`.

Always ask: is the recursive argument strictly smaller?

:::

`bad` type-checks fine (the compiler does not verify termination
for arbitrary functions; in general, it cannot, because the
halting problem is undecidable). If you run it, the program calls
`bad (n+1)`, then `bad (n+2)`, then `bad (n+3)`, forever; each
call adds a frame to the stack; eventually the stack overflows
and the program crashes with `Stack overflow during evaluation`.

For termination, the discipline is: every recursive call must
move *closer* to a base case, by some measure. `factorial (n-1)`
is closer to `0` than `factorial n`, if `n` started non-negative.
`length rest` is shorter than `length xs`, if the pattern matched
`_ :: rest`. Whenever you write a recursive call, ask: by what
measure is the argument smaller? If you cannot give a clear
answer, the function might not terminate.

The compiler will not check this for you. You are responsible.
The good news is that for the standard shapes (recurse on a
number that decreases, recurse on a list that shrinks), the
measure is obvious. For more elaborate recursion patterns, you
sometimes have to think carefully.

## What if the input is unexpected?

Consider `factorial` again. What if you call it with a negative
input?

```text
let rec factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial (-1)  (* Stack overflow! *)
```

:::slide

## What if the input is negative?

```text
let rec factorial n =
  if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial (-1)  (* Stack overflow! *)
```

- Stack overflow: `-1, -2, -3, ...` never reaches `0`.

Fix 1: loosen the base case.

```ocaml
let rec factorial n =
  if n <= 0 then 1
  else n * factorial (n - 1)
```

- `<= 0`: treat all non-positive inputs as base.

:::

:::slide

## What if the input is negative?: be strict

Fix 2: reject bad inputs.

```ocaml
let rec factorial n =
  if n < 0 then invalid_arg "factorial: negative input"
  else if n = 0 then 1
  else n * factorial (n - 1)
```

- Rejects negative inputs; surfaces the bug.
- Permissive `<= 0` silently accepts nonsense; strict version
  catches it early.
- Library code: prefer strict. Quick script: permissive is fine.

:::

Stack overflow. The base case is `n = 0`, but if `n = -1`, the
recursive call is `factorial (-2)`, then `factorial (-3)`, and so
on: the recursion moves *away* from the base case.

Two fixes:

1. **Loosen the base case** to catch the bad inputs:

   ```ocaml
   let rec factorial n =
     if n <= 0 then 1
     else n * factorial (n - 1)
   ```

   Now any non-positive input returns 1. This is permissive: it
   silently treats nonsense inputs as `0!`.

2. **Be strict** about valid inputs:

   ```ocaml
   let rec factorial n =
     if n < 0 then invalid_arg "factorial: negative input"
     else if n = 0 then 1
     else n * factorial (n - 1)
   ```

   `invalid_arg` raises an exception (we will see exceptions in
   [Module 7](M07-L03-exceptions.html)). This rejects nonsense
   inputs with a runtime error.

Which is better depends on your context. The strict version
catches bugs early; the permissive version "just works." For a
library function with documented preconditions, the strict version
is usually better. For a quick script where you control all the
inputs, the permissive version is fine. Both are defensible; the
key is to choose deliberately.

## The mental model

The rhythm for reading or writing a recursive function:

:::slide

## The mental model

Rhythm for reading or writing a recursive function:

1. **What is the input made of?** Number (zero or successor)? List (empty or cons)?
2. **What is the base case?** Answer for the smallest input.
3. **What is the recursive case?** Trust the function on smaller
   input; combine with current piece.

This is the **inductive style**.

:::

Three questions:

1. **What is the input made of?** A number is either zero or one
   more than another number. A list is either empty or a head
   followed by another list. Whatever data you are recursing on
   has a *shape* that determines the pattern of cases.

2. **What is the base case?** What is the smallest possible input,
   and what is the answer for it? For a number, usually zero. For
   a list, usually `[]`.

3. **What is the recursive case?** Given a non-smallest input,
   what is the answer in terms of the answer for a *smaller*
   input? You assume the function works correctly on smaller
   inputs (call this the *induction hypothesis*) and write the
   answer for the current input in terms of that.

This is the *inductive style*. It is the same kind of reasoning
you used for proofs by induction in discrete math: prove the base
case, prove that if it works for `n` it works for `n+1`, conclude
it works for all `n`. Recursive function definition is the
computational version of inductive proof. Once you internalise
this style, writing recursive functions becomes mechanical.

## Worked example: power

Compute `x^n` for non-negative integer `n`.

```ocaml
let rec power x n =
  if n = 0 then 1
  else x * power x (n - 1)

let _ = power 2 10  (* = 1024 *)
```

:::slide

## Worked example: power

`power x n = x^n` for integer `n ≥ 0`.

```ocaml
let rec power x n =
  if n = 0 then 1
  else x * power x (n - 1)

let _ = power 2 10  (* = 1024 *)
```

- Base case: anything to the zero is `1`.
- Recursive case: `x^n = x * x^(n-1)`. `n` moves toward the base.

:::

The function follows the same shape: base case `n
= 0` returns `1`; recursive case `x^n = x * x^(n-1)`. Note that
`x` is unchanged in the recursive call; only `n` is reduced. This
is fine: the *measure* by which the recursion makes progress is
`n`, not `x`.

## Two recursive calls: Fibonacci

A recursive function does not have to make exactly one recursive
call per case. Fibonacci makes two:

```ocaml
let rec fib n =
  if n < 2 then n
  else fib (n - 1) + fib (n - 2)

let _ = fib 10  (* = 55 *)
```

:::slide

## Two recursive calls: Fibonacci

```ocaml
let rec fib n =
  if n < 2 then n
  else fib (n - 1) + fib (n - 2)

let _ = fib 10  (* = 55 *)
```

- Two base cases bundled: `fib 0 = 0`, `fib 1 = 1`.
- Recursive case has *two* calls.
- Slow for large `n`: overlapping subproblems recomputed.
- Revisited in the tail-recursion lecture and in Module 6.

:::

Result: `55` (the 10th Fibonacci number). The base case is `n <
2`, which bundles two cases: `fib 0 = 0` and `fib 1 = 1`. The
recursive case calls `fib` twice with different smaller arguments.

This implementation is *slow* for large `n`. Each call computes
`fib (n-1)` and `fib (n-2)`; both of those compute overlapping
subproblems from scratch. The number of function calls grows
exponentially. `fib 40` already takes a noticeable second; `fib
50` takes minutes. The classic fix is *memoisation* (caching
already-computed results) or *iterative bottom-up computation*
(building up from `fib 0` and `fib 1`); we will see the latter
in the [Module 3 tutorial](M03-L06-tutorial.html#why-is-naive-fibonacci-so-slow).

## A small code challenge

:::quiz code id=M03-L02-q2
Write a recursive function `sum_list : int list -> int` that
returns the sum of a list of integers. Empty list sums to 0.

```ocaml
let rec sum_list xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sum_list []           =  0) "empty";
  check (sum_list [1; 2; 3]    =  6) "small";
  check (sum_list [10; -3; 5]  = 12) "with negative";
  check (sum_list [0; 0; 0; 0] =  0) "all zeros";
  print_endline "all tests passed"
```
:::

:::solution

The shape: `match xs with | [] -> 0 | x :: rest -> x + sum_list
rest`. Structural recursion on the list: base case is `[]`,
recursive case is "first element plus sum of the rest."

:::

## Activity

:::slide

## Activity

Write a recursive function `count_up : int -> int -> unit` that
prints each integer from `lo` up to `hi` (inclusive). What is the
base case, and how does the recursive call differ from
`count_down`?

:::

:::solution

:::slide

## Activity solution

```ocaml
let rec count_up lo hi =
  if lo > hi then ()
  else begin
    print_endline (string_of_int lo);
    count_up (lo + 1) hi
  end
```

- Base case `lo > hi`: do nothing.
- Recursive case: print `lo`, recur on `(lo + 1) hi` (only `lo` changes).
- Trace `count_up 1 3`: prints `1, 2, 3`, then `count_up 4 3` hits base.

:::

:::

:::quiz mcq id=M03-L02-q1
For the function below, what is the base case?

```ocaml
let rec count_up lo hi =
  if lo > hi then ()
  else begin
    print_endline (string_of_int lo);
    count_up (lo + 1) hi
  end
```

- [ ] `lo = hi`
- [x] `lo > hi`
- [ ] `lo = 0`
- [ ] There is no base case.

**Why:** the function returns `()` (does nothing) when `lo > hi`.
The recursive case prints `lo` and then calls `count_up (lo + 1)
hi`. For `count_up 1 3`, the prints are `1`, `2`, `3`, then
`count_up 4 3` hits the base case and stops. If the base case
were `lo = hi`, the function would print `1`, `2` and stop
without printing `3`. The current base case (`lo > hi`) is what
makes `hi` print.
:::

## What's next

We have introduced the basic shape of recursion. The next two
lectures put recursion to better use.
[M03-L03](M03-L03-currying.html) covers *currying* and *partial
application*: making the "function returning function" pattern
explicit and using it to write small reusable utilities.
[M03-L04](M03-L04-tail-recursion.html) covers *tail recursion*:
how to make recursive functions run in constant stack space, so
you can recurse on lists of millions of elements without blowing
the stack.

:::slide

## What's next

Lecture 3: **currying and partial application**.

- Make explicit the "function returning function" pattern.

Lecture 4: **tail recursion**.

- Fixes the stack-overflow risk of naive recursive functions.

:::

## Reading

- **Cornell CS3110**, *Recursion*: the textbook chapter, with
  more worked examples and the math-induction connection
  explored:
  <https://cs3110.github.io/textbook/chapters/basics/functions.html>
- **Real World OCaml**, *Lists and Patterns* (recursion section):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
