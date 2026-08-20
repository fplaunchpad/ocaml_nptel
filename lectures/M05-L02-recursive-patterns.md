---
title: "Pattern matching on lists and trees"
lecture_no: 2
week: 5
duration_target_min: 22
concepts: [pattern matching, list, tree, structural recursion, recursive variant, option]
keywords: [OCaml, pattern matching, list, tree, recursion, cons, nil, Leaf, Node]
activity_question: "Write [inorder : 'a tree -> 'a list] that returns the values of a binary tree in left-root-right order. Pattern-match on the two constructors."
think_about_this: "Every recursive type has one or more *base* constructors (carry no recursive reference) and one or more *recursive* constructors. How does the shape of a function over the type follow directly from that split?"
reading:
  - title: "Cornell CS3110, Lists and pattern matching"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
  - title: "Cornell CS3110, Trees"
    url: https://cs3110.github.io/textbook/chapters/data/trees.html
---

# Pattern matching on lists and trees

:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Pattern matching on lists and trees</h2>
<p class="title-slide-label">Module 5 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The last lecture covered three primitive pattern forms: literals,
variables, and the wildcard. Those are enough to dispatch on an
integer or a boolean, but they cannot yet take apart a *recursive*
value. From [Module 4](M04-L04-recursive-types.html) you already
know two recursive types: the built-in `'a list` and the binary
tree `'a tree`. This lecture is where pattern matching earns its
keep: we pair each recursive type with patterns over its
constructors, and walk the structure with one clause per
constructor. By the end of the lecture we will have written
`length`, `sum`, safe `hd`/`tl`, `append`, `size`, `depth`, and
`mirror`, all in three to five lines each.

:::slide

## From flat values to recursive structure

- [Last lecture](M05-L01-basic-patterns.html), patterns dispatched
  on *flat* values: an `int`, a `bool`.
- Real data is *built up*
  - lists from `[]` and `::`
  - trees from `Leaf` and `Node`.
- Patterns mirror the constructors:
  - one clause for `[]`, one for `h :: t`
  - one for `Leaf`, one for `Node (l, v, r)`.
- Recursive type + matching on its constructors = the canonical
  shape of every list / tree function.

:::

## A list is built from `[]` and `::`

Recall the built-in list type from the
[recursive-types lecture](M04-L04-recursive-types.html#ocamls-built-in-lists-are-just-variants):

```ocaml
(* type 'a list =
     | []
     | (::) of 'a * 'a list *)
```

Two constructors, so two patterns. `[]` matches the empty list.
`h :: t` matches a non-empty list, binding `h` to the head element
and `t` to the rest. That is *all* the pattern syntax we need for
this lecture; the four functions on the next four slides all use
just these two patterns.

:::slide

## A list is `[] | h :: t`

```ocaml skip
(* the two patterns we will use *)
| []      -> (* empty list *)
| h :: t  -> (* head h, tail t *)
```

- Two constructors: two patterns.
- `[]` matches the empty list, binds nothing.
- `h :: t` matches a non-empty list, binds the head and the tail.
- Every list pattern in this lecture is one of these two.

:::

## `length`: count the elements

The first function is `length`. The shape of the function follows
the shape of the type: one clause per constructor.

```ocaml
let rec length l =
  match l with
  | []     -> 0
  | _ :: t -> 1 + length t

let _ = length [10; 20; 30]  (* = 3 *)
let _ = length []             (* = 0 *)
```

The empty list has length `0`. A non-empty list has one more
element than its tail, so we add `1` and recurse on the tail.
Notice the `_` for the head: we do not need the value, just the
fact that there *is* a head. The recursive call is on `t`, which
is strictly shorter than `l`, so the recursion is guaranteed to
terminate.

:::slide

## `length`: one clause per constructor

```ocaml
let rec length l =
  match l with
  | []     -> 0
  | _ :: t -> 1 + length t

let _ = length [10; 20; 30]  (* = 3 *)
let _ = length []             (* = 0 *)
```

- Two constructors of `list`, two clauses.
- Base case `[]` returns `0`; no recursion.
- Recursive case adds `1` and recurses on `t`, the *strictly
  shorter* tail.
- `_` for the head: we did not need its value.

:::

## `sum`: total an integer list

`sum` has the same shape as `length`, but combines the elements
instead of counting them. Now we *do* need the head's value.

```ocaml
let rec sum l =
  match l with
  | []     -> 0
  | h :: t -> h + sum t

let _ = sum [10; 20; 30]  (* = 60 *)
let _ = sum []             (* = 0 *)
```

Base case: the empty list sums to `0`. Recursive case: add the
head to the sum of the tail. The structural shape is identical to
`length`: every list-consuming function will look like this.

:::slide

## `sum`: combine the head with the recursive result

```ocaml
let rec sum l =
  match l with
  | []     -> 0
  | h :: t -> h + sum t

let _ = sum [10; 20; 30]  (* = 60 *)
```

- Same shape as `length`.
- Base case `[]` returns `0` (the identity for `+`).
- Recursive case names the head `h` and combines it with the
  recursive result on `t`.

:::

## Safe `head` and `tail` with `option`

The built-in `List.hd` and `List.tl` raise an exception when the
list is empty. Exceptions are a Module 7 idea; for now we can
return `option` instead, matching the slogan from the
[recursive-types lecture](M04-L04-recursive-types.html#when-to-use-option-the-fix):
*make illegal states unrepresentable*. The function returns
`None` on the empty list and `Some _` otherwise.

```ocaml
let head_opt l =
  match l with
  | []     -> None
  | h :: _ -> Some h

let tail_opt l =
  match l with
  | []     -> None
  | _ :: t -> Some t

let _ = head_opt [10; 20; 30]  (* = Some 10 *)
let _ = tail_opt [10; 20; 30]  (* = Some [20; 30] *)
let _ = head_opt []            (* = None *)
let _ = tail_opt []            (* = None *)
```

`head_opt` ignores the tail with `_`; `tail_opt` ignores the
head. The caller now *has* to deal with the `None` case, because
the return type forces it.

:::slide

## Safe head and tail with `option`

```ocaml
let head_opt l =
  match l with
  | []     -> None
  | h :: _ -> Some h

let tail_opt l =
  match l with
  | []     -> None
  | _ :: t -> Some t

let _ = head_opt [10; 20; 30]  (* = Some 10 *)
let _ = tail_opt [10; 20; 30]  (* = Some [20; 30] *)
let _ = head_opt []            (* = None *)
```

- No exceptions, no sentinel value; the type says "may fail."
- `_` skips the part we do not need.
- Caller is *forced* to handle `None`. Illegal states gone.

:::

## `append`: glue two lists together

`append` takes two lists and returns a single list with the first
followed by the second. The OCaml built-in is the `@` operator.
We can write our own with the same two-clause shape.

```ocaml
let rec append l1 l2 =
  match l1 with
  | []     -> l2
  | h :: t -> h :: append t l2

let _ = append [1; 2; 3] [4; 5; 6]  (* = [1; 2; 3; 4; 5; 6] *)
let _ = append [] [4; 5; 6]         (* = [4; 5; 6] *)
let _ = append [1; 2; 3] []         (* = [1; 2; 3] *)
```

The recursion is over `l1`. When `l1` is empty, the answer is
just `l2`. When `l1` is `h :: t`, the result starts with `h` and
continues with `append t l2`. Note that the right-hand `::` is the
list *constructor*, not a pattern: we are *building* a list here,
not taking one apart.

:::slide

## `append`: recurse over the first list

```ocaml
let rec append l1 l2 =
  match l1 with
  | []     -> l2
  | h :: t -> h :: append t l2

let _ = append [1; 2; 3] [4; 5; 6]  (* = [1; 2; 3; 4; 5; 6] *)
```

- Base case: empty first list, return the second.
- Recursive case: stick the head on the front of `append t l2`.
- LHS `h :: t` is a *pattern*; RHS `h :: append ...` is the
  *constructor*. Same symbol, two roles.

:::

## Structural recursion as a discipline

Look back at the four functions. They all have the same skeleton:

```text
match l with
| []     -> <base answer>
| h :: t -> <combine h with recursive call on t>
```

This is *structural recursion*: the function's structure mirrors
the type's. There is one clause per constructor; the recursive
call is on a *strictly smaller* sub-value (the tail). The
recursion is guaranteed to terminate because every non-empty list
is one cons shorter than the original.

:::slide

## The shape of every list function

```text
match l with
| []     -> <base>
| h :: t -> <combine h with the recursive result on t>
```

- One clause per constructor.
- Recursion on the *strictly smaller* sub-value (the tail).
- Termination is "for free": eventually you reach `[]`.

:::

## A binary tree is `Leaf | Node (l, v, r)`

Recall the
[binary tree type](M04-L04-recursive-types.html#a-binary-tree)
from Module 4:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let example =
  Node (Node (Leaf, 1, Leaf),
        2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))
```

Two constructors again, so again two patterns. `Leaf` matches the
empty tree. `Node (l, v, r)` matches an internal node, binding the
left subtree, the value, and the right subtree. The same recipe
as lists, with the difference that the recursive constructor
holds *two* recursive references instead of one.

:::slide

## A tree is `Leaf | Node`

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
```

```text
        2
       / \
      1   3
           \
            4
```

- `Leaf`: empty. `Node (l, v, r)`: left, value, right.
- Two constructors, **two** recursive references in `Node`.
- We will get two recursive calls per node.

:::

## `size`: count the values in a tree

The function over the tree has one clause per constructor, just
like a list function. The recursive case has *two* recursive
calls, one per subtree.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec size t =
  match t with
  | Leaf            -> 0
  | Node (l, _, r)  -> 1 + size l + size r

let example =
  Node (Node (Leaf, 1, Leaf),
        2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))

let _ = size example  (* = 4 *)
let _ = size Leaf     (* = 0 *)
```

The empty tree has size `0`. A non-empty tree contributes `1` for
its own value plus the sizes of its two subtrees. The value at
the node does not affect the count, so we discard it with `_`.

:::slide

## `size`: one clause per constructor, **two** subtree calls

```ocaml
let rec size t =
  match t with
  | Leaf           -> 0
  | Node (l, _, r) -> 1 + size l + size r

let example =
  Node (Node (Leaf, 1, Leaf), 2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))

let _ = size example  (* = 4 *)
```

- Base case: `Leaf` returns `0`.
- Recursive case: `1` for this node, plus `size l`, plus `size r`.
- Two recursive calls because `Node` has two recursive children.

:::

## `depth`: longest path from root to a leaf

`depth` measures the height of the tree. The recursive case
takes the deeper of the two subtrees and adds `1`.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec depth t =
  match t with
  | Leaf           -> 0
  | Node (l, _, r) -> 1 + max (depth l) (depth r)

let example =
  Node (Node (Leaf, 1, Leaf),
        2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))

let _ = depth example  (* = 3 *)
let _ = depth Leaf     (* = 0 *)
```

`Stdlib.max` returns the larger of two values. The empty tree has
depth `0`; an internal node is one level deeper than its deepest
subtree.

:::slide

## `depth`: take the deeper subtree, add 1

```ocaml
let rec depth t =
  match t with
  | Leaf           -> 0
  | Node (l, _, r) -> 1 + max (depth l) (depth r)

let _ = depth example  (* = 3 *)
```

- Base case: `Leaf` is at depth `0`.
- Recursive case: `1` more than the deeper of the two subtrees.
- `max` lives in `Stdlib`; works on any comparable type.

:::

## `mirror`: swap left and right at every node

`mirror` returns a new tree where every `Node`'s subtrees are
swapped. It is a tree-*producing* function as well as a
tree-consuming one: each clause builds the answer with the
constructors.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec mirror t =
  match t with
  | Leaf           -> Leaf
  | Node (l, v, r) -> Node (mirror r, v, mirror l)

let _ = mirror (Node (Node (Leaf, 1, Leaf), 2, Leaf))
(* = Node (Leaf, 2, Node (Leaf, 1, Leaf)) *)

let _ = mirror Leaf  (* = Leaf *)
```

Empty tree mirrors to empty tree. A `Node` mirrors to a new
`Node` with the mirrored *right* subtree on the left and the
mirrored *left* subtree on the right. The value is unchanged.

:::slide

## `mirror`: rebuild with swapped subtrees

:::cols
:::col 62%

```ocaml
let rec mirror t =
  match t with
  | Leaf           -> Leaf
  | Node (l, v, r) -> Node (mirror r, v, mirror l)

let _ = mirror (Node (Node (Leaf, 1, Leaf), 2, Leaf))
(* = Node (Leaf, 2, Node (Leaf, 1, Leaf)) *)
```

- LHS `Node (l, v, r)`: pattern that *takes apart* a node.
- RHS `Node (mirror r, v, mirror l)`: constructor that *builds*
  a new node.

:::
:::col 38%

input:

```text
   2
  /
 1
```

output:

```text
2
 \
  1
```

:::
:::

:::

## Two checks

:::quiz mcq id=M05-L02-q1
What does `length [10; 20; 30]` evaluate to using the `length` we
wrote?

```ocaml skip
let rec length l =
  match l with
  | []     -> 0
  | _ :: t -> 1 + length t
```

- [ ] `0`
- [x] `3`
- [ ] `60`
- [ ] An exception is raised.

**Why:** the list has three cons cells before reaching `[]`. Each
cons adds `1`; the empty list contributes `0`. Total: `3`.
:::

:::quiz mcq id=M05-L02-q2
In `Node (l, v, r) -> 1 + size l + size r`, what is the role of `l`?

- [ ] It is the value at the node.
- [x] It is the *left subtree*, which itself has type `'a tree`.
- [ ] It is the leftmost leaf of the tree.
- [ ] It is a list of values from the left side of the tree.

**Why:** `Node` is declared `Node of 'a tree * 'a * 'a tree`; the
first field is the left subtree. The pattern `Node (l, v, r)` binds
`l` to that subtree.
:::

:::quiz code id=M05-L02-q3
Write `count_leaves : 'a tree -> int` that returns the number of
`Leaf` constructors in the tree. Pattern-match on the two
constructors.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec count_leaves t =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (count_leaves Leaf = 1) "single leaf";
  check (count_leaves (Node (Leaf, 1, Leaf)) = 2) "two leaves";
  check (count_leaves
           (Node (Node (Leaf, 1, Leaf), 2,
                  Node (Leaf, 3, Node (Leaf, 4, Leaf)))) = 5)
    "five leaves";
  print_endline "all tests passed"
```
:::

## Activity

Time to try one yourself before we discuss it. The function uses
both subtrees of every `Node`, and the answer is a *list*, not a
number: a small step from `mirror` (tree out) towards the
linearisation walks you will write in the [tutorial](M05-L06-tutorial.html).

:::slide

## Activity

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec inorder t = failwith "TODO"
```

- Write `inorder : 'a tree -> 'a list`.
- Return the values in **left-root-right** order.
- Two constructors, two clauses.
- The recursive case will call `inorder` on both subtrees

:::

:::solution

## Activity solution

The structural-recursion recipe applies straight off: one clause
per constructor, recursive calls on the strictly smaller
subtrees. The recursive clause concatenates three pieces: the
left walk, a one-element list with the node value, and the right
walk.

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let rec inorder t =
  match t with
  | Leaf           -> []
  | Node (l, v, r) -> inorder l @ [v] @ inorder r

let example =
  Node (Node (Leaf, 1, Leaf),
        2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))

let _ = inorder example  (* = [1; 2; 3; 4] *)
let _ = inorder Leaf     (* = [] *)
```

On our running `example`, the result is `[1; 2; 3; 4]`. The
tree's structure is gone; only the in-order linearisation
remains. `@` is the built-in list-append we wrote by hand
earlier in the lecture.

:::slide

## Activity solution: `inorder`

```ocaml
let rec inorder t =
  match t with
  | Leaf           -> []
  | Node (l, v, r) -> inorder l @ [v] @ inorder r

let example =
  Node (Node (Leaf, 1, Leaf), 2,
        Node (Leaf, 3, Node (Leaf, 4, Leaf)))

let _ = inorder example  (* = [1; 2; 3; 4] *)
```

- `Leaf` returns the empty list.
- `Node (l, v, r)` returns
  `inorder l @ [v] @ inorder r`.
- `@` is the built-in list-append (same shape as the `append`
  we wrote earlier in this lecture).
- `inorder example` = `[1; 2; 3; 4]`.

:::

:::

## Common pitfalls

A small set of mistakes catch almost everyone in the first week
of writing list and tree functions.

:::slide

## Common pitfalls

- **Forgetting `let rec`.** A recursive function needs `rec`; the
  compiler will tell you the name is unbound otherwise.
- **Missing the base case.** No `[]` / no `Leaf` clause means
  infinite recursion *and* a non-exhaustive warning from
  [Lecture 5](M05-L05-exhaustiveness.html).
- **Swapping `h :: t`.** The head is on the left; the tail is on
  the right. Reading `2 :: [3; 4]` as `[2]` on the right gives
  the wrong answer.
- **Confusing `::` the constructor with `::` the pattern.** LHS
  of `->` is a pattern (takes apart); RHS is an expression
  (builds). Same symbol, two roles.

:::

## What's next

[Lecture 3](M05-L03-nested-and-or-patterns.html) takes the next
step: patterns *inside* patterns, like `(x, _) :: _` for "a list
whose head is a pair," and *or-patterns* like `1 | 2 | 3 -> ...`
for sharing a right-hand side across several shapes. The list and
tree patterns from this lecture will appear constantly inside
those nested forms.

:::slide

## What's next

- [Lecture 3](M05-L03-nested-and-or-patterns.html): patterns
  inside patterns; or-patterns.
- The `[]` / `::` and `Leaf` / `Node` patterns from this lecture
  will appear inside nested forms throughout the rest of the
  module.
- [Lecture 5](M05-L05-exhaustiveness.html) will make the
  *compiler* check that you handled every constructor.

:::

## Reading

- Cornell CS3110,
  [Pattern matching](https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html)
  (list patterns and structural recursion).
- Cornell CS3110,
  [Trees](https://cs3110.github.io/textbook/chapters/data/trees.html).

## Sources

This lecture mirrors the *Pattern Matching on Lists* and
structural-recursion sections of the
[CS3100 monsoon 2025 lecture 6](https://github.com/fplaunchpad/cs3100_m25/blob/main/lectures/lec06_pattern_matching/lec6_pattern_matching.ipynb).
The `'a tree` type, the `example` value, and the `mirror` and
`inorder` examples are adapted from CS3100 monsoon 2025
[lecture 5](https://github.com/fplaunchpad/cs3100_m25/blob/main/lectures/lec05_datatypes/lec5_datatypes.ipynb).
