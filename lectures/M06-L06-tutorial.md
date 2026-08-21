---
title: "Tutorial: fold across data structures"
lecture_no: 6
week: 6
duration_target_min: 28
concepts: [worked higher-order, reimplement standard library, fold-everywhere, composition]
keywords: [OCaml, List, tutorial, higher-order, rebuild]
activity_question: "Write [maximum : 'a list -> 'a option] that returns the largest element of a list, or [None] if empty. Express it using [List.fold_left]."
think_about_this: "Almost every concrete list function can be written in terms of [fold_left] or [fold_right]. Why aren't they written that way in the standard library? What would you lose if they were?"
reading:
  - title: "Cornell CS3110, Re-implementing the List module"
    url: https://cs3110.github.io/textbook/chapters/hop/fold.html
---

# Tutorial: fold across data structures


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: fold across data structures</h2>
<p class="title-slide-label">Module 6 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

This lecture is the worked-exercise capstone of Module 6. Across the
previous five lectures we built up a small toolkit:
[higher-order functions](M06-L01-functions-revisited.html),
[`map`](M06-L02-map.html), [`filter`](M06-L03-filter.html),
[`fold_left` and `fold_right`](M06-L04-fold.html), the
[pipeline operator `|>`, and function composition](M06-L05-pipelines.html).
The thesis of this module has been that this small toolkit is enough
to express much list processing without writing a single
hand-coded recursion. In this tutorial we try to make good on
that claim: pick a list function from the standard library, then
build it from the toolkit.

The point of the exercise is not that you should always re-derive
standard library functions in real code; you should not. Use
`List.length` rather than `List.fold_left (fun n _ -> n + 1) 0`,
because the standard library version expresses intent more clearly
and is usually faster. The point is to *see how versatile the
toolkit is*: how few primitives you need before the rest follows. By
the end of this lecture, if I asked you to write a new list-flavoured
function on the spot, you should reach for `map`, `filter`, or
`fold` first.

We will work through seven problems: four rebuild small `List`
functions on top of `fold`, and three lift `fold` to other
data structures (binary tree pre/in/post/level order, and rose
trees).

:::slide

## This tutorial: fold across data structures

- The capstone of M06: put the toolkit to work.
- Toolkit: higher-order functions, `map`, `filter`, `fold`, `|>`, composition.
- Thesis: this small toolkit covers much list work without
  hand-coded recursion, *and* the same pattern lifts
  to other recursive types.
- Seven problems: four `List`-fold rebuilds, then three lifts of
  `fold` to other data structures (binary tree pre/in/post/level
  order, rose trees).
- Not that you should re-derive stdlib functions in real code;
  the point is to *see* how few primitives the rest follows from.

:::

## Problem 1: `sum` and `product`

```ocaml
let sum xs = List.fold_left (+) 0 xs

let _ = sum [1; 2; 3; 4; 5]  (* = 15 *)
```

:::slide

## Problem 1: `sum` and `product`

```ocaml
let sum xs = List.fold_left (+) 0 xs

let _ = sum [1; 2; 3; 4; 5]  (* = 15 *)
```

- `+` is the combining function.
- `0` is the starting accumulator.

Same shape for `product`:

```ocaml
let product xs = List.fold_left ( * ) 1 xs

let _ = product [1; 2; 3; 4; 5]  (* = 120 *)
```

- Accumulator starts at `1` (identity for multiplication).

:::

`sum` is the canonical fold: pass the operator `(+)` and the
identity element for the operator (`0`). For `product`, the operator
is `( * )` and the identity is `1`. The general pattern: any
associative binary operator with an identity element gives you a
one-line fold-based aggregation.

(Why does the identity element matter? Because of the empty-list
case. `fold_left (+) 0 []` returns `0`; `fold_left ( * ) 1 []`
returns `1`. Picking the identity makes those answers consistent
with the mathematical convention that an empty sum is zero and an
empty product is one.)

## Problem 2: `concat`

Flatten a list of lists into a single list. (Also called `flatten`
in some libraries.)

```ocaml
let concat xss =
  List.fold_right (fun xs acc -> xs @ acc) xss []

let _ = concat [[1; 2]; [3; 4; 5]; [6]]  (* = [1; 2; 3; 4; 5; 6] *)
```

:::slide

## Problem 2: `concat`

Flatten a list of lists into a single list.

```ocaml
let concat xss =
  List.fold_right (fun xs acc -> xs @ acc) xss []

let _ = concat [[1; 2]; [3; 4; 5]; [6]]  (* = [1; 2; 3; 4; 5; 6] *)
```


- `@` is list-append.
- Fold over the outer list; append each inner list to the accumulator.
- `fold_right` is `O(n)` in total length: each inner list is copied once.
- `fold_left (fun acc xs -> acc @ xs)` preserves order but is
  quadratic in the worst case because it repeatedly copies `acc`.
- For very long inputs, `List.concat` from the standard library is
  more efficient.

:::

The operator `@` is list-append. Each inner list is appended to the
accumulator; the rightmost inner list ends up at the back, the
leftmost at the front. A left fold can produce the same order:
`List.fold_left (fun acc xs -> acc @ xs) [] xss`. However, that
version is quadratic in the worst case: every step copies the entire
accumulated prefix before appending the next inner list. The
`fold_right` version is linear in the total number of elements because
each inner list is copied only once.

The standard library's `List.concat` is similar but optimised for
the common case.

## Problem 3: `for_all` and `exists`

Two list predicates.

```ocaml
let for_all p xs = List.fold_left (fun acc x -> acc && p x) true xs

let exists p xs = List.fold_left (fun acc x -> acc || p x) false xs

let _ = for_all (fun n -> n > 0) [1; 2; 3]    (* = true *)
let _ = for_all (fun n -> n > 0) [1; -2; 3]   (* = false *)
let _ = exists (fun n -> n < 0) [1; -2; 3]    (* = true *)
```

:::slide

## Problem 3: `for_all` and `exists`

```ocaml
let for_all p xs = List.fold_left (fun acc x -> acc && p x) true xs

let exists p xs = List.fold_left (fun acc x -> acc || p x) false xs

let _ = for_all (fun n -> n > 0) [1; 2; 3]    (* = true *)
let _ = for_all (fun n -> n > 0) [1; -2; 3]   (* = false *)
let _ = exists (fun n -> n < 0) [1; -2; 3]    (* = true *)
```


- `for_all`: accumulator starts `true`; an element with `p x = false`
  drags the whole `&&` to false.
- `exists`: accumulator starts `false`; a passing element flips the
  `||` to true.
- These don't short-circuit: fold visits every element.
- The standard library's `List.for_all` / `List.exists` do
  short-circuit; prefer those for long lists with early failure.

:::

`for_all p xs` is `true` if every element satisfies `p`; `exists p
xs` is `true` if at least one does. The two fold-based
implementations use `&&` and `||` respectively, with the appropriate
identity (`true` for AND, `false` for OR).

A subtlety: these implementations *do not short-circuit*. The fold
visits every element of the list, even if the answer is already
determined. The standard library's `List.for_all` and `List.exists`
are written directly and *do* short-circuit (returning `false` as
soon as an element fails `for_all`, returning `true` as soon as one
succeeds in `exists`). For long lists where failure or success
arrives early, the standard library is faster. Another reason to
prefer the library version over the home-rolled fold one in real
code.

## Problem 4: `count`

Count how many elements satisfy a predicate.

```ocaml
let count p xs =
  List.fold_left (fun n x -> if p x then n + 1 else n) 0 xs

let _ = count (fun n -> n > 0) [-1; 5; -3; 8; 0; 2]  (* = 3 *)
```

:::slide

## Problem 4: `count`

How many elements satisfy a predicate?

```ocaml
let count p xs =
  List.fold_left (fun n x -> if p x then n + 1 else n) 0 xs

let _ = count (fun n -> n > 0) [-1; 5; -3; 8; 0; 2]  (* = 3 *)
```

- Three positive elements.
- Accumulator counts; combining function bumps on a passing element.
- Alternative: `List.length (List.filter p xs)`.
- Fold version is one pass, no intermediate list.

:::

The result is `3` (the three strictly positive elements: `5`, `8`,
`2`). We could have written this as `List.length (List.filter p
xs)`: filter to keep the passing elements, then count. The
two-step version is arguably clearer; the fold version makes one
pass and never allocates the intermediate list. For short lists this
does not matter; for long ones the fold version saves both time and
garbage.

## Problem 5: tree folds in three orderings

Everything so far has been a fold on a `list`. The fold pattern
generalises directly to any recursive data type. A binary tree:

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
```

Three natural traversal orderings, all the same recursion with
`f acc v` permuted:

```ocaml
let rec fold_inorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_inorder f acc l in
      let acc = f acc v in
      fold_inorder f acc r

let rec fold_preorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = f acc v in
      let acc = fold_preorder f acc l in
      fold_preorder f acc r

let rec fold_postorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_postorder f acc l in
      let acc = fold_postorder f acc r in
      f acc v
```

The only thing that changes is *where* the visit `f acc v` sits
relative to the two recursive calls. In-order: between the
children. Pre-order: before. Post-order: after.

:::slide

## Problem 5a: in-order

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree

let rec fold_inorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_inorder f acc l in
      let acc = f acc v in
      fold_inorder f acc r
```

- Visit *left subtree*, then the *root*, then *right subtree*.
- `f acc v` sits between the two recursive calls.
- On a BST, this gives elements in **sorted order**.

:::

:::slide

## Problem 5b: pre-order

```ocaml
let rec fold_preorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = f acc v in
      let acc = fold_preorder f acc l in
      fold_preorder f acc r
```

- *Root first*, then left subtree, then right subtree.
- `f acc v` moves *before* both recursive calls.
- Use when each node should be visited before its descendants
  (e.g. copying / serialising a tree).

:::

:::slide

## Problem 5c: post-order

```ocaml
let rec fold_postorder f acc = function
  | Leaf -> acc
  | Node (l, v, r) ->
      let acc = fold_postorder f acc l in
      let acc = fold_postorder f acc r in
      f acc v
```

- Left subtree, right subtree, *then* the root.
- `f acc v` moves *after* both recursive calls.
- Use when each node's work depends on its children being done
  first (e.g. evaluating an expression tree).

:::

To see the difference, try them on a small binary search tree:

```ocaml
let t =
  Node (
    Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)),
    4,
    Node (Node (Leaf, 5, Leaf), 6, Node (Leaf, 7, Leaf)))

let collect = fun acc x -> acc @ [x]

let _ = fold_inorder   collect [] t  (* = [1; 2; 3; 4; 5; 6; 7] *)
let _ = fold_preorder  collect [] t  (* = [4; 2; 1; 3; 6; 5; 7] *)
let _ = fold_postorder collect [] t  (* = [1; 3; 2; 5; 7; 6; 4] *)
```

In-order on a BST returns elements in sorted order: that is the
defining property of a BST. Pre-order lists every node before its
children, which mirrors how the tree is built. Post-order lists
every node after its children, which is what you want when each
node's value depends on its subtrees being processed first (think
"evaluate the leaves before the internal nodes").

:::slide

## Three orderings on one tree

The tree:

```text
       4
      / \
     2   6
    / \ / \
   1  3 5  7
```

```ocaml
let t = Node (Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)), 4,
              Node (Node (Leaf, 5, Leaf), 6, Node (Leaf, 7, Leaf)))
let collect acc x = acc @ [x]

let _ = fold_inorder   collect [] t  (* = [1; 2; 3; 4; 5; 6; 7] *)
let _ = fold_preorder  collect [] t  (* = [4; 2; 1; 3; 6; 5; 7] *)
let _ = fold_postorder collect [] t  (* = [1; 3; 2; 5; 7; 6; 4] *)
```

- In-order on a BST: sorted order (`1..7`).
- Pre-order: root before children (build / clone the tree).
- Post-order: children before root (evaluate subtrees first).

:::

## Problem 6: level-order with a queue

Pre/in/post are easy because they follow the tree's own recursive
shape. *Level-order* (or *breadth-first*) traversal is different:
it visits all nodes at depth 0, then all at depth 1, then 2, and
so on. The recursive shape of the tree does not give you that order
for free, because each recursive call dives straight to a child
before visiting the sibling.

The standard trick is an explicit *queue* of pending nodes:

```ocaml
let levelorder_fold f acc tree =
  let rec go acc = function
    | [] -> acc
    | Leaf :: rest -> go acc rest
    | Node (l, v, r) :: rest ->
        go (f acc v) (rest @ [l; r])
  in
  go acc [tree]

let _ = levelorder_fold collect [] t  (* = [4; 2; 6; 1; 3; 5; 7] *)
```

The inner function `go` takes a list-as-queue. At each step, take
the head; if it's a `Leaf`, drop it and continue; if it's a `Node`,
visit `v` and append the two children to the *back* of the queue
with `@ [l; r]`. Appending to the back is what makes the traversal
breadth-first: a node's children are queued behind all the nodes
already pending at the current depth, so the current level finishes
before the next one starts.

:::slide

## Problem 6: level-order with a queue

```ocaml
let levelorder_fold f acc tree =
  let rec go acc = function
    | [] -> acc
    | Leaf :: rest -> go acc rest
    | Node (l, v, r) :: rest ->
        go (f acc v) (rest @ [l; r])
  in
  go acc [tree]

let _ = levelorder_fold collect [] t  (* = [4; 2; 6; 1; 3; 5; 7] *)
```

- *Not* a fold on the tree's own recursive shape.
- Uses a list-as-queue of pending subtrees.
- Children appended to the *back*: BFS, level by level.
- `rest @ [l; r]` is `O(n)`; a real implementation uses a proper
  `Queue` (Module 7).

:::

## Problem 7: fold over rose trees

A *rose tree* is an n-ary tree: each node carries a value and a
*list* of children, instead of exactly two:

```ocaml
type 'a rose = Rose of 'a * 'a rose list
```

A fold over a rose tree combines tree recursion with list recursion:
visit this node's value, then `List.fold_left` over the children,
recursively folding each one:

```ocaml
let rec fold_rose f acc (Rose (v, children)) =
  let acc = f acc v in
  List.fold_left (fold_rose f) acc children
```

The body has two folds nested in each other: an outer "fold this
node" (pre-order on the rose tree) and an inner `List.fold_left`
across the children's results. This is the pattern that scales fold
to almost any algebraic data type: one fold per recursive position.

A small example: a threaded discussion. Each comment carries text
(or here, a label) and a list of direct replies; each reply is
itself a comment that may have its own replies.

```ocaml
let thread =
  Rose ("Original post",
    [ Rose ("Reply A",
        [ Rose ("Reply A.1", []);
          Rose ("Reply A.2", []) ]);
      Rose ("Reply B",
        [ Rose ("Reply B.1", []) ]);
      Rose ("Reply C", []) ])

let _ = fold_rose (fun acc s -> acc @ [s]) [] thread  (* = ["Original post"; "Reply A"; ...; "Reply C"] *)
```

That is the pre-order walk of the discussion: each comment listed
before its replies, replies listed before their sub-replies. This
is the same order most threaded forums use to render comments
top-to-bottom on a page.

:::slide

## Problem 7a: fold over rose trees

```ocaml skip
type 'a rose = Rose of 'a * 'a rose list

let rec fold_rose f acc (Rose (v, children)) =
  let acc = f acc v in
  List.fold_left (fold_rose f) acc children
```

- Rose tree: each node has a *list* of children, not exactly two.
- One fold per recursive position: tree recursion *plus*
  `List.fold_left` across the children.
- The body is two folds nested: pre-order over the rose tree,
  list-fold across each node's children.
- This pattern scales fold to almost any algebraic data type.

:::

:::slide

## Problem 7b: walking a threaded discussion

:::cols
:::col 80%

```ocaml skip
let thread =
  Rose ("Post",
    [ Rose ("A", [Rose ("A.1", [])]);
      Rose ("B", []) ])

let _ = fold_rose (fun acc s -> acc @ [s]) [] thread
(* = ["Post"; "A"; "A.1"; "B"] *)
```

- Pre-order: each comment is listed before its replies.
- That's how forums render threads top-to-bottom.
- Same fold engine; only the combining function and accumulator
  change to match the question being asked.

:::
:::col 20%

```text
+ Post
  + A
    + A.1
  + B
```

:::
:::
:::

## A wider example: word frequencies

Let us combine pieces from across the module into a slightly larger
example. We count how often each word appears in a piece of text.
We will return the answer as an *association list* (a list of
pairs); in [Module 7](M07-L08-functors.html) we will see proper hash
tables and balanced maps.

```ocaml
let word_counts text =
  text
  |> String.lowercase_ascii
  |> String.split_on_char ' '
  |> List.filter (fun s -> s <> "")
  |> List.fold_left (fun counts w ->
       let n = match List.assoc_opt w counts with
         | Some n -> n
         | None -> 0
       in
       (w, n + 1) :: List.remove_assoc w counts
     ) []

let _ = word_counts "the quick brown fox jumps over the lazy dog the fox"  (* = [("fox", 2); ("the", 3); ...; ("quick", 1)] *)
```

The result is `[("fox", 2); ("the", 3); ("dog", 1); ("lazy", 1);
("over", 1); ("jumps", 1); ("brown", 1); ("quick", 1)]`: each fold
step prepends the freshly-bumped pair, so the words appear in
most-recently-touched-first order.

The pipeline reads top-to-bottom: lowercase, split into words, drop
empty pieces, then fold to build up a frequency table. The fold's
accumulator is an association list of word/count pairs; for each
word, we look up its current count (or 0 if absent), remove the old
entry, and prepend a new one with the bumped count.

This is the kind of code that, in Python or Java, would take a
small loop with a hash table. In OCaml with the higher-order
toolkit, it is a single pipeline. The trade-off is that this
implementation is `O(n^2)` in the number of distinct words (each
`List.assoc` and `List.remove_assoc` is linear); the proper solution
uses `Map` or `Hashtbl`, which we will meet in
[Module 7](M07-L08-functors.html). For now, the point is that the
*shape* of the computation is captured cleanly.

:::slide

## A wider example: word frequencies

```ocaml
let word_counts text =
  text
  |> String.lowercase_ascii
  |> String.split_on_char ' '
  |> List.filter (fun s -> s <> "")
  |> List.fold_left (fun counts w ->
       let n = match List.assoc_opt w counts with
         | Some n -> n
         | None -> 0
       in
       (w, n + 1) :: List.remove_assoc w counts
     ) []
```

- A `map`-like (`lowercase_ascii`), a `filter`, and a `fold_left`
  chained with `|>`.
- Accumulator: an association list `(word, count)`.
- For each word: look up the running count, drop the old entry,
  prepend the bumped one.
- `O(n^2)` because `List.assoc` is linear; for production use
  `Map` or `Hashtbl` ([Module 7](M07-L08-functors.html)).

:::

:::slide

## `assoc_opt` is not magic

```ocaml
let rec assoc_opt k = function
  | [] -> None
  | (k', v) :: rest -> if k = k' then Some v else assoc_opt k rest

let _ = assoc_opt "fox" [("the", 3); ("fox", 2)]  (* = Some 2 *)
```

- Walk the pairs; first matching key wins.
- `O(n)` per lookup; `List.remove_assoc` is the same walk.
- That linear lookup inside `word_counts`' fold is exactly where
  its `O(n^2)` comes from.

:::

:::slide

## `word_counts`: a worked example

```ocaml
let _ = word_counts
  "the quick brown fox jumps over the lazy dog the fox"
(* = [("fox", 2); ("the", 3); ("dog", 1); ("lazy", 1);
      ("over", 1); ("jumps", 1); ("brown", 1); ("quick", 1)] *)
```

- Eight distinct words; "the" appears three times, "fox" twice.
- Ordering is "most-recently-touched first" (each step prepends).
- Same code on a 10 MB text file: still works, but `O(n^2)` in
  distinct words starts to bite.
- Module 7's `Map` / `Hashtbl` will turn this into an `O(n)`
  one-liner with the same overall shape.

:::

## A quick check

:::quiz mcq id=M06-L06-q3
Which of the following is *not* a fold doing constant work per
element as it walks the list once?

- [ ] `List.length`
- [ ] `List.filter p`
- [ ] `List.map f`
- [x] `List.sort compare`

**Why:** `length`, `filter`, and `map` are all linear walks of the
list, combining each element into the accumulator with a
constant-time step. They are textbook folds. Sorting is the odd one
out, with a qualifier worth knowing: you *can* write insertion sort
as a fold (`fold_right insert xs []`), but the combining step
(`insert`) is itself a linear walk of the accumulator, so the whole
thing is `O(n^2)`. What no fold gives you is `List.sort`'s
`O(n log n)` merge sort: that algorithm repeatedly compares elements
far apart, which does not fit the one-pass,
combine-as-you-go shape.
:::

:::quiz mcq id=M06-L06-q2
`List.fold_left (fun acc x -> x :: acc) [] [1; 2; 3]` is...

- [ ] `[1; 2; 3]`
- [x] `[3; 2; 1]`
- [ ] `[]`
- [ ] An error.

**Why:** `fold_left` walks left to right. Initial `acc = []`. After
`1`: `[1]`. After `2`: `[2; 1]`. After `3`: `[3; 2; 1]`. So this is
the classic one-line `List.rev`. To get back the original order, use
`fold_right` (which walks right-to-left).
:::

A code challenge:

:::quiz code id=M06-L06-q1
Write `longest : string list -> string option` that returns the
longest string in a list, or `None` for an empty list. If several
strings share the greatest length, return the *first* of them. Use
`List.fold_left` with `String.length`. (Hint: the accumulator is a
`string option`.)

```ocaml
let longest xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (longest ["hi"; "hello"; "hey"]   = Some "hello") "basic";
  check (longest []                       = None)         "empty";
  check (longest ["solo"]                 = Some "solo")  "singleton";
  check (longest ["abc"; "xyz"; "ab"]     = Some "abc")   "tie keeps first";
  check (longest [""; "a"]                = Some "a")     "empty string loses";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let longest xs =
  List.fold_left
    (fun acc s ->
      match acc with
      | None -> Some s
      | Some t ->
          if String.length s > String.length t then Some s else acc)
    None xs
```

The accumulator is a `string option`, starting at `None`. For each
string: if the accumulator is `None`, take this string as the
current best. Otherwise keep whichever is longer; the strict `>`
means a tie keeps the earlier string. The result is `None` exactly
when the list was empty.

:::

## Activity

:::slide

## Activity

Write `maximum : 'a list -> 'a option` returning the largest
element of a list, or `None` if empty. Use `List.fold_left`.

:::

:::solution

:::slide

## Activity solution

```ocaml
let maximum xs =
  List.fold_left
    (fun acc x ->
      match acc with
      | None -> Some x
      | Some m -> Some (max m x))
    None xs

let _ = maximum [3; 7; 1; 9; 5]      (* = Some 9 *)
let _ = maximum ([] : int list)      (* = None *)
```

- Accumulator is an *option* (`'a option`; an `int option` in the
  calls above).
- Starts at `None` (no element seen yet).
- For each element: if `None`, take this element; otherwise keep the larger.
- `([] : int list)` annotation is needed: `[]` alone is polymorphic
  and OCaml needs to pick a type.

:::

:::

## What you should be able to do now

By the end of Module 6 you should be able to:

- Recognise a higher-order function (one that takes or returns a
  function) and read its type fluently.
- Reach for `List.map` whenever you have "transform each element of
  a list."
- Reach for `List.filter` whenever you have "drop elements that fail
  a test," and for `List.filter_map` when you also want to transform.
- Reach for `List.fold_left` / `List.fold_right` when the answer
  is not a list, or when you need both summary and transformation in
  one pass.
- Chain operations with `|>` pipelines, top-to-bottom.
- Recognise when the standard library already has a function for
  the job (it almost always does).

:::slide

## What you should be able to do now

After Module 6 you can:

- Write functions that take or return other functions.
- Use `List.map` to transform every element of a list.
- Use `List.filter` to keep elements that pass a predicate.
- Use `List.fold_left` / `List.fold_right` to reduce a list to any
  value.
- Chain operations with `|>` pipelines.
- Recognize when the standard library has a function for the job.

What's coming up:

- [Module 7](M07-L01-references.html): side effects (`ref`, mutation, exceptions) and **modules** (the OCaml language feature, not the NPTEL kind).
- [Module 8](M08-L01-option-monad.html): monads and GADTs.

:::

## What's next

[Module 7](M07-L01-references.html) is a turn back toward the
imperative side of OCaml: *side effects* (mutable references,
exceptions, `Printf`), and *modules* (the OCaml language feature for
organising code into named, type-bearing units). Higher-order
functions remain in play throughout; we will see them again in
Module 7 in the form of references that hold functions and in
[Module 8](M08-L01-option-monad.html) in the form of monads, where
the whole programming pattern is built on higher-order composition.

## Reading

- **Cornell CS3110**, *Fold (re-implementing the List module)*:
  <https://cs3110.github.io/textbook/chapters/hop/fold.html>
- **John Hughes**, *Why Functional Programming Matters*: the
  classic case for the higher-order style and how it scales:
  <https://www.cs.kent.ac.uk/people/staff/dat/miranda/whyfp90.pdf>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
