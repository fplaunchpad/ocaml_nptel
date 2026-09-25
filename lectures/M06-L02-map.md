---
title: "`map`: transform every element"
lecture_no: 2
week: 6
youtube_id: S9ByMTcWpL4
duration_target_min: 22
concepts: [map, transformation, list traversal, polymorphism, function arguments]
keywords: [OCaml, map, list, higher-order, transformation]
activity_question: "Write [zip_with : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list] that pairs up two lists element-wise using the given combining function. What happens for lists of different lengths?"
think_about_this: "The natural definition of [map] conses onto a recursive call, so it is not tail-recursive. What goes wrong if you fix it by appending to an accumulator with [@]?"
reading:
  - title: "Cornell CS3110, Map"
    url: https://cs3110.github.io/textbook/chapters/hop/map.html
---

# `map`: transform every element


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">`map`: transform every element</h2>
<p class="title-slide-label">Module 6 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

`map` takes a function `f` and a list `xs`, and produces a new list
where every element is `f` applied to the corresponding element of
`xs`. Its type signature, `('a -> 'b) -> 'a list -> 'b list`, says
the same thing in formal language: give me a function from `'a` to
`'b`, give me a list of `'a`s, and I will give you a list of `'b`s
with the same length and order.

It is by some distance the most-used higher-order function in
everyday OCaml. Any time you have a list and you want a new list of
"the same things, but transformed somehow," `map` is the right tool.
This lecture goes through `map` carefully because the patterns we
develop here (extracting a walk, writing recursive higher-order
functions, thinking about [polymorphic types](M04-L04-recursive-types.html#polymorphism))
carry over to [`filter`](M06-L03-filter.html), [`fold`](M06-L04-fold.html),
and everything else in this module.

:::slide

## This lecture: `map`

- `map f xs`: a new list, each element transformed by `f`.
- Type: `('a -> 'b) -> 'a list -> 'b list`. Same length, same order.
- The most-used higher-order function in everyday OCaml.
- Pattern: take a list, get a list of "the same things, transformed".
- We write it from scratch; the moves carry over to `filter` and `fold`.

:::

## Writing `map` from scratch

We saw a hint of `map` at the end of [Lecture 1](M06-L01-functions-revisited.html#why-bother-the-abstraction-principle).
Here is the full derivation. Suppose we want two list functions:

```ocaml
let rec double_each = function
  | [] -> []
  | h :: t -> (h * 2) :: double_each t

let rec string_lengths = function
  | [] -> []
  | h :: t -> String.length h :: string_lengths t

let _ = double_each [1; 2; 3]            (* = [2; 4; 6] *)
let _ = string_lengths ["hi"; "world"]   (* = [2; 5] *)
```

`double_each` doubles every element of an `int list`. `string_lengths`
turns a `string list` into the `int list` of their lengths. Notice
the second function's input and output element types differ; the
output list is still a list, the same length, but built from values
computed from each input.

The two functions share a skeleton: dispatch on the list, return
`[]` on `[]`, and on a cons, compute a fresh head and cons it onto
the recursive call. The only thing that differs is *what each
function does to the head*. Pull that out as a parameter `f`:

```ocaml
let rec map f = function
  | [] -> []
  | h :: t -> f h :: map f t

let _ = map (fun x -> x * 2) [1; 2; 3]     (* = [2; 4; 6] *)
let _ = map String.length ["hi"; "world"]  (* = [2; 5] *)
```

:::slide

## Definition

```ocaml
let rec map f = function
  | [] -> []
  | h :: t -> f h :: map f t

let _ = map (fun x -> x * x) [1; 2; 3; 4]  (* = [1; 4; 9; 16] *)
```

- `f : 'a -> 'b`.
- Input is `'a list`, output is `'b list`.
- Same length; possibly different element types.

:::

That is `map`. Nine lines, including the example. The original
`double_each` and `string_lengths` collapse into one-liners on top of
it:

```ocaml
let double_each    = map (fun x -> x * 2)
let string_lengths = map String.length
```

Each is a [*partial application*](M03-L03-currying.html#partial-application-the-payoff)
of `map`: we have supplied the function argument and left the list
argument unbound. The result of each partial application is a
function that, given a list of the right element type, returns the
transformed list. This is exactly the
[Abstraction Principle](M06-L01-functions-revisited.html#why-bother-the-abstraction-principle)
from Lecture 1, made concrete.

The OCaml standard library calls this function `List.map`. The
implementation is essentially what we just wrote. From now on, use
`List.map` rather than redefining it; the only reason we wrote it
ourselves is to see clearly what it does.

## The type signature is a contract

Look at the type signature carefully:

```
val map : ('a -> 'b) -> 'a list -> 'b list
```

It says four useful things at once.

:::slide

## Type and what it tells you

```ocaml
let rec map (f : 'a -> 'b) (xs : 'a list) : 'b list =
  match xs with
  | [] -> []
  | h :: t -> f h :: map f t
```

`('a -> 'b) -> 'a list -> 'b list`.

What the signature says:

- Takes a function from some type `'a` to some type `'b`.
- Takes a list of `'a`.
- Returns a list of `'b`.
- The two element types may differ (e.g. `int list -> string list`).
- Always *one-to-one*: no element dropped or duplicated.

:::

First, **input and output element types can differ.** Look at the
`'a` and `'b`: nothing forces them to be the same. So we can map
`int list` to `string list` with `string_of_int`:

```ocaml
let _ = List.map string_of_int [1; 2; 3]  (* = ["1"; "2"; "3"] *)
```

Second, **the function is polymorphic.** A single `List.map` works
for `int list -> int list`, `int list -> string list`, `string list
-> int list`, anything. The compiler infers the specific `'a` and
`'b` from the function and the list you pass in.

Third, **the result is a list.** The output is always a list, never
some other shape. `map` does not collapse a list to a number, or
sort it, or split it; it just transforms each element in place.

Fourth, **the result has the same length as the input.** The
implementation makes one output element per input element. No
duplications, no omissions. If you want a different length, you
want a different function: [`filter`](M06-L03-filter.html) (drops
elements), [`filter_map`](M06-L03-filter.html#filtermap-filter-and-transform-in-one-pass)
(drops and transforms), or [`fold_left`](M06-L04-fold.html#foldleft-the-other-direction)
(returns anything you want).

Reading types this carefully pays off. Once you internalise what a
type signature is telling you, you can predict the rough shape of a
function before reading its body. With higher-order functions, this
is most of the battle: the type signature does much of the
documenting work.

## Examples

```ocaml
let _ = List.map (fun x -> x * 2) [1; 2; 3]              (* = [2; 4; 6] *)
let _ = List.map string_of_int [1; 2; 3]                 (* = ["1"; "2"; "3"] *)
let _ = List.map String.length ["hello"; "world"; "!"]   (* = [5; 5; 1] *)
```

:::slide

## `map` in the standard library

```ocaml
let _ = List.map (fun x -> x * 2) [1; 2; 3]              (* = [2; 4; 6] *)
let _ = List.map string_of_int [1; 2; 3]                 (* = ["1"; "2"; "3"] *)
let _ = List.map String.length ["hello"; "world"; "!"]   (* = [5; 5; 1] *)
```

Each call transforms element-by-element with the given function.

:::

The first call doubles every element. The second uses the standard
library function `string_of_int` directly as the function argument:
because OCaml functions are first-class values, we pass the function
by name without writing a lambda. The third call uses `String.length`
similarly to turn a list of strings into a list of their lengths.

## Partial application + `map`

Combining the [operator-as-function trick](M06-L01-functions-revisited.html#operators-are-functions-too)
from Lecture 1 with `map` gives some of the most compact OCaml in
the standard library:

```ocaml
let _ = List.map ((+) 10) [1; 2; 3]   (* = [11; 12; 13] *)
let _ = List.map (( * ) 2) [1; 2; 3]  (* = [2; 4; 6] *)
```

:::slide

## Partial application + map

```ocaml
let _ = List.map ((+) 10) [1; 2; 3]   (* = [11; 12; 13] *)
let _ = List.map (( * ) 2) [1; 2; 3]  (* = [2; 4; 6] *)
```

- `(+) 10` is the function "add 10".
- `( * ) 2` is "multiply by 2".
- Both are partial applications of infix operators; no lambdas needed.
- You'll write `List.map ((+) k)` more often than
  `List.map (fun x -> x + k)`: less noise, intent clear.

:::

`(+) 10` is `(+)` (the addition function) applied to one of its two
arguments, leaving a function `int -> int` that adds 10. Pass that
function to `List.map`, and you get the list with 10 added to every
element. The whole expression has no anonymous functions in it, yet
it does the same work as `List.map (fun x -> x + 10) [1; 2; 3]`. The
shorter form takes a little getting used to but quickly becomes
natural to read.

You will see this idiom often. It is one of the small payoffs of a
language where operators are values and partial application is
free.

## `map` does not change the length

A property worth saying out loud:

:::slide

## `map` doesn't change the length

- `List.map f xs` has the **same length** as `xs`. Always.
- One input element produces exactly one output element.

When you want something else:

- Drop elements: `List.filter` (Lecture 3).
- Drop *and* transform: `List.filter_map`.
- Totally different shape: `List.fold_left` (Lecture 4).

`map` is for "transform each element in place".

:::

`map` is the right tool *only* when input length and output length
should match. If you find yourself reaching for `map` and then
filtering the result to discard some elements, the right tool was
probably [`filter_map`](M06-L03-filter.html#filtermap-filter-and-transform-in-one-pass)
(Lecture 3); if you want to collapse the list to a single value, the
right tool is [`fold`](M06-L04-fold.html) (Lecture 4). Picking the
right tool is half the job; this is the easy bit.

## Tail recursion and `List.map`

Our `map` from earlier is not tail-recursive:

```ocaml
let rec map f = function
  | [] -> []
  | h :: t -> f h :: map f t
```

The recursive call `map f t` is not the *last* thing the function
does. After it returns, we still have to cons `f h` onto its result.
So the call sits in the call stack waiting for the recursion to
return, just like the naive recursive `sum` we saw in
[Module 3](M03-L04-tail-recursion.html#what-a-stack-overflow-looks-like).

:::slide

## Tail recursion and `List.map`

The naive definition we wrote is *not* tail-recursive:

```ocaml
let rec map f = function
  | [] -> []
  | h :: t -> f h :: map f t
```

- `f h :: map f t` does work *after* the recursive call (the cons).
- Hand-written like this, very long lists overflow the stack.
- Stdlib `List.map` is stack-safe on modern OCaml (5.1+):
  - the compiler turns cons-onto-recursive-call into a loop
    (tail recursion modulo cons, TMC).
- On older OCaml, the workaround was `List.rev (List.rev_map f xs)`.

:::

For lists of a few thousand elements this is fine: OCaml's default
stack size is generous. For lists of millions of elements, the naive
version eventually overflows.

You might think the obvious fix is to introduce an accumulator and
recurse tail-fashion:

```ocaml
let rec map_bad f acc = function
  | [] -> acc
  | h :: t -> map_bad f (acc @ [f h]) t
```

This is tail-recursive, but it is awful. The expression `acc @ [f h]`
is a list append, which walks the entire `acc` to find its end. So
each recursive step does linear work, and there are `n` steps:
total `O(n^2)`. What was a linear-time function is now quadratic.
Tail-recursive, sure, but at a brutal cost.

The cleaner fix is to *cons onto the accumulator* (which is constant
time), accepting that the accumulator will end up reversed, and
reverse it at the end:

```ocaml
let map f xs =
  let rec go acc = function
    | [] -> List.rev acc
    | x :: rest -> go (f x :: acc) rest
  in
  go [] xs
```

Two passes through the list (the fold-style traversal, then the
reverse), but each pass is linear and tail-recursive. Total: still
`O(n)` time, `O(1)` stack.

:::slide

## A tail-recursive `map`

```ocaml
let map f xs =
  let rec go acc = function
    | [] -> List.rev acc
    | x :: rest -> go (f x :: acc) rest
  in
  go [] xs

let _ = map (fun x -> x * x) [1; 2; 3; 4]   (* = [1; 4; 9; 16] *)
```

- Accumulate in reverse, then reverse at the end.
- Two passes through the list, constant stack.

:::

Where does `List.rev` come from? It is itself a small
tail-recursive function with the same accumulator-and-cons shape
as our tail-recursive `map`:

```ocaml
let rev xs =
  let rec go acc = function
    | [] -> acc
    | x :: rest -> go (x :: acc) rest
  in
  go [] xs

let _ = rev [1; 2; 3]  (* = [3; 2; 1] *)
```

No magic: walk the list left to right, cons each element onto
`acc` (so each element moves to the front of the accumulator),
return `acc` at the end. The same tail-recursion pattern we just
applied to `map`.

:::slide

## `rev` is not magic

```ocaml
let rev xs =
  let rec go acc = function
    | [] -> acc
    | x :: rest -> go (x :: acc) rest
  in
  go [] xs

let _ = rev [1; 2; 3]  (* = [3; 2; 1] *)
```

- Same accumulator-and-cons pattern as tail-recursive `map`.
- Cons onto `acc`: each element moves to the front.
- Walking left to right, accumulating right to left, reverses.
- `List.rev` is just this, in the standard library.

:::

What does the standard library do? On modern OCaml (5.1 and
later), `List.map` keeps the natural cons-onto-the-recursive-call
definition, but the compiler recognises that shape and turns it
into a loop; the technique is called *tail recursion modulo cons*
(TMC), and it makes `List.map` stack-safe even on very long lists.
On older OCaml, `List.map` really could overflow, and the standard
workaround was `List.rev (List.rev_map f xs)`: `List.rev_map` is
tail-recursive but builds the result reversed, so you reverse it
back, paying a second pass.

The bigger point is that *higher-order functions hide these
tradeoffs from the caller*. You write `List.map f xs` and stop
thinking about it; the library (and compiler) authors did the
worrying about stack safety once, so every caller benefits.

## `map` on options

`List.map` is the most familiar instance of a deeper pattern. *Any*
container-like type that "holds" elements can have its own `map`.

OCaml's [option type](M04-L04-recursive-types.html#the-option-type)
is the simplest example after lists. An `'a option` is either `None`
(no value) or `Some x` (a value of type `'a`). The standard library
provides `Option.map`:

```ocaml
let _ = Option.map (fun x -> x + 1) (Some 5)  (* = Some 6 *)
let _ = Option.map (fun x -> x + 1) None      (* = None *)
```

:::slide

## `map` on options

- `map` is a *pattern*, not just a list function.
- The idea generalises to anything that "contains" elements:

```ocaml
let _ = Option.map (fun x -> x + 1) (Some 5)  (* = Some 6 *)
let _ = Option.map (fun x -> x + 1) None      (* = None *)
```

- `Option.map` applies the function inside `Some`.
- It passes `None` through unchanged.

:::

The first call returns `Some 6`: the function is applied to the
contained value. The second returns `None`: there is no contained
value, so the function is not called and the `None` passes through.
This is exactly the same pattern as list `map`: walk the structure,
transform the elements, preserve the structure.

## `map` on trees

For your own data types, you can define `map` yourself. Here is a
[binary tree](M04-L04-recursive-types.html#a-binary-tree) with
values at internal nodes:

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec map_tree f = function
  | Leaf -> Leaf
  | Node (l, v, r) -> Node (map_tree f l, f v, map_tree f r)

let _ = map_tree (fun x -> x * 10)
                 (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)))
(* = Node (Node (Leaf, 10, Leaf), 20, Node (Leaf, 30, Leaf)) *)
```

:::slide

## `map` on trees

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec map_tree f = function
  | Leaf -> Leaf
  | Node (l, v, r) -> Node (map_tree f l, f v, map_tree f r)

let _ = map_tree (fun x -> x * 10)
                 (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)))
(* = Node (Node (Leaf, 10, Leaf), 20, Node (Leaf, 30, Leaf)) *)
```

- Same tree shape; every value multiplied by 10.
- Any "container of elements" type can have its own `map`.

:::

The result has the same shape as the input; only the values are
transformed. We will return to this generalisation in
[Module 7](M07-L08-functors.html) when we look at how libraries like
`Map` and `Set` package these patterns into reusable abstractions.

## Worked example: producing nicely-formatted strings

```ocaml
type person = { name : string; age : int }

let people = [
  { name = "Ada";    age = 36 };
  { name = "Linus";  age = 54 };
  { name = "Grace";  age = 85 };
]

let names = List.map (fun p -> p.name) people  (* = ["Ada"; "Linus"; "Grace"] *)

let descriptions =
  List.map (fun p -> p.name ^ " is " ^ string_of_int p.age) people
(* descriptions = ["Ada is 36"; "Linus is 54"; "Grace is 85"] *)
```

The first `map` is *projection*: pull a field out of every record.
This is so common that some libraries (Jane Street's `Core`, for
instance) define a shorthand. The second `map` is *transformation*:
combine fields of each record into a derived string. Both are the
same `map`; only the per-element function differs.

## A quick check

:::quiz mcq id=M06-L02-q3
What is the result of `List.map String.length ["hi"; "hello"; ""]`?

- [ ] `["2"; "5"; "0"]`
- [x] `[2; 5; 0]`
- [ ] `[2; 5]`
- [ ] `3`

**Why:** `String.length` takes a string and returns an `int`. So
this is mapping `string list` to `int list`. The empty string has
length `0`, so it is not dropped (that would be filtering).
`List.map` always preserves length.
:::

:::quiz mcq id=M06-L02-q2
What is the type of `List.map fst`?

- [ ] `('a * 'b) -> 'a`
- [x] `('a * 'b) list -> 'a list`
- [ ] `('a -> 'b) -> 'a list -> 'b list`
- [ ] `'a list * 'b list -> 'a list`

**Why:** `fst : 'a * 'b -> 'a` extracts the first component of a
pair. Partially applying `List.map` to `fst` gives a function
`('a * 'b) list -> 'a list`. So `List.map fst [(1,"a"); (2,"b")]`
returns `[1; 2]`.
:::

Now a code challenge:

:::quiz code id=M06-L02-q1
`map` walks a list of values and applies one function to each.
Flip the roles: write
`apply_all : ('a -> 'b) list -> 'a -> 'b list` that walks a list
of *functions* and applies each one to a single value `x`,
collecting the results in order. So
`apply_all [f; g; h] x = [f x; g x; h x]`.

```ocaml
let rec apply_all fs x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (apply_all [(fun x -> x + 1); (fun x -> x * 2); (fun x -> x * x)] 10
         = [11; 20; 100]) "three functions";
  check (apply_all [String.length] "hello" = [5]) "one function";
  check (apply_all [] 3 = []) "no functions";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let apply_all fs x = List.map (fun f -> f x) fs
```

No new recursion needed: the list holds functions, and the
per-element transformation is "apply it to `x`". Functions are
values, so a list of functions is as ordinary a `map` input as a
list of ints. Writing the walk by hand gives the same function:

```ocaml
let rec apply_all fs x =
  match fs with
  | [] -> []
  | f :: rest -> f x :: apply_all rest x
```

:::

## Activity

:::slide

## Activity

Write `zip_with : ('a -> 'b -> 'c) -> 'a list -> 'b list -> 'c list`
that pairs up two lists element-wise using the given function. Stop
when the shorter list runs out.

:::

:::solution

:::slide

## Activity solution

```ocaml
let rec zip_with f xs ys =
  match xs, ys with
  | [], _ | _, [] -> []
  | x :: xr, y :: yr -> f x y :: zip_with f xr yr

let _ = zip_with (+) [1; 2; 3] [10; 20; 30]                       (* = [11; 22; 33] *)
let _ = zip_with (fun a b -> a ^ b) ["he"; "wo"] ["llo"; "rld"]   (* = ["hello"; "world"] *)
let _ = zip_with (+) [1; 2; 3] [10; 20]                           (* = [11; 22] *)
```

- `[], _ | _, []` is an or-pattern catching either list empty.
- When either runs out, we stop.
- Third call: extra element of the longer list is dropped.

:::

:::

## What's next

`map` transforms but never drops. The next lecture is
[`filter`](M06-L03-filter.html): the higher-order function for
*dropping* elements based on a predicate.

:::slide

## What's next

Lecture 3: **`filter`**.

- Keep only the elements that match a predicate.
- The second of the three canonical higher-order list operations
  (`map`, `filter`, `fold`).

:::

## Reading

- **Cornell CS3110**, *Map*:
  <https://cs3110.github.io/textbook/chapters/hop/map.html>
- **Real World OCaml**, *Lists and patterns*:
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
