---
title: "Practice: pattern matching, by hand"
lecture_no: 7
week: 5
duration_target_min: 0
concepts: [practice problems, pattern matching, recursion, lists, trees, variants, options]
keywords: [OCaml, practice, assignment, pattern matching, match, recursion, lists, trees, variants, option]
think_about_this: "Every solution here is a `match` and a recursive call. Before you write a clause, ask: what are the shapes the value can take? An empty list and a cons; a leaf and a node; None and Some. One clause per shape, and the recursion handles the smaller pieces."
reading:
  - title: "Cornell CS3110, Pattern matching"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
---

# Practice: pattern matching, by hand

This is a *Practice* chapter, not a Tutorial. There are no slides
and there is no video; it is a worksheet. The
[tutorial](M05-L06-tutorial.html) walked through a worked example on
screen. Here you solve the problems yourself, directly in the
browser. Each problem has an editable cell seeded with
`failwith "not implemented"` and a test cell that prints
`all tests passed` when your solution is correct. A reference
solution sits below each problem behind a collapsed *Reference
solution* panel: try the problem first, then reveal the solution to
compare.

The rule for this worksheet: solve everything with `match` and
recursion *by hand*. The higher-order helpers (`map`, `filter`,
`fold`) come later; here the point is to see the recursion you are
hand-writing, one clause per shape of the data. If you find yourself
wanting `List.map`, stop and write the two list clauses instead.

The worksheet comes in three parts:

- **Part 1: lists** (Problems 1 to 7). Matching `[]` against
  `x :: xs`, carrying an index or a running answer, and one merge
  puzzle.
- **Part 2: binary trees** (Problems 8 to 10). The same `'a tree`
  you met in the [recursive-patterns lecture](M05-L02-recursive-patterns.html),
  matched on `Leaf` against `Node`.
- **Part 3: your own variants** (Problems 11 to 12). Define a small
  variant type and match on it, including matching on a pair of
  values at once.

Difficulty rises roughly as you go, but not strictly; if you get
stuck on one, skip ahead and come back.

## Part 1: lists

## Problem 1: `last`

Write a function

```text
last : 'a list -> 'a option
```

that returns the last element of a list as `Some x`, or `None` if
the list is empty. For example, `last [1; 2; 3] = Some 3`.

:::quiz code id=M05-L07-q1
Implement `last`.

```ocaml
let rec last l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (last [1; 2; 3] = Some 3) "three elements";
  check (last ([] : int list) = None) "empty";
  check (last [7] = Some 7) "single element";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec last l =
  match l with
  | [] -> None
  | [x] -> Some x
  | _ :: xs -> last xs
```

Three shapes: the empty list (no last element), a one-element list
(that element *is* the last), and a longer list (drop the head and
recurse). The `[x]` clause must come before the `_ :: xs` clause,
since a singleton also matches `_ :: xs`.

:::

## Problem 2: `nth`

Write a function

```text
nth : 'a list -> int -> 'a option
```

that returns `Some` of the element at position `n` (counting from
`0`), or `None` if `n` is out of range. For example,
`nth [10; 20; 30] 1 = Some 20` and `nth [10; 20; 30] 5 = None`.

:::quiz code id=M05-L07-q2
Implement `nth`.

```ocaml
let rec nth l n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (nth [10; 20; 30] 1 = Some 20) "middle";
  check (nth [10; 20; 30] 0 = Some 10) "first";
  check (nth [10; 20; 30] 5 = None) "out of range";
  check (nth ([] : int list) 0 = None) "empty";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec nth l n =
  match l with
  | [] -> None
  | x :: rest -> if n = 0 then Some x else nth rest (n - 1)
```

Walk down the list and the index together: when `n` reaches `0` the
head is the answer; otherwise drop the head and look for position
`n - 1` in the tail. Running off the end of the list (the `[]`
clause) means `n` was too big.

:::

## Problem 3: `count_occurrences`

Write a function

```text
count_occurrences : 'a -> 'a list -> int
```

that counts how many times a value appears in a list. For example,
`count_occurrences 2 [1; 2; 2; 3; 2] = 3`.

:::quiz code id=M05-L07-q3
Implement `count_occurrences`.

```ocaml
let rec count_occurrences x l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (count_occurrences 2 [1; 2; 2; 3; 2] = 3) "three twos";
  check (count_occurrences 9 [1; 2; 3] = 0) "absent";
  check (count_occurrences 1 ([] : int list) = 0) "empty";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec count_occurrences x l =
  match l with
  | [] -> 0
  | y :: ys ->
      (if x = y then 1 else 0) + count_occurrences x ys
```

The empty list contributes nothing. For a cons, add `1` when the
head equals `x` (and `0` otherwise), then recurse on the tail. The
comparison `x = y` is OCaml's structural equality, so this works for
any type whose values can be compared with `=`.

:::

## Problem 4: `take`

Write a function

```text
take : int -> 'a list -> 'a list
```

that returns the first `n` elements of a list (all of them if the
list is shorter than `n`, and `[]` if `n <= 0`). For example,
`take 2 [1; 2; 3; 4] = [1; 2]`.

:::quiz code id=M05-L07-q4
Implement `take`.

```ocaml
let rec take n l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 2 [1; 2; 3; 4] = [1; 2]) "first two";
  check (take 0 [1; 2] = []) "n = 0";
  check (take 9 [1; 2] = [1; 2]) "n past the end";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec take n l =
  match l with
  | [] -> []
  | _ when n <= 0 -> []
  | x :: rest -> x :: take (n - 1) rest
```

Two ways to stop: the list runs out (`[]`), or we have taken enough
(`n <= 0`, expressed as a guard). Otherwise keep the head and take
`n - 1` from the tail. The guarded clause sits before the
`x :: rest` clause so that `n <= 0` wins even on a non-empty list.

:::

## Problem 5: `drop`

Write the companion to `take`:

```text
drop : int -> 'a list -> 'a list
```

returning the list with its first `n` elements removed (the whole
list if `n <= 0`, and `[]` if `n` exceeds the length). For example,
`drop 2 [1; 2; 3; 4] = [3; 4]`.

:::quiz code id=M05-L07-q5
Implement `drop`.

```ocaml
let rec drop n l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (drop 2 [1; 2; 3; 4] = [3; 4]) "drop two";
  check (drop 0 [1; 2] = [1; 2]) "n = 0";
  check (drop 9 [1; 2] = []) "n past the end";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec drop n l =
  match l with
  | [] -> []
  | _ when n <= 0 -> l
  | _ :: rest -> drop (n - 1) rest
```

Mirror of `take`: when `n <= 0` we are done dropping and return the
list unchanged; otherwise discard the head and drop `n - 1` more.
Note the guarded clause returns `l` (the whole remaining list), not
`[]`.

:::

## Problem 6: `is_sorted`

Write a function

```text
is_sorted : int list -> bool
```

that returns `true` when a list is in non-decreasing order. The
empty list and any one-element list count as sorted. For example,
`is_sorted [1; 2; 2; 3] = true` and `is_sorted [3; 1] = false`.

:::quiz code id=M05-L07-q6
Implement `is_sorted`. You will want to look at the first *two*
elements at once.

```ocaml
let rec is_sorted l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (is_sorted [1; 2; 2; 3] = true) "non-decreasing";
  check (is_sorted [3; 1] = false) "out of order";
  check (is_sorted ([] : int list) = true) "empty";
  check (is_sorted [5] = true) "single";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec is_sorted l =
  match l with
  | [] | [_] -> true
  | x :: (y :: _ as rest) -> x <= y && is_sorted rest
```

An or-pattern handles the two "trivially sorted" shapes together:
`[]` and a singleton `[_]`. For a list with at least two elements,
name the head `x`, the second element `y`, and (with `as`) the whole
tail `rest`; the list is sorted when `x <= y` *and* the tail is
sorted. Binding the tail with `as` lets us recurse on it without
rebuilding `y :: ...`.

:::

## Problem 7: `merge`

Write a function

```text
merge : int list -> int list -> int list
```

that merges two already-sorted lists into one sorted list. For
example, `merge [1; 3; 5] [2; 4] = [1; 2; 3; 4; 5]`. (This is the
combining step of merge sort.)

:::quiz code id=M05-L07-q7
Implement `merge`. Assume both inputs are sorted.

```ocaml
let rec merge xs ys =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (merge [1; 3; 5] [2; 4] = [1; 2; 3; 4; 5]) "interleaved";
  check (merge [] [1; 2] = [1; 2]) "empty left";
  check (merge [1; 2] [] = [1; 2]) "empty right";
  check (merge [1; 1] [1] = [1; 1; 1]) "duplicates";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec merge xs ys =
  match xs, ys with
  | [], _ -> ys
  | _, [] -> xs
  | x :: xs', y :: ys' ->
      if x <= y then x :: merge xs' ys
      else y :: merge xs ys'
```

Match on the *pair* of lists. If either is empty, the answer is the
other. Otherwise compare the two heads: emit the smaller one and
recurse, advancing only the list it came from. Using `<=` (not `<`)
keeps equal elements in a stable order and handles duplicates.

:::

## Part 2: binary trees

For the next three problems we use the same binary tree from the
recursive-patterns lecture. Run the cell below first so the type and
a sample tree are in scope.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

(* a sample tree used by the tests below *)
let sample =
  Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 5, Node (Leaf, 3, Leaf)))
```

## Problem 8: `sum_tree`

Write a function

```text
sum_tree : int tree -> int
```

that adds up every value stored in the tree (`0` for an empty tree).
For `sample` above, `sum_tree sample = 11`.

:::quiz code id=M05-L07-q8
Implement `sum_tree`.

```ocaml
let rec sum_tree t =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sum_tree sample = 11) "sample sum";
  check (sum_tree (Leaf : int tree) = 0) "empty tree";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec sum_tree t =
  match t with
  | Leaf -> 0
  | Node (l, v, r) -> sum_tree l + v + sum_tree r
```

A `Leaf` holds nothing, so it sums to `0`. A `Node` contributes its
own value `v` plus the sums of both subtrees. The two recursive
calls mirror the two subtrees: this is the tree version of summing a
list.

:::

## Problem 9: `tree_max`

Write a function

```text
tree_max : int tree -> int option
```

that returns the largest value in the tree as `Some`, or `None` for
an empty tree. For `sample`, `tree_max sample = Some 5`.

:::quiz code id=M05-L07-q9
Implement `tree_max`. You will need to combine option results from
the two subtrees.

```ocaml
let rec tree_max t =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (tree_max sample = Some 5) "sample max";
  check (tree_max (Leaf : int tree) = None) "empty tree";
  check (tree_max (Node (Leaf, 42, Leaf)) = Some 42) "single node";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec tree_max t =
  match t with
  | Leaf -> None
  | Node (l, v, r) ->
      let best a b =
        match a, b with
        | None, o | o, None -> o
        | Some x, Some y -> Some (if x > y then x else y)
      in
      best (Some v) (best (tree_max l) (tree_max r))
```

A `Leaf` has no maximum (`None`). For a `Node`, the answer is the
largest of `v`, the left maximum, and the right maximum, each of
which is an `int option`. The local helper `best` merges two
options: if one is `None` the other wins (the or-pattern
`None, o | o, None`), and when both are `Some` it keeps the larger.

:::

## Problem 10: `tree_contains`

Write a function

```text
tree_contains : 'a -> 'a tree -> bool
```

that returns `true` when the value appears anywhere in the tree. For
`sample`, `tree_contains 5 sample = true` and `tree_contains 9
sample = false`.

:::quiz code id=M05-L07-q10
Implement `tree_contains`.

```ocaml
let rec tree_contains x t =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (tree_contains 5 sample = true) "present";
  check (tree_contains 9 sample = false) "absent";
  check (tree_contains 1 (Leaf : int tree) = false) "empty tree";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec tree_contains x t =
  match t with
  | Leaf -> false
  | Node (l, v, r) ->
      v = x || tree_contains x l || tree_contains x r
```

An empty tree contains nothing. A node contains `x` if its own value
matches, or if either subtree contains it. The `||` operator
short-circuits, so once the value is found the remaining subtrees are
not searched. (This is an *arbitrary* tree; it does not assume the
ordering of a search tree.)

:::

## Part 3: your own variants

## Problem 11: `beats`

Define a type for the three moves of rock-paper-scissors and a
function

```text
beats : move -> move -> bool
```

that returns `true` when the first move beats the second. Rock beats
scissors, scissors beats paper, and paper beats rock; anything else
(including a tie) is `false`.

:::quiz code id=M05-L07-q11
The type is given. Implement `beats` by matching on the *pair* of
moves.

```ocaml
type move = Rock | Paper | Scissors

let beats a b =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (beats Rock Scissors = true) "rock beats scissors";
  check (beats Scissors Paper = true) "scissors beats paper";
  check (beats Paper Rock = true) "paper beats rock";
  check (beats Rock Paper = false) "rock loses to paper";
  check (beats Rock Rock = false) "tie";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let beats a b =
  match a, b with
  | Rock, Scissors | Paper, Rock | Scissors, Paper -> true
  | _ -> false
```

Match on the pair `a, b`. An or-pattern lists the three winning
combinations on a single clause; the wildcard `_` catches every
other pair (losses and ties) and returns `false`. Without the three
winning pairs spelled out, you would need a clause per case; the
or-pattern keeps it to two clauses.

:::

## Problem 12: `nat` (the natural numbers)

Here is a type that builds the natural numbers from scratch: `Zero`,
and `Succ n` (the successor, "one more than `n`"). So `2` is
`Succ (Succ Zero)`. Implement two functions:

```text
to_int : nat -> int
add    : nat -> nat -> nat
```

`to_int` converts a `nat` to an ordinary `int`, and `add` adds two
naturals (returning a `nat`).

:::quiz code id=M05-L07-q12
The type is given. Implement `to_int` and `add` by matching on the
constructors.

```ocaml
type nat = Zero | Succ of nat

let rec to_int n =
  failwith "not implemented"

let rec add a b =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let two = Succ (Succ Zero)
let three = Succ (Succ (Succ Zero))
let () =
  check (to_int Zero = 0) "zero";
  check (to_int three = 3) "three";
  check (to_int (add two three) = 5) "two plus three";
  check (to_int (add Zero two) = 2) "zero plus two";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec to_int n =
  match n with
  | Zero -> 0
  | Succ m -> 1 + to_int m

let rec add a b =
  match a with
  | Zero -> b
  | Succ m -> Succ (add m b)
```

`to_int` peels one `Succ` at a time, adding `1` for each, until it
reaches `Zero`. `add` recurses on its *first* argument: adding `Zero`
to `b` gives `b`, and adding `Succ m` to `b` is one more than adding
`m` to `b`, i.e. `Succ (add m b)`. This is addition defined purely by
pattern matching on the structure of a number.

:::
