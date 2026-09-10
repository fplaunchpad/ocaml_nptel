---
title: "Practice: recursion, higher-order functions, and syntax trees"
lecture_no: 7
week: 6
duration_target_min: 0
concepts: [practice problems, list recursion, higher-order, tail recursion]
keywords: [OCaml, practice, assignment, list, recursion, fold, tail-recursion]
think_about_this: "These problems are deliberately a mix: some are short warm-ups, some are real puzzles. The order is roughly increasing in difficulty but not strictly. If you get stuck on one, skip ahead and come back."
reading:
  - title: "OCaml standard library, List"
    url: https://v2.ocaml.org/api/List.html
---

# Practice: recursion, higher-order functions, and syntax trees

This is a *Practice* chapter, not a Tutorial. There are no slides
and there is no video; it is a worksheet. The
[tutorial](M06-L06-tutorial.html) walked through worked examples
on screen. Here you solve the problems yourself, directly in the
browser. Each problem has an editable cell seeded with
`failwith "not implemented"` and a test cell that prints
`all tests passed` when your solution is correct. A reference
solution sits below each problem behind a collapsed *Reference
solution* panel: try the problem first, then reveal the solution to
compare.

The worksheet comes in two parts:

- **Part 1: list recursion and basics** (Problems 1 to 9). Pattern
  matching on lists and options, hand-written recursion, and tail
  recursion. Hand-rolling the recursion is the point here; reach for
  the standard library only where a problem says so.
- **Part 2: the higher-order toolkit** (Problems 10 to 15). The
  same problems you could solve with raw recursion, now done with
  `map`, `filter`, `fold`, `|>`, and composition. These follow on
  from the [pipelines lecture](M06-L05-pipelines.html) and the
  [fold-everywhere tutorial](M06-L06-tutorial.html).
- **Part 3: optimising a syntax tree** (Problems 16 to 17). Recursion
  over a custom algebraic data type: the little arithmetic
  expression AST you met in the [variants tutorial](M04-L05-tutorial.html)
  and the [interpreter tutorial](M05-L06-tutorial.html), this time
  rewritten to a *simpler equivalent tree* (constant folding and
  algebraic identities).

Nothing here needs anything from Module 7 or later. Difficulty
rises roughly as you go, but not strictly; if you get stuck on one,
skip ahead and come back.

## Part 1: list recursion and basics

## Problem 1: `cond_dup`

Write a function

```text
cond_dup : 'a list -> ('a -> bool) -> 'a list
```

that takes a list and a predicate, duplicating every element that
satisfies the predicate and leaving the rest unchanged. For example,

```text
cond_dup [3; 4; 5] (fun x -> x mod 2 = 1) = [3; 3; 4; 5; 5]
```

:::quiz code id=M06-L07-q1
Implement `cond_dup` so that the tests below pass.

```ocaml
let rec cond_dup l f =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (cond_dup [3; 4; 5] (fun x -> x mod 2 = 1) = [3; 3; 4; 5; 5])
        "odds duplicated";
  check (cond_dup [] (fun _ -> true) = ([] : int list))
        "empty";
  check (cond_dup [1; 2; 3] (fun _ -> false) = [1; 2; 3])
        "predicate always false";
  check (cond_dup [1; 2; 3] (fun _ -> true) = [1; 1; 2; 2; 3; 3])
        "predicate always true";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec cond_dup l f =
  match l with
  | [] -> []
  | x :: xs ->
      if f x then x :: x :: cond_dup xs f
      else x :: cond_dup xs f
```

The two list cases: empty list returns empty; a head element either
gets prepended twice (predicate holds) or once (predicate fails),
and we recurse on the tail. This is not tail-recursive, but for the
size of input this exercise expects, that does not matter.

:::

## Problem 2: `n_times`

Write a function

```text
n_times : ('a -> 'a) * int * 'a -> 'a
```

such that `n_times (f, n, v)` applies `f` to `v` exactly `n` times.
For example, `n_times ((fun x -> x + 1), 50, 0) = 50`. If `n <= 0`
return `v` unchanged.

The argument is a *tuple*, not three curried arguments. Most OCaml
code prefers currying, but a tuple is a fine shape too. If `n_times`
were curried (`n_times f n v`), you could partially apply it; with
a tuple you cannot. The signature here is deliberately the tupled
one.

:::quiz code id=M06-L07-q2
Implement `n_times`.

```ocaml
let rec n_times (f, n, v) =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (n_times ((fun x -> x + 1), 50, 0) = 50) "increment 50 times";
  check (n_times ((fun x -> x * 2), 4, 1) = 16) "double four times";
  check (n_times ((fun x -> x + 1), 0, 7) = 7) "n=0";
  check (n_times ((fun x -> x + 1), -3, 7) = 7) "n<0";
  check (n_times ((fun s -> s ^ "!"), 3, "go") = "go!!!") "string repeat";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec n_times (f, n, v) =
  if n <= 0 then v
  else n_times (f, n - 1, f v)
```

A standard accumulator-style recursion: the running value is `v`,
and at each step we apply `f` and decrement `n`. This recursion is
already tail-recursive (the recursive call is the last thing the
function does), so it will not blow the stack for large `n`.

:::

## Problem 3: `range`

Write a function

```text
range : int -> int -> int list
```

such that `range num1 num2` returns the ordered list of all integers
from `num1` to `num2` inclusive. For example, `range 2 5 = [2; 3; 4; 5]`
and `range 7 7 = [7]`. If `num2 < num1`, call `failwith "Incorrect range"`.

(`failwith` raises a generic failure exception; you have used it
since Module 1 as the placeholder body for unimplemented functions.
Exceptions are introduced properly in
[the exceptions lecture](M07-L03-exceptions.html); here we just use
`failwith` as a signal.)

:::quiz code id=M06-L07-q3
Implement `range`. The tests below check only the valid-range path;
the `failwith` behaviour is left for you to verify yourself.

```ocaml
let rec range num1 num2 =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (range 2 5 = [2; 3; 4; 5]) "small range";
  check (range 7 7 = [7]) "singleton";
  check (range 0 0 = [0]) "zero singleton";
  check (range (-2) 2 = [-2; -1; 0; 1; 2]) "across zero";
  check (List.length (range 1 100) = 100) "length 100";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec range num1 num2 =
  if num2 < num1 then failwith "Incorrect range"
  else if num1 = num2 then [num1]
  else num1 :: range (num1 + 1) num2
```

Three cases. The error case bails out. The singleton case (`num1 =
num2`) returns a one-element list. The recursive case prepends
`num1` and recurses on the rest of the range.

:::

## Problem 4: `unzip`

Write a function

```text
unzip : ('a * 'b) list -> 'a list * 'b list
```

that splits a list of pairs into a pair of lists, preserving order:
the first list holds every first component, the second list every
second component. For example,
`unzip [(1, 'a'); (2, 'b'); (3, 'c')] = ([1; 2; 3], ['a'; 'b'; 'c'])`.

The standard library calls this `List.split`; write it yourself
with direct recursion. (Hint: destructure the recursive call's
result with a `let (xs, ys) = ... in ...` pattern.)

:::quiz code id=M06-L07-q4
Implement `unzip`.

```ocaml
let rec unzip l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (unzip [(1, 'a'); (2, 'b'); (3, 'c')]
         = ([1; 2; 3], ['a'; 'b'; 'c'])) "three pairs";
  check (unzip ([] : (int * char) list) = ([], [])) "empty";
  check (unzip [(7, "x")] = ([7], ["x"])) "singleton";
  check (unzip [(true, 1); (false, 2)] = ([true; false], [1; 2]))
        "bools and ints";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec unzip = function
  | [] -> ([], [])
  | (a, b) :: rest ->
      let (xs, ys) = unzip rest in
      (a :: xs, b :: ys)
```

The base case returns a pair of empty lists. The cons case takes a
pair `(a, b)` off the front, unzips the rest, and conses `a` and
`b` onto their respective halves. Both output lists come out in the
input order because each component is prepended to an
already-ordered result.

:::

## Problem 5: `buckets`

Write a function

```text
buckets : ('a -> 'a -> bool) -> 'a list -> 'a list list
```

that partitions a list into equivalence classes. `buckets equiv lst`
returns a list of lists, where each sublist contains mutually
equivalent elements (the supplied `equiv` returns `true` between
them). For example,

```text
buckets (=) [1; 2; 3; 4] = [[1]; [2]; [3]; [4]]
buckets (=) [1; 2; 3; 4; 2; 3; 4; 3; 4]
  = [[1]; [2; 2]; [3; 3; 3]; [4; 4; 4]]
buckets (fun x y -> x mod 3 = y mod 3) [1; 2; 3; 4; 5; 6]
  = [[1; 4]; [2; 5]; [3; 6]]
```

The order of buckets in the output must reflect the order in which
the first element of each bucket appeared in the input. The order
of elements *within* a bucket must reflect the order in which they
appeared in the input.

Assume `equiv` is reflexive, symmetric, and transitive (a proper
equivalence relation). Just use lists; do not reach for sets or
hash tables.

:::quiz code id=M06-L07-q5
Implement `buckets`.

```ocaml
let buckets p l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (buckets (=) [1; 2; 3; 4] = [[1]; [2]; [3]; [4]])
        "all distinct";
  check (buckets (=) [1; 2; 3; 4; 2; 3; 4; 3; 4]
         = [[1]; [2; 2]; [3; 3; 3]; [4; 4; 4]])
        "repeats";
  check (buckets (fun x y -> x mod 3 = y mod 3) [1; 2; 3; 4; 5; 6]
         = [[1; 4]; [2; 5]; [3; 6]])
        "mod-3";
  check (buckets (=) ([] : int list) = ([] : int list list))
        "empty";
  check (buckets (=) [7] = [[7]]) "singleton";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let buckets p l =
  let rec insert x = function
    | [] -> [[x]]
    | (y :: _ as b) :: rest when p x y -> (b @ [x]) :: rest
    | b :: rest -> b :: insert x rest
  in
  List.fold_left (fun bs x -> insert x bs) [] l
```

The inner `insert` walks the current buckets and either appends `x`
to the first bucket whose representative `y` is equivalent to `x`,
or (if no bucket matches) appends a new singleton bucket at the
end. The outer `List.fold_left` runs `insert` for each input
element in turn. Assuming `p` takes constant time, the worst-case
cost is `O(n²)`. Even with a single bucket, each `b @ [x]` copies
all of `b`, for a total of `0 + 1 + ... + (n - 1)` copied cells.
Searching for a bucket also takes up to `O(k)` per element, where
`k` is the final number of buckets. This simple implementation is
fine for the problem's intended sizes.

:::

## Problem 6: `remove_stutter`

Write a function

```text
remove_stutter : 'a list -> 'a list
```

that removes *stuttering* (consecutive runs of the same element
collapsed to one). For example,

```text
remove_stutter [1; 2; 2; 3; 1; 1; 1; 4; 4; 2; 2] = [1; 2; 3; 1; 4; 2]
```

The output keeps the first element of each run and drops the rest of
that run. Note this is not the same as removing all duplicates: the
`1` near the end stays because it is not adjacent to the earlier
`1`s. (The `option` type may come in handy as the running "previous
element seen.")

:::quiz code id=M06-L07-q6
Implement `remove_stutter`.

```ocaml
let remove_stutter l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (remove_stutter [1; 2; 2; 3; 1; 1; 1; 4; 4; 2; 2]
         = [1; 2; 3; 1; 4; 2])
        "mixed";
  check (remove_stutter ([] : int list) = ([] : int list))
        "empty";
  check (remove_stutter [5] = [5]) "singleton";
  check (remove_stutter [3; 3; 3; 3] = [3]) "all same";
  check (remove_stutter [1; 2; 3; 4] = [1; 2; 3; 4]) "no stutter";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let remove_stutter l =
  let rec aux prev acc = function
    | [] -> List.rev acc
    | x :: xs ->
        (match prev with
         | Some y when y = x -> aux prev acc xs
         | _ -> aux (Some x) (x :: acc) xs)
  in
  aux None [] l
```

The accumulator `acc` collects results in reverse; the second
accumulator `prev` records the previous element seen (or `None` at
the start). On each step: if the current element equals `prev`,
skip it; otherwise, prepend to `acc` and update `prev`. Reverse at
the end. Tail-recursive.

:::

## Problem 7: `pairwise`

Write a function

```text
pairwise : 'a list -> ('a * 'a) list
```

that pairs each element with its immediate successor. For example,
`pairwise [1; 2; 3; 4] = [(1, 2); (2, 3); (3, 4)]`. Lists with
fewer than two elements have no adjacent pairs: return `[]`.

Note each middle element appears in *two* pairs (once on the right,
once on the left), so this is not a chunking of the list. The shape
is useful whenever a computation compares neighbours: detecting
ascending runs, computing differences, drawing line segments
between consecutive points.

(Hint: the nested pattern `x :: (y :: _ as rest)` from the
nested-patterns lecture matches a list with at least two elements
*and* keeps a name for everything after `x`.)

:::quiz code id=M06-L07-q7
Implement `pairwise`.

```ocaml
let rec pairwise l =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (pairwise [1; 2; 3; 4] = [(1, 2); (2, 3); (3, 4)])
        "four elements";
  check (pairwise ([] : int list) = []) "empty";
  check (pairwise [5] = []) "singleton";
  check (pairwise [1; 2] = [(1, 2)]) "exactly one pair";
  check (pairwise ["a"; "b"; "c"] = [("a", "b"); ("b", "c")])
        "strings";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec pairwise = function
  | x :: (y :: _ as rest) -> (x, y) :: pairwise rest
  | _ -> []
```

The first clause matches a list with at least two elements: `x` is
the head, `y` the second element, and `as rest` names the tail
*including* `y` so the recursion can pair `y` with its own
successor. The catch-all covers both the empty list and the
singleton, the two shapes with no adjacent pair.

:::

## Problem 8: `fold_inorder`

Given a binary tree

```text
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
```

write a function

```text
fold_inorder : ('a -> 'b -> 'a) -> 'a -> 'b tree -> 'a
```

that performs an in-order fold over the tree: visit the left
subtree, then the root, then the right subtree, threading the
accumulator through. For example,

```text
fold_inorder (fun acc x -> acc @ [x]) []
  (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)))
  = [1; 2; 3]
```

The [tree-folds section of the tutorial](M06-L06-tutorial.html#problem-5-tree-folds-in-three-orderings)
walked through this. Here, write it yourself before peeking.

:::quiz code id=M06-L07-q8
Implement `fold_inorder`.

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec fold_inorder f acc t =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let t =
  Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf))
let big =
  Node (
    Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)),
    4,
    Node (Node (Leaf, 5, Leaf), 6, Node (Leaf, 7, Leaf)))
let () =
  check (fold_inorder (fun acc x -> acc @ [x]) [] t = [1; 2; 3])
        "small tree";
  check (fold_inorder (fun acc x -> acc @ [x]) [] big
         = [1; 2; 3; 4; 5; 6; 7])
        "BST in order";
  check (fold_inorder (+) 0 big = 28) "sum";
  check (fold_inorder (fun acc _ -> acc + 1) 0 big = 7) "count";
  check (fold_inorder (fun acc x -> acc @ [x]) [] (Leaf : int tree) = [])
        "empty tree";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec fold_inorder f acc t =
  match t with
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_inorder f acc l in
      let acc = f acc v in
      fold_inorder f acc r
```

The two cases mirror the two constructors. At a `Leaf`, return the
accumulator unchanged. At a `Node (l, v, r)`, fold the left subtree
first, then visit the root with `f`, then fold the right subtree.
Each step threads the latest accumulator into the next.

:::

## Problem 9: tail-recursive Fibonacci

The textbook recursive Fibonacci

```text
let rec fib n =
  if n = 0 then 0
  else if n = 1 then 1
  else fib (n - 1) + fib (n - 2)
```

has exponential running time: computing `fib 46` this way is
already unbearable. But Fibonacci can be computed in linear time
by carrying the current and previous values as you go. Implement

```text
fib_tailrec : int -> int
```

as a *tail-recursive* function (each recursive call is in tail
position) so that `fib_tailrec 46 = 1836311903` returns instantly.
(Why stop at 46? The in-browser toplevel compiles to JavaScript,
where OCaml ints are 32-bit; `fib 47` already overflows them. On
native 64-bit OCaml you could go much further.)

:::quiz code id=M06-L07-q9
Implement `fib_tailrec`.

```ocaml
let fib_tailrec n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (fib_tailrec 0 = 0) "fib 0";
  check (fib_tailrec 1 = 1) "fib 1";
  check (fib_tailrec 2 = 1) "fib 2";
  check (fib_tailrec 10 = 55) "fib 10";
  check (fib_tailrec 46 = 1836311903) "fib 46";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let fib_tailrec n =
  let rec aux i prev cur =
    if i = n then cur
    else aux (i + 1) cur (prev + cur)
  in
  if n = 0 then 0 else aux 1 0 1
```

The inner `aux` carries the index `i` and the running pair
`(prev, cur)`. At each step, advance `(prev, cur)` to
`(cur, prev + cur)` and increment `i`. The recursive call is in tail
position, so the compiler turns it into a loop and no stack frames
accumulate. The outer `if n = 0` handles the boundary case
separately.

:::

## Part 2: the higher-order toolkit

Part 1 was deliberately recursion-first. Part 2 revisits the same
flavour of problem, but now you should reach for `List.map`,
`List.filter`, `List.fold_left` / `List.fold_right`, function
composition, and the pipeline operator `|>`. Several of these have a
one-line answer once you pick the right combinator and accumulator;
finding that shape is the exercise.

## Problem 10: `partition`

Write a function

```text
partition : ('a -> bool) -> 'a list -> 'a list * 'a list
```

that splits a list into two: the elements satisfying the predicate
(in original order) and the elements failing it (in original order).
For example, `partition (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5; 6] =
([2; 4; 6], [1; 3; 5])`.

The standard library has `List.partition`; write your own with a
single `List.fold_right`. (The accumulator is a *pair* of lists.)

:::quiz code id=M06-L07-q10
Implement `partition` using `List.fold_right`.

```ocaml
let partition p xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (partition (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5; 6]
         = ([2; 4; 6], [1; 3; 5])) "evens / odds";
  check (partition (fun _ -> true) [1; 2; 3] = ([1; 2; 3], []))
        "all pass";
  check (partition (fun _ -> false) [1; 2; 3] = ([], [1; 2; 3]))
        "all fail";
  check (partition (fun x -> x > 0) ([] : int list) = ([], []))
        "empty";
  check (partition (fun s -> String.length s > 2)
           ["hi"; "bye"; "yo"; "okay"]
         = (["bye"; "okay"], ["hi"; "yo"])) "strings";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let partition p xs =
  List.fold_right
    (fun x (yes, no) -> if p x then (x :: yes, no) else (yes, x :: no))
    xs ([], [])
```

The accumulator is a pair `(yes, no)`. Each element is consed onto
the front of whichever side it belongs to. `fold_right` walks
right-to-left and conses onto the front, so both output lists come
out in the original order. (With `fold_left` you would get both
reversed.)

:::

## Problem 11: `flat_map`

Write a function

```text
flat_map : ('a -> 'b list) -> 'a list -> 'b list
```

that applies `f` (which returns a list) to every element and
concatenates the results. For example, `flat_map (fun x -> [x; x * 10])
[1; 2; 3] = [1; 10; 2; 20; 3; 30]`.

`flat_map` is `map` followed by `concat` (the standard library calls
it `List.concat_map`). It is the workhorse behind list
comprehensions in other languages, and is the *bind* of the list
monad you will meet in [Module 8](M08-L02-laws-list-result.html).

:::quiz code id=M06-L07-q11
Implement `flat_map`. Either `fold_right` with `@`, or
`List.concat (List.map ...)`, works.

```ocaml
let flat_map f xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (flat_map (fun x -> [x; x * 10]) [1; 2; 3]
         = [1; 10; 2; 20; 3; 30]) "duplicate-scaled";
  check (flat_map (fun x -> [x]) [1; 2; 3] = [1; 2; 3]) "singleton lists";
  check (flat_map (fun _ -> []) [1; 2; 3] = ([] : int list)) "all empty";
  check (flat_map (fun x -> if x mod 2 = 0 then [x] else []) [1; 2; 3; 4]
         = [2; 4]) "filter via flat_map";
  check (flat_map (fun n -> [n; -n]) [5] = [5; -5]) "single element";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let flat_map f xs =
  List.fold_right (fun x acc -> f x @ acc) xs []
```

Fold `@` over the per-element result lists. The equivalent
two-step form is `List.concat (List.map f xs)`: map each element to
a list, then flatten. Both produce the same result; the fold form
avoids building the intermediate list of lists.

:::

## Problem 12: `compose_all`

Write a function

```text
compose_all : ('a -> 'a) list -> 'a -> 'a
```

that composes a list of functions into one, applying them
left-to-right. For example, `compose_all [f; g; h] x` should compute
`h (g (f x))`: `f` first, then `g`, then `h`. An empty list composes
to the identity function. For example,

```text
compose_all [(fun x -> x + 1); (fun x -> x * 2); (fun x -> x - 3)] 10 = 19
```

(that is `((10 + 1) * 2) - 3`).

This follows directly from the [composition
lecture](M06-L05-pipelines.html): you are folding the composition
operator over a list of functions, with the identity function as
the seed.

:::quiz code id=M06-L07-q12
Implement `compose_all` with a fold.

```ocaml
let compose_all fs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (compose_all
           [(fun x -> x + 1); (fun x -> x * 2); (fun x -> x - 3)] 10
         = 19) "arithmetic chain";
  check (compose_all [] 42 = 42) "empty is identity";
  check (compose_all [(fun x -> x * x)] 5 = 25) "single function";
  check (compose_all [String.trim; String.lowercase_ascii] "  HELLO  "
         = "hello") "string pipeline";
  check (compose_all
           [(fun x -> x + 1); (fun x -> x + 1); (fun x -> x + 1)] 0
         = 3) "thrice";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let compose_all fs =
  List.fold_left (fun acc f -> fun x -> f (acc x)) (fun x -> x) fs
```

Start from the identity function `fun x -> x`. For each function
`f` in the list, wrap the running composition `acc` so that the new
function runs `acc` first and then `f`. Folding *left* gives
left-to-right application order. The result is a single function of
type `'a -> 'a`; it does no work until you apply it to an argument.

:::

## Problem 13: `run_length_encode`

Write a function

```text
run_length_encode : 'a list -> ('a * int) list
```

that compresses each run of equal adjacent elements into a single
`(element, count)` pair. For example,

```text
run_length_encode [1; 1; 1; 2; 3; 3] = [(1, 3); (2, 1); (3, 2)]
```

This is the counting cousin of `remove_stutter` from Problem 6:
instead of dropping the repeats, you tally them.

:::quiz code id=M06-L07-q13
Implement `run_length_encode` with a single `List.fold_right`.

```ocaml
let run_length_encode xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (run_length_encode [1; 1; 1; 2; 3; 3]
         = [(1, 3); (2, 1); (3, 2)]) "mixed runs";
  check (run_length_encode ([] : int list) = ([] : (int * int) list))
        "empty";
  check (run_length_encode [7] = [(7, 1)]) "singleton";
  check (run_length_encode [1; 2; 3] = [(1, 1); (2, 1); (3, 1)])
        "no runs";
  check (run_length_encode ['a'; 'a'; 'b'; 'b'; 'b'; 'a']
         = [('a', 2); ('b', 3); ('a', 1)]) "runs return";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let run_length_encode xs =
  List.fold_right
    (fun x acc ->
      match acc with
      | (y, n) :: rest when y = x -> (y, n + 1) :: rest
      | _ -> (x, 1) :: acc)
    xs []
```

Folding from the right, the accumulator is the encoding of the
elements seen so far (those to the right of the current one). If the
current element `x` matches the head pair's element `y`, bump that
pair's count; otherwise start a new `(x, 1)` pair at the front.
Because we fold right-to-left and always inspect the *front* pair,
adjacent equal elements land in the same run.

:::

## Problem 14: `running_sum`

Write a function

```text
running_sum : int list -> int list
```

that returns the list of prefix sums: each output element is the sum
of all input elements up to and including that position. For
example, `running_sum [1; 2; 3; 4] = [1; 3; 6; 10]`.

This is a *scan* (sometimes `scanl`): like a fold, but it keeps every
intermediate accumulator instead of only the final one.

:::quiz code id=M06-L07-q14
Implement `running_sum`. A `fold_left` carrying `(total, reversed
output)` then a final `List.rev` is one clean way.

```ocaml
let running_sum xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (running_sum [1; 2; 3; 4] = [1; 3; 6; 10]) "ascending";
  check (running_sum ([] : int list) = ([] : int list)) "empty";
  check (running_sum [5] = [5]) "singleton";
  check (running_sum [1; -1; 1; -1] = [1; 0; 1; 0]) "alternating";
  check (running_sum [10; 20; 30] = [10; 30; 60]) "tens";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let running_sum xs =
  List.rev
    (snd
       (List.fold_left
          (fun (total, acc) x -> let t = total + x in (t, t :: acc))
          (0, []) xs))
```

The fold carries a pair: the running `total` and the output list
built in reverse. At each element, add it to the total and prepend
the new total to the output. At the end, take the second component
and reverse it. A scan keeps every step's accumulator, which is why
the output has the same length as the input.

:::

## Problem 15: `dot_product`

Write a function

```text
dot_product : int list -> int list -> int
```

that treats the two lists as vectors of equal length and returns
the sum of the element-wise products. For example,
`dot_product [1; 2; 3] [4; 5; 6] = 32` (that is
`1*4 + 2*5 + 3*6`).

Write it as a *pipeline*: combine the two lists element-wise with
`List.map2` (the standard library's two-list `map`; it raises
`Invalid_argument` on a length mismatch, which is fine here since
the inputs are promised to have equal length), then pipe the
products into a fold that sums them.

:::quiz code id=M06-L07-q15
Implement `dot_product` with `List.map2` and a `|>` pipeline.

```ocaml
let dot_product xs ys =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (dot_product [1; 2; 3] [4; 5; 6] = 32) "1*4 + 2*5 + 3*6";
  check (dot_product ([] : int list) [] = 0) "empty";
  check (dot_product [2] [10] = 20) "singleton";
  check (dot_product [1; -1] [5; 5] = 0) "cancels to zero";
  check (dot_product [3; 0; 2] [0; 7; 5] = 10) "zeros inside";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let dot_product xs ys =
  List.map2 ( * ) xs ys
  |> List.fold_left ( + ) 0
```

`List.map2 ( * )` multiplies the lists element-wise, producing the
list of products; the pipeline feeds it into `fold_left ( + ) 0`,
which sums them. Note `( * )` is the multiplication operator as a
function (the spaces keep it from being read as a comment opener).
A single `fold_left2` could do it in one pass; the two-stage
pipeline reads more clearly.

:::

## Part 3: optimising a syntax tree

The last two problems leave lists behind and work on a small
*abstract syntax tree* (AST) for arithmetic expressions: integer
literals, variables, and the three binary operators. This is the
same kind of tree you built in the
[variants tutorial](M04-L05-tutorial.html) and interpreted in the
[interpreter tutorial](M05-L06-tutorial.html):

```text
type expr =
  | Int of int
  | Var of string
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
```

Those tutorials *evaluated* a tree to a number. Here you do
something a compiler does before evaluating: rewrite the tree into a
smaller, equivalent tree. Both problems are recursions with the same
shape as the tree folds in Part 1's Problem 8, but the result is
itself an `expr`, not a number, so the recursion *rebuilds* the tree
as it goes.

## Problem 16: `constant_fold`

Write a function

```text
constant_fold : expr -> expr
```

that replaces any subexpression whose operands are both integer
literals with the computed literal, working bottom-up. Variables
(and any operator with a variable somewhere underneath) stay. For
example, `constant_fold (Mul (Add (Int 5, Int 3), Int 2)) = Int 16`,
while `constant_fold (Add (Mul (Int 2, Int 3), Var "x")) =
Add (Int 6, Var "x")` (the `2 * 3` folds to `6`, but the `+ x` stays
because `x` is not known).

The shape: recurse into both children *first*, then look at what
they reduced to. If both are `Int`, compute the result; otherwise
rebuild the node with the simplified children.

:::quiz code id=M06-L07-q16
Implement `constant_fold`.

```ocaml
type expr =
  | Int of int
  | Var of string
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr

let rec constant_fold e =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (constant_fold (Add (Int 1, Int 2)) = Int 3) "1+2";
  check (constant_fold (Mul (Add (Int 5, Int 3), Int 2)) = Int 16)
        "(5+3)*2";
  check (constant_fold (Add (Mul (Int 2, Int 3), Var "x"))
         = Add (Int 6, Var "x")) "2*3 + x";
  check (constant_fold (Var "y") = Var "y") "lone variable";
  check (constant_fold (Sub (Int 10, Add (Int 2, Int 3))) = Int 5)
        "10-(2+3)";
  check (constant_fold (Mul (Var "x", Add (Int 1, Int 1)))
         = Mul (Var "x", Int 2)) "x * (1+1)";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec constant_fold e =
  match e with
  | Int _ | Var _ -> e
  | Add (a, b) ->
      (match constant_fold a, constant_fold b with
       | Int x, Int y -> Int (x + y)
       | a', b' -> Add (a', b'))
  | Sub (a, b) ->
      (match constant_fold a, constant_fold b with
       | Int x, Int y -> Int (x - y)
       | a', b' -> Sub (a', b'))
  | Mul (a, b) ->
      (match constant_fold a, constant_fold b with
       | Int x, Int y -> Int (x * y)
       | a', b' -> Mul (a', b'))
```

Leaves (`Int`, `Var`) return unchanged. For each operator: fold the
two children, then match on the *results*. If both folded to `Int`,
compute the literal. Otherwise rebuild the node from the simplified
children (`a'`, `b'`) so any folding deeper in the tree is kept.
Because the recursion runs before the match, the folding propagates
all the way up from the leaves.

:::

## Problem 17: `simplify`

Constant folding only fires when *both* operands are literals.
Real optimisers also use algebraic identities that fire when just
one operand is a particular literal. Write

```text
simplify : expr -> expr
```

that does everything `constant_fold` does, and in addition applies:

- `e + 0 = e` and `0 + e = e`
- `e - 0 = e`
- `e * 1 = e` and `1 * e = e`
- `e * 0 = 0` and `0 * e = 0`

For example, `simplify (Add (Mul (Var "x", Int 0), Mul (Int 1, Var "y")))
= Var "y"`: the `x * 0` collapses to `0`, the `1 * y` collapses to
`y`, and then `0 + y` collapses to `y`.

:::quiz code id=M06-L07-q17
Implement `simplify`.

```ocaml
type expr =
  | Int of int
  | Var of string
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr

let rec simplify e =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (simplify (Add (Var "x", Int 0)) = Var "x") "x + 0";
  check (simplify (Mul (Int 1, Var "y")) = Var "y") "1 * y";
  check (simplify (Mul (Var "z", Int 0)) = Int 0) "z * 0";
  check (simplify (Add (Mul (Int 2, Int 3), Var "x"))
         = Add (Int 6, Var "x")) "fold then keep";
  check (simplify (Add (Mul (Var "x", Int 0), Mul (Int 1, Var "y")))
         = Var "y") "cascade to y";
  check (simplify (Sub (Var "x", Int 0)) = Var "x") "x - 0";
  check (simplify (Mul (Add (Int 1, Int 1), Add (Var "x", Int 0)))
         = Mul (Int 2, Var "x")) "both sides simplify";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec simplify e =
  match e with
  | Int _ | Var _ -> e
  | Add (a, b) ->
      (match simplify a, simplify b with
       | Int x, Int y -> Int (x + y)
       | Int 0, e | e, Int 0 -> e
       | a', b' -> Add (a', b'))
  | Sub (a, b) ->
      (match simplify a, simplify b with
       | Int x, Int y -> Int (x - y)
       | e, Int 0 -> e
       | a', b' -> Sub (a', b'))
  | Mul (a, b) ->
      (match simplify a, simplify b with
       | Int x, Int y -> Int (x * y)
       | Int 0, _ | _, Int 0 -> Int 0
       | Int 1, e | e, Int 1 -> e
       | a', b' -> Mul (a', b'))
```

The structure is `constant_fold` with extra match arms *between*
the both-literals arm and the rebuild arm. Order matters: the
both-`Int` arm is tried first (so `0 + 0` folds to `Int 0`, not
matched as an identity), then the identity arms, then the catch-all
rebuild. Because each operator simplifies its children before
matching, identities cascade: `x * 0` becomes `Int 0`, which then
lets the enclosing `0 + _` identity fire.

:::

## What you should be able to do now

By the end of these seventeen problems you should be comfortable with:

- Pattern-matching on lists (`[]`, `x :: xs`) and on options (`None`,
  `Some _`).
- Writing your own recursion when the standard library does not
  quite have the shape you need.
- Carrying an accumulator through a tail-recursive helper, and
  reversing at the end when order matters.
- Reaching for `List.fold_left` / `List.fold_right` when the answer
  is built from the whole list rather than each element
  independently.
- Recognising when a problem is asking for an explicit "previous
  element" or "running bucket list," and the shape of the helper
  function that follows.
- Choosing the right higher-order combinator (`map`, `filter`,
  `fold`, composition) instead of hand-writing the recursion, and
  chaining them into a `|>` pipeline that reads top-to-bottom.
- Using a pair-valued accumulator (`partition`, `running_sum`) and
  composing functions into new functions (`compose_all`).
- Recursing over a custom algebraic data type and *rebuilding* it,
  not just summarising it: a tree-to-tree rewrite like the constant
  folding and algebraic simplification an optimiser performs.

[Module 7](M07-L01-references.html) introduces side effects and the
OCaml *module* system: references and mutation, arrays, exceptions
(the formal counterpart to the `failwith` shortcut we used in
Problem 3), streams, memoisation, signatures, and functors.
Higher-order functions remain in play throughout.

## Sources

Most of Part 1 is drawn from
[Assignment 1](https://github.com/fplaunchpad/cs3100_m25/tree/main/assignments/assignment1)
of the instructor's *CS3100: Paradigms of Programming* course at
IIT Madras (Monsoon 2025), with prose, test harnesses, and
reference solutions rewritten for this NPTEL course; Problems 4
and 7 are new here. Part 2 (Problems 10 to 15) and Part 3
(Problems 16 to 17) are also new, extending the higher-order
toolkit and the arithmetic AST from the Module 4 to Module 6
lectures and tutorials.
