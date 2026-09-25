---
title: "`fold`: reduce a list to a single value"
lecture_no: 4
week: 6
youtube_id: RAcYi2gYfAs
duration_target_min: 25
concepts: [fold, fold_left, fold_right, reduction, accumulator, generalization]
keywords: [OCaml, fold, fold_left, fold_right, reduce, accumulator]
activity_question: "Express two functions using only [List.fold_left]: [count_evens : int list -> int] counts the even integers in the input list; [max_of_default : int list -> int -> int] returns the maximum element of the list, or the default if the list is empty."
think_about_this: "[fold_left] is tail-recursive and goes left-to-right; [fold_right] is not tail-recursive and goes right-to-left. When is each one the natural fit?"
reading:
  - title: "Cornell CS3110, Fold"
    url: https://cs3110.github.io/textbook/chapters/hop/fold.html
---

# `fold`: reduce a list to a single value


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">`fold`: reduce a list to a single value</h2>
<p class="title-slide-label">Module 6 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[`map`](M06-L02-map.html) returns a list.
[`filter`](M06-L03-filter.html) returns a list. `fold` returns
*anything*: a number, a string, a record, another list, a tree. If
the answer to your problem is computed by walking the elements of a
list and combining them somehow, `fold` is the tool. It is the most
general of the three canonical higher-order list functions, and it
subsumes both `map` and `filter`: as we will see by the end of the
lecture, you can write both of them on top of `fold`.

This lecture follows the same shape as the previous two: start from
two concrete recursive functions that share a pattern, abstract the
pattern, name the abstraction, then study the two flavours that
arise (`fold_left` and `fold_right`). At the end we look at folds
beyond lists.

:::slide

## This lecture: `fold`

- `map` returns a list. `filter` returns a list. `fold` returns *anything*.
- A number, a string, a record, another list, a tree.
- The most general of the three: subsumes both `map` and `filter`.
- Same shape as before: two concrete functions, abstract the pattern, name it.
- Two flavours: `fold_left` and `fold_right`.
- At the end: folds beyond lists.

:::

## From `sum` and `all_true` to `fold`

Two functions:

```ocaml
let rec sum = function
  | [] -> 0
  | h :: t -> h + sum t

let rec all_true = function
  | [] -> true
  | h :: t -> h && all_true t

let _ = sum [1; 2; 3]                       (* = 6 *)
let _ = all_true [true; true; false]        (* = false *)
```

Same shape, two differences:

- The base case returns a different value: `0` for `sum`, `true`
  for `all_true`.
- The combining step uses a different operator: `+` for `sum`, `&&`
  for `all_true`.

Both differences need to be parameterised. The base case becomes an
argument we will call `init` (the initial accumulator); the operator
becomes a function we will call `f`. Putting them together:

```ocaml
let rec reduce f init = function
  | [] -> init
  | h :: t -> f h (reduce f init t)

let sum      = reduce (+)  0
let all_true = reduce (&&) true
```

:::slide

## Two functions, the same shape

```ocaml
let rec sum = function
  | [] -> 0
  | h :: t -> h + sum t

let rec all_true = function
  | [] -> true
  | h :: t -> h && all_true t
```

- Same recursion skeleton; two things differ.
- Base case: `0` for `sum`, `true` for `all_true`.
- Combining step: `+` for `sum`, `&&` for `all_true`.

:::

:::slide

## Factor both out: `reduce`

```ocaml
let rec reduce f init = function
  | [] -> init
  | h :: t -> f h (reduce f init t)

let sum      = reduce (+)  0
let all_true = reduce (&&) true
```

- One generic function captures the shape.
- Two parameters: the combining function `f`, the initial value `init`.
- `sum` and `all_true` collapse to one-liners on top of `reduce`.

:::

That little function `reduce` is, with a tiny renaming, the
standard library function `List.fold_right`. The renaming: people
conventionally write `acc` instead of `init` for the accumulator
argument, and put the list before the accumulator. So:

```ocaml
let rec fold_right f xs acc =
  match xs with
  | [] -> acc
  | h :: t -> f h (fold_right f t acc)

let _ = fold_right (+) [1; 2; 3] 0          (* = 6 *)
let _ = fold_right (^) ["a"; "b"; "c"] ""   (* = "abc" *)
```

That is the actual signature of `List.fold_right`. Read the type:

```
val fold_right : ('a -> 'acc -> 'acc) -> 'a list -> 'acc -> 'acc
```

`f` takes an element and an accumulator, produces a new accumulator.
The function takes a list of `'a`, an initial accumulator of type
`'acc`, and returns the final accumulator.

:::slide

## `fold_right` definition

```ocaml
let rec fold_right f xs acc =
  match xs with
  | [] -> acc
  | h :: t -> f h (fold_right f t acc)

let _ = fold_right (+) [1; 2; 3] 0          (* = 6 *)
let _ = fold_right (^) ["a"; "b"; "c"] ""   (* = "abc" *)
```

- Type: `('a -> 'acc -> 'acc) -> 'a list -> 'acc -> 'acc`.
- `f` takes an *element first*, then the accumulator.
- The accumulator goes on the right; that's the "right" in the name.

:::

## What `fold_right` computes

The name "fold right" comes from how the operator gets associated.
For `fold_right f [a; b; c] init`, the computation unfolds as:

```
f a (f b (f c init))
```

That is, the rightmost element is combined first with the initial
accumulator, then that result with the next element, and so on
inward. The parentheses associate to the right. (The recursion
walks the list left-to-right to *reach* the empty tail, but the
arithmetic happens on the way back, rightmost element first.)

A useful way to picture this: a list value is a chain of cons
cells terminated by `[]`. The fold *replaces every cell in that
chain*: each `::` becomes a call to `f`, and the terminal `[]`
becomes `init`. A four-element list `[x1; x2; x3; x4]` is built
by the chain `x1 :: x2 :: x3 :: x4 :: []`, and folding right with
`(+)` and `0` produces `x1 + x2 + x3 + x4 + 0`. The fold reuses
the list's own structure as the skeleton of the computation.

That is also why this signature is so general: it lets you replace
the list's "structure" with any operator and any initial value you
like. Pick `+` and `0`: you get a sum. Pick `^` and `""`: you get a
concatenation. Pick `::` and `[]`: you get back the original list
(because we are replacing `::` with itself and `[]` with itself).
Pick `(fun x acc -> 1 + acc)` and `0`: you get the length. Pick
`(fun x acc -> f x :: acc)` and `[]` for some function `f`: you get
`map`. Pick `(fun x acc -> if p x then x :: acc else acc)` and `[]`:
you get `filter`. Folds are very general.

:::slide

## What `fold_right` does, step by step

`fold_right f [x1; x2; x3] acc` evaluates to:

```
f x1 (f x2 (f x3 acc))
```

- Rightmost element combined first with `acc`.
- Then leftward, one element at a time.
- Parentheses associate to the right (hence "fold_right").
- Recursion walks left-to-right to *reach* `[]`; the work
  happens on the way back, rightmost first.

For `fold_right (+) [1; 2; 3] 0`:

```
1 + (2 + (3 + 0))
= 1 + (2 + 3)
= 1 + 5
= 6
```

:::

:::slide

## `fold_right` as a tree

:::cols
:::col 45%

The list `[1; 2; 3; 4; 5]`:

<img src="assets/m06/figures/list_shape.svg" alt="list shape" style="max-width: 100%; height: auto;">

:::
:::col 55%

After `fold_right f xs z`:

<img src="assets/m06/figures/fold_right.svg" alt="fold_right tree" style="max-width: 100%; height: auto;">

:::
:::

- Every `::` becomes a call to `f`.
- The terminal `[]` becomes `z` (the initial accumulator).
- *Right-leaning* tree: each `f` nests into the second argument.

:::

:::slide

## `fold_right` replaces every cons cell

A list is a chain of cons cells terminated by `[]`:

```
[x1; x2; x3; x4]  ===  x1 :: x2 :: x3 :: x4 :: []
```

`fold_right f xs init` replaces:

- every `::` with `f`
- the terminal `[]` with `init`

Folding right with `(+)` and `0`:

```
x1 + x2 + x3 + x4 + 0
```

That's the whole engine. Pick `f` and `init`, get an operation:

- `(+)` and `0` -> sum.
- `(^)` and `""` -> concatenation.
- `(::)` and `[]` -> the list itself (identity).
- `(fun _ acc -> 1 + acc)` and `0` -> length.
- `(fun x acc -> f x :: acc)` and `[]` -> `map`.
- `(fun x acc -> if p x then x :: acc else acc)` and `[]` -> `filter`.

:::

## `fold_left`: the other direction

There is a second flavour of fold, called `fold_left`, that combines
elements from the *left* instead of the *right*. Where `fold_right`
parenthesises rightward (`f a (f b (f c init))`), `fold_left`
parenthesises leftward (`f (f (f init a) b) c`).

```ocaml
let rec fold_left f acc = function
  | [] -> acc
  | x :: rest -> fold_left f (f acc x) rest

let _ = fold_left (+) 0 [1; 2; 3; 4]        (* = 10 *)
```

:::slide

## `fold_left` definition

```ocaml
let rec fold_left f acc = function
  | [] -> acc
  | x :: rest -> fold_left f (f acc x) rest

let _ = fold_left (+) 0 [1; 2; 3; 4]  (* = 10 *)
```

- Type: `('acc -> 'a -> 'acc) -> 'acc -> 'a list -> 'acc`.
- The function combines the running accumulator with the next
  element to produce the new accumulator.
- Note: accumulator comes *first* in the function; element second.

:::

There are two differences from `fold_right`:

1. **The argument order of the combining function is swapped.** In
   `fold_right`, `f` takes `element` then `accumulator`. In
   `fold_left`, `f` takes `accumulator` then `element`. Mnemonic:
   the accumulator goes on the side suggested by the name. `fold_X`
   has accumulator on the `X`.

2. **The list argument is in a different position.** In `fold_right`
   you write `fold_right f xs init`; in `fold_left` you write
   `fold_left f init xs`. The accumulator comes before the list. This
   is a small inconsistency in the standard library, but it has been
   the convention since the early days of OCaml.

A side-by-side reminder, because the order trips up almost everyone
the first ten times:

| | combining function `f` | call shape |
|---|---|---|
| `fold_right` | `'a -> 'acc -> 'acc` (element, acc) | `fold_right f xs init` |
| `fold_left`  | `'acc -> 'a -> 'acc` (acc, element) | `fold_left f init xs`  |

Mnemonic: in `fold_X`, the accumulator sits on the `X` side, both
inside `f` and in the call.

## What `fold_left` computes, step by step

For `fold_left f acc [x1; x2; x3]`, the computation is:

```
f (f (f acc x1) x2) x3
```

Read inside-out: apply `f` to the initial `acc` and `x1`; take that
result and apply `f` to it and `x2`; take *that* result and apply
`f` to it and `x3`. The accumulator threads through, getting
updated by each element in turn.

:::slide

## What `fold_left` does, step by step

`fold_left f acc [x1; x2; x3]` evaluates to:

```
f (f (f acc x1) x2) x3
```

- `f` applied first to `acc` and `x1`.
- Then to that result and `x2`.
- Then to that result and `x3`.
- Each intermediate result becomes the new accumulator.

For `fold_left (+) 0 [1; 2; 3]`:

```
((0 + 1) + 2) + 3
= (1 + 2) + 3
= 3 + 3
= 6
```

:::

:::slide

## `fold_left` nests the other way

:::cols
:::col 45%

The list `[1; 2; 3; 4; 5]`:

<img src="assets/m06/figures/list_shape.svg" alt="list shape" style="max-width: 100%; height: auto;">

:::
:::col 55%

After `fold_left (+) 0 xs`:

<img src="assets/m06/figures/sum_fold.svg" alt="fold_left sum tree" style="max-width: 100%; height: auto;">

:::
:::

- Traversal is still **left to right**: `1` is consumed first.
- What differs from `fold_right` is how the *expression tree* nests:
  - the *last* element (`5`) sits at the outermost `f`;
  - the accumulator (`0`) sits at the deepest position.
- Elements appear top-to-bottom as `5, 4, 3, 2, 1, 0`:
  - that is nesting order, not visiting order.
- For `(+)` (associative + commutative) both folds agree.
  - The picture works as a stylised view of either fold's sum.
- Tail-recursive (next slide): each `+` finishes before the next
  call starts.

:::

For `fold_left (+) 0 [1; 2; 3]`, the unfolding is `((0 + 1) + 2) +
3`, which is `6`. For addition, this gives the same answer as
`fold_right`: both produce `6`. That is because `+` is *associative*
(the same result regardless of how you parenthesise) and the initial
accumulator `0` is the *identity* (adding `0` does not change the
result).

For a non-associative operator, the two folds disagree. Subtraction
is the textbook example:

```ocaml
let _ = List.fold_right (-) [10; 3; 1] 0     (* 10 - (3 - (1 - 0)) = 8 *)
let _ = List.fold_left  (-) 0 [10; 3; 1]     (* ((0 - 10) - 3) - 1 = -14 *)
```

Same list, same operator, different answers. When this happens, you
have to pick the fold direction that matches the meaning you want.

## `fold_left` is tail-recursive

The other big difference between `fold_left` and `fold_right` is
where the recursive call sits.

```ocaml
let rec fold_left f acc = function
  | [] -> acc
  | x :: rest -> fold_left f (f acc x) rest
```

The recursive call to `fold_left` is in the tail position: nothing
happens after it returns. OCaml will compile this to a loop. The
function uses constant stack space regardless of list length: you
can fold a list of millions of elements without trouble.

:::slide

## `fold_left` is tail-recursive

```ocaml
let rec fold_left f acc = function
  | [] -> acc
  | x :: rest -> fold_left f (f acc x) rest
```

- Recursive call is the *last* thing the function does.
- OCaml compiles it to a loop.
- Constant stack space, regardless of list length.
- Right choice when order doesn't matter, or when the accumulator
  naturally fits left-to-right folding.

:::

Contrast with `fold_right`:

```ocaml
let rec fold_right f xs acc =
  match xs with
  | [] -> acc
  | h :: t -> f h (fold_right f t acc)
```

The recursive call is *inside* `f h (...)`: after it returns, we
still have to apply `f` to its result and `h`. So the recursive call
is not in [tail position](M03-L04-tail-recursion.html#what-is-a-tail-call);
each pending call lives on the stack until its callee returns. For a
list of `n` elements, `fold_right` builds a stack of depth `n`. For
lists in the millions, this overflows.

:::slide

## `fold_right` is *not* tail-recursive

```ocaml
let rec fold_right f xs acc =
  match xs with
  | [] -> acc
  | h :: t -> f h (fold_right f t acc)
```

- `f h (...)` does work *after* the recursive call.
- Not tail-recursive: stack-overflow risk on long lists.
- For very long lists, prefer `fold_left` with an accumulator tweak.
- Or use `List.rev (List.fold_left ...)` for right-to-left semantics
  on long lists.

:::

So when do you reach for which?

- For tail-recursion and constant stack, use `fold_left`.
- When the natural order is right-to-left (because the operation is
  not associative, and the right grouping matches your meaning), use
  `fold_right`. If the list is short, do not worry. If the list is
  very long, use `List.rev` and switch to `fold_left`.
- A useful identity: `fold_right f xs init = fold_left (fun acc x ->
  f x acc) init (List.rev xs)`. The standard library's `fold_right`
  stays plainly recursive, but third-party libraries (Containers,
  Base) use this rev-then-`fold_left` trick for stack-safe right
  folds, and you can apply it yourself when the list is long.

In day-to-day OCaml, `fold_left` is by far the more common choice.

## Implementing `map` and `filter` via fold

We claimed `map` and `filter` can be expressed in terms of fold. The
proofs are short.

For `map`:

```ocaml
let map_via_fold f xs =
  List.fold_right (fun x acc -> f x :: acc) xs []

let _ = map_via_fold (fun n -> n * n) [1; 2; 3]  (* = [1; 4; 9] *)
```

:::slide

## `map` in terms of `fold_right`

```ocaml
let map_via_fold f xs =
  List.fold_right (fun x acc -> f x :: acc) xs []

let _ = map_via_fold (fun n -> n * n) [1; 2; 3]  (* = [1; 4; 9] *)
```

- Accumulator starts as `[]`.
- For each element (right-to-left) we cons `f x` onto it.
- The output order matches the input order: the rightmost cons
  happens first, so the leftmost element ends up at the front.
- One pass, but not tail-recursive (`fold_right` isn't).

:::

:::slide

## Tail-recursive variant: `fold_left` + `rev`

```ocaml
let map_via_fold_left f xs =
  List.rev (List.fold_left (fun acc x -> f x :: acc) [] xs)

let _ = map_via_fold_left (fun n -> n * n) [1; 2; 3]  (* = [1; 4; 9] *)
```

- `fold_left` walks left-to-right and cons-prepends each result,
  so the accumulator ends up *reversed*.
- A final `List.rev` puts it back in order.
- Two passes, but each is tail-recursive: constant stack.
- Same trick as the tail-recursive `map` from [Lecture 2](M06-L02-map.html).

:::

The combining function `(fun x acc -> f x :: acc)` says: at each
step, apply `f` to the current element and cons the result onto the
accumulator. With `fold_right`, the walk goes right-to-left, so the
cons-order matches the original order of the list and we get the
mapped list out.

For `filter`:

```ocaml
let filter_via_fold p xs =
  List.fold_right
    (fun x acc -> if p x then x :: acc else acc)
    xs []

let _ = filter_via_fold (fun n -> n > 2) [1; 2; 3; 4]  (* = [3; 4] *)
```

:::slide

## `filter` in terms of `fold`

```ocaml
let filter_via_fold p xs =
  List.fold_right
    (fun x acc -> if p x then x :: acc else acc)
    xs []

let _ = filter_via_fold (fun n -> n > 2) [1; 2; 3; 4]  (* = [3; 4] *)
```

- The combining function decides whether to include each element.
- `fold` is more general than `map` or `filter`.
- Both can be expressed in terms of it.

:::

The combining function picks either `x :: acc` (keep) or `acc`
(drop). Same general idea: walk the list, build the accumulator,
hand it back at the end.

`fold` is more general than both `map` and `filter`. If you ever
forget the signature of either, you can derive it from `fold`. (We
will not recommend you write `map_via_fold` instead of `map` in real
code: the more specific functions express intent more clearly. But
knowing they are all the same machinery is part of understanding the
toolbox.)

## Beyond lists: fold any structure

Fold scales further than it looks. When Google needed ordinary
engineers to process web-scale data across thousands of machines,
the abstraction they reached for was
[MapReduce](https://research.google/pubs/mapreduce-simplified-data-processing-on-large-clusters/)
(2004), named outright after `map` and `reduce` (`reduce` being
`fold`): map a function over the shards, then fold the partial
results into one answer. The two combinators on this page are
the same two that, scaled out, indexed the web. The reason it
works is that a `fold` says only *how to combine*, not *in what
order* the machine must walk the data.

Fold also generalises to anything recursive.
[Trees](M04-L04-recursive-types.html#a-binary-tree) are the
next-most-common example:

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec fold_tree f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_tree f acc l in
      let acc = f acc v in
      fold_tree f acc r

let _ = fold_tree (+) 0
          (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)))  (* = 6 *)
```

:::slide

## Beyond lists: fold any structure

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec fold_tree f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_tree f acc l in
      let acc = f acc v in
      fold_tree f acc r

let _ = fold_tree (+) 0
          (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)))  (* = 6 *)
```

- An in-order tree fold.
- Accumulator visits left subtree, then root, then right subtree.
- Once internalized, fold applies to any shape: trees, expressions,
  records-of-lists.

:::

For a `Leaf`, return the accumulator unchanged. For a `Node (l, v,
r)`, fold the left subtree first, then combine with the value at the
node, then fold the right subtree. The result is an *in-order* fold:
left subtree, root, right subtree.

The general technique: for any recursive data type, write a fold
that takes one function argument per constructor (or per place the
type recursively occurs), and at each constructor pass the appropriate
combining function. This pattern generalises beyond trees to any
[algebraic data type](M04-L04-recursive-types.html), and it is the
entry point to the abstract idea of a *catamorphism* (a fancy name
for "generalised fold") that appears in category theory. We will see
more of it in [Module 8](M08-L01-option-monad.html).

## When `fold` is overkill

A non-trivial fold can be harder to read than the equivalent
`map`/`filter` chain, because the reader has to decode the
accumulator threading. The rule of thumb:

:::slide

## When `fold` is overkill

- Prefer `map` or `filter` when you can: they read better and
  signal intent more clearly.
- Reach for `fold` when the answer isn't a list (a number, a
  record, a `Map`).
- Or when you need both summary and transformation in one pass.

```ocaml
(* Both produce the same answer *)
let sum_squares_a xs = xs |> List.map (fun x -> x * x) |> List.fold_left (+) 0
let sum_squares_b xs = List.fold_left (fun acc x -> acc + x * x) 0 xs

let _ = sum_squares_a [1; 2; 3]  (* = 14 *)
let _ = sum_squares_b [1; 2; 3]  (* = 14 *)
```

- First: pipeline (map, then sum).
- Second: one fold.
- First is clearer for small steps; second is more efficient (one pass).

:::

`sum_squares_a` first squares each element with `map`, then folds
with `+`. It builds an intermediate list of squares. `sum_squares_b`
does the squaring and accumulation in a single fold, never allocating
the intermediate list. Both produce `14`.

For small inputs, prefer the clearer pipeline. For very long inputs
or hot loops, the single-fold version may be measurably faster.
Profile before "optimising" by fusing operations; readability is
worth more than constant factors in most code.

## A short subtlety: `fold_left` arguments and direction

A common confusion: people remember "fold_left = tail-recursive" and
then are surprised when `fold_left` produces a *reversed* result
where they wanted the original order.

```ocaml
let _ = List.fold_left (fun acc x -> x :: acc) [] [1; 2; 3]  (* = [3; 2; 1] *)
```

It returns `[3; 2; 1]`, not `[1; 2; 3]`.

Why? `fold_left` walks left to right. At each step, we cons the
current element onto the accumulator. After the first element, `acc
= [1]`. After the second, `acc = [2; 1]` (we prepended `2`). After
the third, `acc = [3; 2; 1]`. So the first element ends up
*deepest*, and the result is reversed.

This is the same machinery as `List.rev`, and indeed:

```ocaml
let rev xs = List.fold_left (fun acc x -> x :: acc) [] xs
```

is a standard one-line definition of `rev`. If you want the original
order, either fold right (`List.fold_right (fun x acc -> x :: acc)
xs []`, which gets `[1; 2; 3]`) or `fold_left` then `List.rev`.

:::slide

## Subtlety: `fold_left` and order

```ocaml
let _ = List.fold_left (fun acc x -> x :: acc) [] [1; 2; 3]
  (* = [3; 2; 1], not [1; 2; 3] *)
```

Trace step by step:

- start: `acc = []`
- after `1`: `acc = [1]` (prepended)
- after `2`: `acc = [2; 1]`
- after `3`: `acc = [3; 2; 1]`

- First element ends up *deepest*, so the result is reversed.
- This is exactly the stdlib `List.rev`:
  ```ocaml
  let rev xs = List.fold_left (fun acc x -> x :: acc) [] xs
  ```
- To keep original order: use `fold_right`, or `fold_left` + `List.rev`.

:::

## A quick check

:::quiz mcq id=M06-L04-q3
What is `List.fold_left (+) 0 [1; 2; 3; 4]`?

- [ ] `0`
- [ ] `4`
- [x] `10`
- [ ] `24`

**Why:** `fold_left (+) 0 [1; 2; 3; 4]` evaluates to `(((0 + 1) +
2) + 3) + 4 = 10`. Initial accumulator `0`, then `+1, +2, +3, +4`.
:::

:::quiz mcq id=M06-L04-q2
Which of the following is *not* tail-recursive?

- [ ] `List.fold_left`
- [x] `List.fold_right`
- [ ] `List.length`
- [ ] `List.rev`

**Why:** `List.fold_right` has work to do after the recursive call:
applying `f` to the element and the recursive result. The other
three are tail-recursive in the standard library (`length` and `rev`
use `fold_left` or accumulator-based traversal internally).
:::

A code challenge:

:::quiz code id=M06-L04-q1
Express `List.length xs` using `List.fold_left`. Do not call
`List.length` itself, and do not use a `let rec`.

```ocaml
let my_length xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (my_length [] = 0)                "empty";
  check (my_length [42] = 1)              "singleton";
  check (my_length [1; 2; 3; 4] = 4)      "four ints";
  check (my_length ["a"; "b"; "c"] = 3)   "three strings";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let my_length xs = List.fold_left (fun n _ -> n + 1) 0 xs
```

We ignore each element (the `_`) and just bump the counter.
Tail-recursive, constant stack.

:::

## Activity

:::slide

## Activity

Express two functions using only `List.fold_left`:

- `count_evens : int list -> int` returns the number of even
  integers in the list.
- `max_of_default : int list -> int -> int` returns the maximum
  element of the list, or the default if the list is empty.

:::

:::solution

:::slide

## Activity solution

```ocaml
let count_evens xs =
  List.fold_left (fun n x -> if x mod 2 = 0 then n + 1 else n) 0 xs

let max_of_default xs d = List.fold_left max d xs

let _ = count_evens [1; 2; 3; 4; 5; 6]   (* = 3 *)
let _ = max_of_default [3; 7; 1; 5] 0    (* = 7 *)
let _ = max_of_default [] 0              (* = 0 *)
```

- `count_evens`: conditional counter; only bumps `n` when `x mod 2 = 0`.
- `max_of_default`: pass the stdlib `max` straight in; default as
  starting accumulator means the empty case is handled for free.
- Two different shapes, same `fold_left` machinery.

:::

:::

## What's next

We have the three big higher-order list functions: `map`, `filter`,
`fold`. Next lecture: the [pipeline operator `|>`](M06-L05-pipelines.html),
which lets us chain these together cleanly and read the result
top-to-bottom.

:::slide

## What's next

Lecture 5: **function composition and pipelines**.

- The plumbing that strings `map`, `filter`, `fold` together cleanly.
- Then the Module 6 tutorial.

:::

## Reading

- **Cornell CS3110**, *Fold*:
  <https://cs3110.github.io/textbook/chapters/hop/fold.html>
- **Real World OCaml**, *Lists and patterns*:
  <https://dev.realworldocaml.org/lists-and-patterns.html>
- Graham Hutton, *A tutorial on the universality and expressiveness
  of fold*: shows how general `fold` is. Optional.
  <https://www.cs.nott.ac.uk/~pszgmh/fold.pdf>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
