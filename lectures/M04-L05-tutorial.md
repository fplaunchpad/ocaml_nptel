---
title: "Tutorial: a tiny AST for OCaml"
lecture_no: 5
week: 4
duration_target_min: 25
concepts: [worked ADT design, recursive variants, abstract syntax, AST]
keywords: [OCaml, AST, abstract syntax tree, ADT, recursive variant, tutorial]
activity_question: "Extend [expr] with a [Print of expr] constructor representing a top-level print of an expression's value, then build the AST for [let x = 10 in print x]."
think_about_this: "Why does a compiler convert source text to an AST before doing anything else with it? What goes wrong if you try to operate on the raw string?"
reading:
  - title: "Cornell CS3110, Algebraic data types"
    url: https://cs3110.github.io/textbook/chapters/data/algebraic_data_types.html
  - title: "Real World OCaml, Variants"
    url: https://dev.realworldocaml.org/variants.html
---

# Tutorial for Module 4 (part 1)


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: a tiny AST for OCaml</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Module 4 introduced [tuples](M04-L01-tuples.html),
[records](M04-L02-records.html), [variants](M04-L03-variants.html),
[recursive variants and polymorphism](M04-L04-recursive-types.html),
and [`option` / `result`](M04-L04-recursive-types.html). This
tutorial puts those pieces to work on a worked example, building a
small algebraic data type and a handful of concrete values on it.

The example: a *tiny abstract syntax tree (AST) for OCaml itself*.
Every OCaml expression you have written so far (`5`, `x + 3`, `if y
< 0 then 0 else y`, `let x = 5 in x + x`) is, internally, a value
of a variant type inside the OCaml compiler. The compiler reads
source text, parses it into a tree of constructors, and then every
later stage (type checking, optimisation, code generation) is
*just* recursive functions on that tree. For this lecture we are
going to *be* a tiny version of that compiler: we will design the
tree.

We are deliberately staying on the design side: type definitions
and constructed values, no tree walks. Walking an AST (writing an
*evaluator*, a *type checker*, or a *pretty printer*) needs
pattern matching, which gets its full treatment in
[Module 5](M05-L01-basic-patterns.html). We will return to this
exact `expr` type there and write `eval`, `vars_used`, and a
pretty printer on it.

## What is an AST?

An **abstract syntax tree** is the tree-shaped data representation
of a program. "Abstract" because it throws away surface details
that do not matter for meaning (whitespace, comments, parentheses
that the parser already resolved); "syntax" because it captures
the structure of how the program is written; "tree" because nested
expressions become nested constructors.

Concretely: the expression `5 + 3` is, as text, a five-character
string. As an AST, it is a tree with `+` at the root and two leaves
`5` and `3`. The expression `(5 + 3) * 2` is a tree with `*` at the
root, one leaf `2`, and one subtree (the `+` node) as the other
child. Parentheses do not appear in the tree: the structure already
encodes which operator binds first.

:::slide

## What is an AST?

- AST = **abstract syntax tree**, the tree representation of a
  program.
- Source text -> parser -> tree of constructors.
- Every later compiler stage operates on the tree, not the text.
- Today: we **design** the tree. Walking it is Module 5.

:::

:::slide

## Source vs tree: `5 + 3`

Source: `5 + 3`

Tree:

```text
   +
  / \
 5   3
```

- Operator at the root, operands at the leaves.
- Parens disappear: the structure already encodes binding.

:::

:::slide

## Source vs tree: `(5 + 3) * 2`

Source: `(5 + 3) * 2`

Tree:

```text
       *
      / \
     +   2
    / \
   5   3
```

- `*` is the root; one of its children is itself a `+` node.
- A node's child can be any expression; the grammar is
  **recursive**.

:::

## A first cut: literals and arithmetic

Let's start with the smallest useful AST: integer literals and
addition.

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
```

Two constructors. `Int` carries an OCaml `int`; `Add` carries
*two* sub-expressions. That second one is the key piece: the
recursion is what lets us build arbitrarily nested arithmetic.

A few example trees:

```ocaml
let e1 = Int 5
let e2 = Add (Int 5, Int 3)
let e3 = Add (Add (Int 1, Int 2), Int 4)
```

`e1` is the literal `5`; `e2` is `5 + 3`; `e3` is `(1 + 2) + 4`.
Notice how `e3`'s left child is itself an `Add` node, exactly
mirroring the parenthesised source.

:::slide

## A first cut

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
```

- `Int`: a literal integer.
- `Add`: carries **two** `expr` sub-trees. Recursive.

```ocaml
let e1 = Int 5                                (* 5         *)
let e2 = Add (Int 5, Int 3)                   (* 5 + 3     *)
let e3 = Add (Add (Int 1, Int 2), Int 4)      (* (1+2)+4   *)
```

:::

## Adding more operators

Real programs use more than `+`. The simplest extension is one
constructor per operator:

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
```

Now we can build `(5 + 3) * 2`:

```ocaml
let e_a = Mul (Add (Int 5, Int 3), Int 2)
```

The shape of the OCaml value mirrors the shape of the tree we drew
earlier. `Mul` at the root, `Add (Int 5, Int 3)` on the left,
`Int 2` on the right.

:::slide

## More arithmetic

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
```

```ocaml
(* (5 + 3) * 2 *)
let e_a = Mul (Add (Int 5, Int 3), Int 2)
```

- One constructor per operator. Verbose, but every shape is
  named explicitly.
- We will look at a more compact alternative shortly.

:::

## Adding variables and `let ... in`

So far our ASTs are *closed*: every leaf is a literal. To talk
about names we need a `Var` constructor (a reference to a bound
name) and a `Let_in` constructor (a binding form):

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Var of string
  | Let_in of string * expr * expr
```

`Var` carries just a string (the name being referenced). `Let_in`
carries three pieces: the *name* being bound, the *binding
expression* whose value gets bound to that name, and the *body*
in which the name is in scope. That is the same `let name = e1 in
e2` shape from the let-bindings lecture, now expressed as data.

The AST for `let x = 5 in x + 3`:

```ocaml
let e_let =
  Let_in ("x",
          Int 5,
          Add (Var "x", Int 3))
```

The bound name is `"x"`, the binding is `Int 5`, the body is
`Add (Var "x", Int 3)`. Notice how the body references the bound
name as `Var "x"`, not as a special token: the AST treats names
as ordinary strings, and the compiler's later stages decide what
each `Var` *resolves* to.

Nested let bindings become nested `Let_in` constructors. The AST
for `let x = 5 in let y = 10 in x + y`:

```ocaml
let e_let_nested =
  Let_in ("x", Int 5,
    Let_in ("y", Int 10,
      Add (Var "x", Var "y")))
```

The body of the outer `Let_in` is another `Let_in`; that one's
body is the addition. Exactly the right-associative nesting of
source `let` chains we saw in the let-bindings lecture.

:::slide

## Variables and `let ... in`

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Var of string
  | Let_in of string * expr * expr
```

- `Var "x"`: a reference to a bound name.
- `Let_in (name, bound_expr, body)`: the three-piece `let ... in`.

```ocaml
(* let x = 5 in x + 3 *)
let e_let =
  Let_in ("x", Int 5, Add (Var "x", Int 3))
```

:::

:::slide

## Nested `let ... in`

```ocaml
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Var of string
  | Let_in of string * expr * expr

(* let x = 5 in let y = 10 in x + y *)
let e_let_nested =
  Let_in ("x", Int 5,
    Let_in ("y", Int 10,
      Add (Var "x", Var "y")))
```

- The body of the outer `Let_in` is another `Let_in`.
- Right-associative nesting, exactly mirroring the source.

:::

## Adding `if`, booleans, and comparison

Conditionals need a boolean kind of value and a way to compare. We
add `Bool`, two comparison constructors (`Lt` and `Eq`), and an
`If` constructor with three sub-expressions:

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Lt  of expr * expr
  | Eq  of expr * expr
  | If  of expr * expr * expr
  | Var of string
  | Let_in of string * expr * expr
```

`If (cond, then_branch, else_branch)` carries three children: the
test, the value when the test is true, and the value when the test
is false. That matches the three slots in OCaml's
`if ... then ... else ...` expression from the if-expressions
lecture.

The AST for `if x < 0 then 0 else x`:

```ocaml
let e_clamp =
  If (Lt (Var "x", Int 0),
      Int 0,
      Var "x")
```

The condition is `Lt (Var "x", Int 0)`, a comparison subtree; the
then-branch is `Int 0`; the else-branch is `Var "x"`. Each branch
is just another `expr`, so they can themselves be arbitrarily
nested.

:::slide

## `if`, booleans, comparison

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Lt  of expr * expr
  | Eq  of expr * expr
  | If  of expr * expr * expr
  | Var of string
  | Let_in of string * expr * expr
```

- `If (cond, then_branch, else_branch)`: three sub-expressions.
- Each branch is itself an `expr` (so can nest arbitrarily).

:::

:::slide

## Building `if x < 0 then 0 else x`

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Lt  of expr * expr
  | Eq  of expr * expr
  | If  of expr * expr * expr
  | Var of string
  | Let_in of string * expr * expr

let e_clamp =
  If (Lt (Var "x", Int 0),
      Int 0,
      Var "x")
```

- One AST value for the whole expression.
- `Lt` subtree at the test position; integer / variable at the
  branches.

:::

## Design decision: per-operator vs `Binop`

We chose **one constructor per operator** above: `Add`, `Sub`,
`Mul`, `Lt`, `Eq`. The alternative is **a single `Binop`
constructor** that carries an operator tag plus two sub-expressions.
The two designs:

```ocaml
(* Per-operator. *)
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Lt  of expr * expr
  | Eq  of expr * expr
```

```ocaml
(* Single Binop, with an operator tag. *)
type op =
  | Plus | Minus | Times | Less | Equal

type expr =
  | Int of int
  | Binop of op * expr * expr
```

Trade-offs:

- The per-operator type is **more explicit**. Each operator gets a
  name; the type system makes you spell it out at construction.
- The `Binop` type is **more compact**. Five constructors collapse
  into one. Consumers of the AST (the eval function, the pretty
  printer) match one case and dispatch on `op` internally.
- The per-operator type **scales worse**: adding a new operator is
  a new constructor and a new pattern-match arm everywhere. The
  `Binop` type adds a new operator as just a new `op` variant.
- The `Binop` type **groups related shapes**: if every binary
  operator has the same `expr * expr` payload, it captures that
  regularity in one place.

Real OCaml compilers use the `Binop` style, with the operator (or
"primitive") tag as a richer variant. For our tiny AST either
choice is reasonable; we will keep the per-operator design for the
rest of this lecture because it makes each example tree easier to
read at first glance.

:::slide

## Design decision: per-op vs `Binop`

Two ways to represent binary operators:

```ocaml
(* Per-operator. *)
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Lt  of expr * expr
  | Eq  of expr * expr
```

```ocaml
(* Binop with an operator tag. *)
type op = Plus | Minus | Times | Less | Equal

type expr =
  | Int of int
  | Binop of op * expr * expr
```

- Per-op: more explicit, less compact.
- `Binop`: groups regular shapes, scales better to many operators.
- Real compilers use `Binop`-style. For a tiny tree, per-op reads clearer.

:::

## Design decision: optional type annotations

OCaml `let` lets you annotate the binding with a type:
`let x : int = 5 in ...`. The annotation is **optional**: when
absent, the type checker infers; when present, it must agree with
inference.

That "may or may not be there" is exactly what `option` is for. We
add a `ty` type for the small set of types our AST knows about, and
weave a `ty option` into the `Let_in` payload:

```ocaml
type ty =
  | T_int
  | T_bool

type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr
```

Two example trees, one with and one without an annotation:

```ocaml
(* let x = 5 in x + 3 *)
let e_unannotated =
  Let_in ("x", None, Int 5, Add (Var "x", Int 3))

(* let x : int = 5 in x + 3 *)
let e_annotated =
  Let_in ("x", Some T_int, Int 5, Add (Var "x", Int 3))
```

The `option` cleanly captures "the source either wrote a type or
did not." This is exactly the kind of *consumer uncertainty* the
[recursive-types lecture's rule of thumb](M04-L04-recursive-types.html#when-to-use-option)
covers: a later stage (the type checker) has to decide what to do
when the annotation is missing vs present.

:::slide

## Design decision: optional annotations

OCaml: `let x = 5 in ...` or `let x : int = 5 in ...`.

The annotation is optional - perfect fit for `option`:

```ocaml
type ty = T_int | T_bool

type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr
```

```ocaml
(* let x = 5 in x + 3 *)
let e_u = Let_in ("x", None,        Int 5, Add (Var "x", Int 3))

(* let x : int = 5 in x + 3 *)
let e_a = Let_in ("x", Some T_int,  Int 5, Add (Var "x", Int 3))
```

:::

## The shape of Module 4

This tutorial used every Module 4 idea:

- **Variants** with payloads (every `expr` constructor).
- **Recursive variants** (sub-expressions are themselves `expr`s).
- **Tuples** in constructor payloads (`expr * expr` for binary ops).
- **`option`** for the optional type annotation.
- **Type abbreviations** would fit naturally for an `id = string`
  alias, if we wanted to make `Var` self-documenting.

The next tutorial ([M04-L06](M04-L06-tutorial-fs.html)) builds a
second worked example on a different domain (a tiny file system),
so you see the same toolkit applied to data with a very different
shape.

What we have **not** done yet is take any of these trees apart. To
evaluate `e_clamp`, to substitute a value for `Var`, or to
pretty-print an `expr` back to source: each of those is a recursive
function that needs pattern matching. That is the whole of
[Module 5](M05-L01-basic-patterns.html). We will return to this
exact AST there.

:::slide

## The shape of Module 4

This tutorial used:

- **Variants** with payloads (each `expr` constructor).
- **Recursive variants** (sub-expressions are themselves `expr`).
- **Tuples** in payloads (`expr * expr`).
- **`option`** for optional annotations.

Next tutorial ([M04-L06](M04-L06-tutorial-fs.html)) reapplies the
toolkit to a file system. Walking ASTs (evaluator, pretty-printer)
is [Module 5](M05-L01-basic-patterns.html).

:::

## A quick check

:::quiz mcq id=M04-L05-q2
Given this AST type, which value represents `(5 - 3) * 2`?

```text
type expr =
  | Int of int
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
```

- [ ] `Mul (Sub (5, 3), 2)`
- [x] `Mul (Sub (Int 5, Int 3), Int 2)`
- [ ] `Sub (Mul (Int 5, Int 3), Int 2)`
- [ ] `Mul (Int 5, Sub (Int 3, Int 2))`

**Why:** every leaf has to be wrapped in `Int`, because the
payloads of `Sub` and `Mul` are `expr * expr`, not `int * int`.
The outer operator is the *last* one applied; here that is the
`*`, so the root is `Mul`. The left child is `Sub (Int 5, Int
3)` (the parenthesised part), and the right child is `Int 2`.
The third option puts the `Sub` at the root, which would
represent `(5 * 3) - 2`.
:::

:::quiz mcq id=M04-L05-q3
Why does the AST encode the source `let x = 5 in x + 3` as

```text
Let_in ("x", Int 5, Add (Var "x", Int 3))
```

rather than as

```text
Let_in (Var "x", Int 5, Add (Var "x", Int 3))
```

?

- [ ] Both work; the choice is purely stylistic.
- [x] Its first slot is a bound name (`string`), not an `expr`.
- [ ] `Var` is only allowed inside `Add`, never inside
      `Let_in`.
- [ ] The first slot of `Let_in` is the *value*, not the name.

**Why:** the `Let_in` constructor has payload `string * expr *
expr`: the name being bound (a plain string from the source),
the expression whose value is bound to it, and the body. The
*body* may mention the name via `Var "x"` because there `x` is
being *read*; in the first slot the name is being *introduced*,
so it is just a string. Putting `Var "x"` in the first slot
would be a type error.
:::

## Activity: extending the type

:::slide

## Activity

Extend `expr` with a new constructor `Print of expr` that
represents printing the value of a sub-expression. Then build the
AST for the program:

```text
let x = 10 in print x
```

Treat `print x` as `Print (Var "x")` (the body of the `let`).

:::

:::quiz mcq id=M04-L05-q1
Which is the correct AST for `let x = 10 in print x`?

```text
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Var of string
  | Let_in of string * expr * expr
  | Print of expr             (* new *)
```

- [x] `Let_in ("x", Int 10, Print (Var "x"))`
- [ ] `Let_in ("x", Print (Int 10), Var "x")`
- [ ] `Print (Let_in ("x", Int 10, Var "x"))`
- [ ] `Let_in (Print "x", Int 10, Var "x")`

**Why:** `Let_in` is `(name, bound_expr, body)`. The bound name is
`"x"`, the bound expression is `Int 10`, and the body is what
`print x` parses to, namely `Print (Var "x")`. The third option
prints the result of the *whole* let; the second prints the bound
value before the binding even happens; the fourth puts a `Print`
in the *name* slot, which is type-wrong because the slot expects
a `string`, not an `expr`.
:::

:::slide

## Activity discussion

Add one constructor:

```text
type expr =
  ...
  | Print of expr            (* new *)
```

Build:

```ocaml
type expr =
  | Int of int
  | Var of string
  | Let_in of string * expr * expr
  | Print of expr                          (* new *)

let prog =
  Let_in ("x", Int 10, Print (Var "x"))
```

- One new constructor, taking the expression to print.
- `Let_in`'s body slot accepts any `expr`, so `Print (Var "x")`
  drops straight in.

:::

## What's next

:::slide

## What's next

You have now seen the full Module 4 toolkit applied to an AST.

- One more tutorial ([M04-L06](M04-L06-tutorial-fs.html)):
  the **same toolkit** on a tiny **file system**.
- Then [Module 5](M05-L01-basic-patterns.html): **pattern
  matching** to take these values apart.

:::

You have now seen the full Module 4 toolkit (variants, tuples,
recursion, `option`) applied to an AST. The next
tutorial ([M04-L06](M04-L06-tutorial-fs.html)) reapplies the same
toolkit to a tiny file system, so you see how the same ingredients
fit a very different domain. Walking either tree (an AST evaluator,
a file-system `du`) is the job of pattern matching, which arrives
in [Module 5](M05-L01-basic-patterns.html).

## Reading

- **Cornell CS3110**, *Algebraic data types*:
  <https://cs3110.github.io/textbook/chapters/data/algebraic_data_types.html>
- **Real World OCaml**, *Variants*:
  <https://dev.realworldocaml.org/variants.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
