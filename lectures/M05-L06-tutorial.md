---
title: "Tutorial: an interpreter for the OCaml AST"
lecture_no: 6
week: 5
duration_target_min: 28
concepts: [worked AST walk, structural recursion, interpreter, environment, multi-purpose pattern matching]
keywords: [OCaml, AST, expression, interpreter, eval, environment, pattern matching tutorial]
activity_question: "Extend the AST with [Sub of expr * expr] and [Mul of expr * expr]. Update [pretty], [depth], and [eval]. Where does the compiler help? Where does it stay silent?"
think_about_this: "The `eval` function returns `value option`, not `value`. Why is that the natural choice given everything we know about M05 so far?"
reading:
  - title: "Cornell CS3110, Walking an AST"
    url: https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html
---

# Tutorial: an interpreter for the OCaml AST

:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: an interpreter for the OCaml AST</h2>
<p class="title-slide-label">Module 5 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

In the [AST tutorial](M04-L05-tutorial.html) you *built* an
algebraic data type for a tiny subset of OCaml: integer and
boolean literals, addition, variables, and `let ... in`. We
constructed example trees but never walked them. This lecture
closes the loop. We will write three walkers over the same AST:
a pretty printer, a depth function, and the centrepiece, an
*interpreter* that evaluates an expression to a value. The
interpreter is the natural home for almost everything we have
seen in Module 5, from
[basic patterns](M05-L01-basic-patterns.html) to
[or-patterns](M05-L03-nested-and-or-patterns.html) to
[exhaustiveness](M05-L05-exhaustiveness.html).

We will extend the OCaml AST with *one* new constructor,
`If`, so that the existing `Bool` constructor has somewhere to
flow. Everything else stays as it was. The interpreter uses
nothing beyond the language features introduced in Modules 1
through 5: pattern matching, recursion, `option`, lists. No
higher-order functions, no exceptions, no modules.

:::slide

## This tutorial

- Reuse the [OCaml AST](M04-L05-tutorial.html): `Int`, `Bool`,
  `Add`, `Var`, `Let_in`.
- Add **one** new constructor: `If` (so `Bool` earns its keep).
- Three walkers, each a pattern match on the same type:
  - **`pretty`**: produce a string.
  - **`depth`**: how tall is the tree.
  - **`eval`**: the centrepiece; reduce an expression to a value.
- Only M01-M05 features inside the interpreter. No
  exceptions, no higher-order functions, no modules.

:::

## The type, extended with `If`

The OCaml AST's final form from the previous tutorial, with
`If (cond, then, else)` added so that `Bool` actually does
something. The annotation on `Let_in` is `ty option` to preserve
the *make-illegal-states-unrepresentable* choice from the AST
tutorial: programs either supplied a type or did not.

```ocaml
type ty =
  | T_int
  | T_bool

type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | If of expr * expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr
```

Six constructors. Three of them carry payloads with sub-
expressions (`Add`, `If`, `Let_in`), so they are *recursive*.
The other three (`Int`, `Bool`, `Var`) are leaves at the AST
level: they carry data but no sub-expressions. Every walker
will have one clause per constructor, three of which recurse.

:::slide

## The AST

```ocaml
type ty = T_int | T_bool

type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | If of expr * expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr
```

- Six constructors: three leaves (`Int`, `Bool`, `Var`), three
  recursive (`Add`, `If`, `Let_in`).
- `If` is the one new constructor beyond the AST tutorial.
- `ty option` keeps "type annotation present or absent" as a
  type-level distinction, same choice as the AST tutorial.

:::

A small example program to test our walkers on. In OCaml syntax:

```text
let x : int = 10 in
if true then x + 5 else 0
```

The same in our AST:

```ocaml
let example =
  Let_in ("x", Some T_int, Int 10,
    If (Bool true,
        Add (Var "x", Int 5),
        Int 0))
```

Every constructor of `expr` appears at least once. The program
should pretty-print back to something resembling the source,
have a small finite depth, and evaluate to `15`.

:::slide

## The example program

```text
let x : int = 10 in
if true then x + 5 else 0
```

as an `expr` value:

```ocaml
let example =
  Let_in ("x", Some T_int, Int 10,
    If (Bool true,
        Add (Var "x", Int 5),
        Int 0))
```

- Every constructor appears at least once.
- Should evaluate to `15`.

:::

## Function 1: `pretty`

A pretty printer turns an `expr` back into a string. We will
parenthesise every internal node so we never have to worry
about operator precedence. Two clauses are interesting: `If`
prints all three sub-expressions; `Let_in` has to decide whether
to emit the optional type annotation.

```ocaml
let pretty_ty t =
  match t with
  | T_int  -> "int"
  | T_bool -> "bool"

let rec pretty e =
  match e with
  | Int n  -> string_of_int n
  | Bool b -> string_of_bool b
  | Add (e1, e2) ->
    "(" ^ pretty e1 ^ " + " ^ pretty e2 ^ ")"
  | If (c, t, f) ->
    "(if " ^ pretty c ^ " then " ^ pretty t
    ^ " else " ^ pretty f ^ ")"
  | Var x  -> x
  | Let_in (x, opt_ty, e1, e2) ->
    let annot =
      match opt_ty with
      | None    -> ""
      | Some ty -> " : " ^ pretty_ty ty
    in
    "(let " ^ x ^ annot ^ " = " ^ pretty e1
    ^ " in " ^ pretty e2 ^ ")"

let _ = pretty example
(* = "(let x : int = 10 in (if true then (x + 5) else 0))" *)
```

The `Let_in` clause uses an *inner* `match` on the
`ty option`: present or absent, decided once, plugged back into
the surrounding string. This is the
[pattern-inside-a-constructor](M05-L03-nested-and-or-patterns.html#patterns-inside-a-variant-constructor)
shape, used here at the
sub-result level rather than at the outer pattern.

:::slide

## `pretty`: one clause per constructor

```ocaml
let pretty_ty t = match t with T_int -> "int" | T_bool -> "bool"

let rec pretty e =
  match e with
  | Int n  -> string_of_int n
  | Bool b -> string_of_bool b
  | Add (e1, e2) ->
    "(" ^ pretty e1 ^ " + " ^ pretty e2 ^ ")"
  | If (c, t, f) ->
    "(if " ^ pretty c ^ " then " ^ pretty t
    ^ " else " ^ pretty f ^ ")"
  | Var x  -> x
  | Let_in (x, opt_ty, e1, e2) ->
    let annot =
      match opt_ty with
      | None    -> ""
      | Some ty -> " : " ^ pretty_ty ty
    in
    "(let " ^ x ^ annot ^ " = " ^ pretty e1
    ^ " in " ^ pretty e2 ^ ")"
```

- Six clauses, one per constructor of `expr`.
- Inner `match` on `ty option` for the annotation.

:::

:::slide

## `pretty example`

```ocaml
let _ = pretty example
(* = "(let x : int = 10 in (if true then (x + 5) else 0))" *)
```

- The `Let_in` clause prints `let x : int = 10 in ...`.
- The annotation `: int` came from the inner `match` on the
  `ty option` payload.
- Every internal node parenthesised; no precedence to worry about.

:::

## Function 2: `depth`

`depth` returns the height of the AST. The three leaf
constructors all return `1`; we can fold them into a single
clause with an [or-pattern](M05-L03-nested-and-or-patterns.html#or-patterns-shared-right-hand-sides),
since they share the same right-hand side.

```ocaml
let rec depth e =
  match e with
  | Int _ | Bool _ | Var _ -> 1
  | Add (e1, e2)           -> 1 + max (depth e1) (depth e2)
  | If (c, t, f)           ->
    1 + max (depth c) (max (depth t) (depth f))
  | Let_in (_, _, e1, e2)  -> 1 + max (depth e1) (depth e2)

let _ = depth example  (* = 4 *)
```

The or-pattern `Int _ | Bool _ | Var _` collapses three clauses
into one. The depth of `example` is `4`: `Let_in` at the top,
`If` underneath, `Add` underneath that, `Var` (or `Int`) at the
bottom.

:::slide

## `depth`: or-pattern across the leaves

```ocaml
let rec depth e =
  match e with
  | Int _ | Bool _ | Var _ -> 1
  | Add (e1, e2)           -> 1 + max (depth e1) (depth e2)
  | If (c, t, f)           ->
    1 + max (depth c) (max (depth t) (depth f))
  | Let_in (_, _, e1, e2)  -> 1 + max (depth e1) (depth e2)
```

- Three leaves share the same right-hand side: one clause via
  the or-pattern `Int _ | Bool _ | Var _`.
- Each recursive case adds `1` and takes the `max` over its
  sub-expressions.

:::

:::slide

## `depth example`

```ocaml
let _ = depth example  (* = 4 *)
```

- `Let_in` at the root: contributes `1`.
- `If` underneath: `1` more.
- `Add` underneath that: `1` more.
- Leaf (`Int` or `Var`) at the bottom: `1`. Total = `4`.

:::

## Function 3: `eval`

`eval` is the heart of the tutorial. Given an expression and
an *environment* mapping variable names to values, return the
value the expression reduces to.

A value is either an integer or a boolean. We model this with
a new variant; we cannot reuse OCaml's own `int` or `bool`
directly, because the same `eval` has to return both kinds of
result depending on the expression. An environment is a list of
`(name, value)` pairs:

```ocaml
type value =
  | VInt of int
  | VBool of bool

type env = (string * value) list
```

`eval` can *fail*. If we ask for `Add (Bool true, Int 1)` the
expression is type-incorrect and we have no answer. We have not
covered exceptions yet ([Module 7](M07-L03-exceptions.html)), so
we return `value option`: `Some v` on success, `None` on any
runtime mismatch. That matches the
[*make-illegal-states-unrepresentable*](M04-L04-recursive-types.html#when-to-use-option-the-fix)
slogan from Module 4: the type forces the caller to handle the
failure.

We also need to look up a variable in the environment. A plain
recursive function over the list; returns `None` if the name is
absent:

```ocaml
let rec lookup x (e : env) =
  match e with
  | []              -> None
  | (k, v) :: rest  -> if x = k then Some v else lookup x rest
```

:::slide

## `eval`: values, environment, and lookup

```ocaml
type value = VInt of int | VBool of bool
type env = (string * value) list

let rec lookup x (e : env) =
  match e with
  | []              -> None
  | (k, v) :: rest  -> if x = k then Some v else lookup x rest
```

- A `value` is `VInt _` or `VBool _`; eval returns *either*
  shape, so we need a tagged union.
- `env` is a `(name, value) list`: a fresh binding at the head
  shadows older ones.
- `lookup` walks the list; returns `None` if the name is unbound.

:::

Now `eval` itself. One clause per constructor of `expr`. The
recursive cases use nested `match`es on the sub-results to
propagate `None` and to enforce the expected value shape (an
`Add` needs two `VInt`s, an `If` needs a `VBool` condition).

```ocaml
let rec eval (env : env) e =
  match e with
  | Int n   -> Some (VInt n)
  | Bool b  -> Some (VBool b)
  | Add (e1, e2) ->
    (match eval env e1, eval env e2 with
     | Some (VInt a), Some (VInt b) -> Some (VInt (a + b))
     | _ -> None)
  | If (c, t, f) ->
    (match eval env c with
     | Some (VBool true)  -> eval env t
     | Some (VBool false) -> eval env f
     | _ -> None)
  | Var x -> lookup x env
  | Let_in (x, _, e1, e2) ->
    (match eval env e1 with
     | Some v -> eval ((x, v) :: env) e2
     | None   -> None)

let _ = eval [] example  (* = Some (VInt 15) *)
```

Reading the clauses:

- `Int n` and `Bool b` are leaves; they evaluate to themselves.
- `Add` evaluates both sub-expressions, then requires both to be
  `VInt`. The nested pattern `Some (VInt a), Some (VInt b)`
  binds the two integers and rebuilds a `VInt`. Anything else
  (a `None`, a `VBool`) collapses to `None`.
- `If` evaluates the condition, requires it to be `VBool`, and
  picks the branch. The runtime annotation `ty option` is
  ignored: it would matter to a *type checker*, not to the
  interpreter.
- `Var` delegates to `lookup`.
- `Let_in` evaluates the bound expression, extends the
  environment, and evaluates the body. The type annotation is
  again ignored at runtime.

`eval [] example` returns `Some (VInt 15)`.

:::slide

## `eval`: the easy cases

```text
let rec eval (env : env) e =
  match e with
  | Int n  -> Some (VInt n)
  | Bool b -> Some (VBool b)
  | Add (e1, e2) ->
    (match eval env e1, eval env e2 with
     | Some (VInt a), Some (VInt b) -> Some (VInt (a + b))
     | _ -> None)
  | ...
```

- Leaves wrap themselves in the matching `value` constructor.
- `Add` recurses on both children, then matches **the pair** of
  options to enforce "both `Some`, both `VInt`."
- Anything off-shape collapses to `None`.

:::

:::slide

## `eval`: `If`, `Var`, `Let_in`

```text
  | If (c, t, f) ->
    (match eval env c with
     | Some (VBool true)  -> eval env t
     | Some (VBool false) -> eval env f
     | _ -> None)
  | Var x -> lookup x env
  | Let_in (x, _, e1, e2) ->
    (match eval env e1 with
     | Some v -> eval ((x, v) :: env) e2
     | None   -> None)
```

- `If`: condition must be `VBool`; branch on it.
- `Var`: delegate to `lookup`.
- `Let_in`: eval the binding, extend env at the head, eval the
  body. The `ty option` is ignored at runtime (`_`).
- `eval [] example` = `Some (VInt 15)`.

:::

:::slide

## `eval`, assembled

```ocaml
let rec eval (env : env) e =
  match e with
  | Int n   -> Some (VInt n)
  | Bool b  -> Some (VBool b)
  | Add (e1, e2) ->
    (match eval env e1, eval env e2 with
     | Some (VInt a), Some (VInt b) -> Some (VInt (a + b))
     | _ -> None)
  | If (c, t, f) ->
    (match eval env c with
     | Some (VBool true)  -> eval env t
     | Some (VBool false) -> eval env f
     | _ -> None)
  | Var x -> lookup x env
  | Let_in (x, _, e1, e2) ->
    (match eval env e1 with
     | Some v -> eval ((x, v) :: env) e2
     | None   -> None)

let _ = eval [] example  (* = Some (VInt 15) *)
```

:::

## More examples

With `eval` defined, we can run it on a few small
expressions. For each one we show the `pretty` output (so you
can read the program as surface syntax) and the `eval` result.

```ocaml
let ex1 = Add (Int 2, Int 3)
let _ = pretty ex1   (* = "(2 + 3)" *)
let _ = eval [] ex1  (* = Some (VInt 5) *)
```

```ocaml
let ex2 = Let_in ("x", None, Int 10, Add (Var "x", Int 1))
let _ = pretty ex2   (* = "(let x = 10 in (x + 1))" *)
let _ = eval [] ex2  (* = Some (VInt 11) *)
```

`Let_in` extends the environment with `("x", VInt 10) :: []`,
then evaluates the body under that env. `Var "x"` finds it via
`lookup`.

```ocaml
let ex3 = If (Bool true, Int 42, Add (Int 1, Int 1))
let _ = pretty ex3   (* = "(if true then 42 else (1 + 1))" *)
let _ = eval [] ex3  (* = Some (VInt 42) *)
```

The condition `Bool true` evaluates to `VBool true`, so the
`then`-branch wins; the `else`-branch is never touched.

:::slide

## `eval` on a few small programs

```ocaml
let ex1 = Add (Int 2, Int 3)
let _ = eval [] ex1  (* = Some (VInt 5) *)
(* pretty: (2 + 3) *)

let ex2 = Let_in ("x", None, Int 10, Add (Var "x", Int 1))
let _ = eval [] ex2  (* = Some (VInt 11) *)
(* pretty: (let x = 10 in (x + 1)) *)

let ex3 = If (Bool true, Int 42, Add (Int 1, Int 1))
let _ = eval [] ex3  (* = Some (VInt 42) *)
(* pretty: (if true then 42 else (1 + 1)) *)
```

- Arithmetic, let-binding, conditional: same skeleton.
- `Let_in` extends `env`; `Var` looks up; `If` branches.
- Every clause threads `option` by hand.

:::

## When `eval` returns `None`

The interpreter is total in the sense that it never raises an
exception, but it does report failure with `None`. There are
two ways for an `expr` to fail at runtime: a value of the wrong
*kind* in an operator position, and a `Var` whose name is
unbound in the current environment.

```ocaml
let bad1 = Add (Bool true, Int 1)
let _ = pretty bad1   (* = "(true + 1)" *)
let _ = eval [] bad1  (* = None *)
```

`Add` expects two `VInt` payloads, and the first sub-expression
evaluates to a `VBool`. The nested `match` inside the `Add`
clause falls through to `_ -> None`.

```ocaml
let bad2 = Var "y"
let _ = pretty bad2   (* = "y" *)
let _ = eval [] bad2  (* = None *)
```

`lookup "y" []` walks the empty environment and returns `None`,
which propagates to the top.

```ocaml
let bad3 = If (Int 1, Int 42, Int 0)
let _ = pretty bad3   (* = "(if 1 then 42 else 0)" *)
let _ = eval [] bad3  (* = None *)
```

The condition is an integer, not a boolean. The nested `match`
inside the `If` clause falls through to `_ -> None`.

:::slide

## When `eval` returns `None`

```ocaml
let bad1 = Add (Bool true, Int 1)    (* "(true + 1)" *)
let _ = eval [] bad1                  (* = None *)

let bad2 = Var "y"                    (* "y" *)
let _ = eval [] bad2                  (* = None *)

let bad3 = If (Int 1, Int 42, Int 0)  (* "(if 1 then 42 else 0)" *)
let _ = eval [] bad3                  (* = None *)
```

- `bad1`: type-incorrect at runtime; `Add` wants two `VInt`s.
- `bad2`: unbound variable; `lookup` returns `None`.
- `bad3`: condition is not a `VBool`.

:::

## Two looming questions

There are two things to be uncomfortable about with this
interpreter, and both have proper answers in Module 8.

**Why so much `None`-bookkeeping?** Look at every recursive
clause: `Add`, `If`, `Let_in`. Each one does the same dance:
evaluate a sub-expression, pattern-match on the `Some _` / `None`
result, propagate `None` if it appears. The clauses are
near-copies of each other with different right-hand sides. This
boilerplate is exactly what the *option monad* captures, with a
`let*` operator that compresses each nested `match` to one line.
We take this same interpreter and rewrite it with `let*` in
[the option-monad lecture](M08-L01-option-monad.html). The shape
stays the same; the noise disappears.

**Why can `eval` fail at all?** Look at `bad1`: `Add (Bool true,
Int 1)` is a well-typed *OCaml value* of type `expr`, but it
represents a program that makes no sense. The OCaml type system
cannot see this, because our `expr` lumps integer expressions
and boolean expressions together. *GADTs*, in
[the GADT lectures](M08-L04-gadts-basics.html), let you index
`expr` by what it produces (`int` vs `bool`). With that indexing,
the
type system rules out `Add (Bool true, _)` at compile time, and
the option return type disappears entirely.

For Module 5, we accept the boilerplate and the runtime failure
as a fact of life. Both get repaired by the end of Module 8.

:::slide

## Two looming questions

- **Why so much `None`-bookkeeping?**
  Every recursive clause threads `option` by hand.
  [The option monad](M08-L01-option-monad.html) compresses each
  nested `match` to a one-line `let*`.
- **Why can `eval` fail at all?**
  `expr` lumps int and bool expressions together; the OCaml
  type system cannot reject `Add (Bool true, _)`.
  [GADTs](M08-L04-gadts-basics.html) index `expr` by what it
  produces, ruling `bad1` out at compile time.
- The `option` return type then disappears entirely.

:::

## The meta-pattern

Three different walkers, one shared skeleton. Each function has
exactly one clause per constructor. The base cases are the
leaves; the recursive cases recurse on the sub-expressions and
combine the results.

:::slide

## Every walker on `expr` has the same shape

```text
let rec f e =
  match e with
  | Int _ -> <leaf answer>
  | Bool _ -> <leaf answer>
  | Add (e1, e2) -> <combine f e1 and f e2>
  | If (c, t, f') -> <combine f c, f t, f f'>
  | Var _ -> <leaf answer>
  | Let_in (_, _, e1, e2) -> <combine f e1 and f e2>
```

- One clause per constructor of `expr`.
- The *exhaustiveness checker* tells you when you have missed
  one. We will lean on that in the activity.
- [Module 6](M06-L04-fold.html) extracts this skeleton as a
  generic *fold* over `expr` so you do not write it three times.

:::

The type definition gives the template; you fill in the actions.
The compiler will complain if you skip a constructor. After
Module 5 this should be muscle memory: "I have a recursive ADT;
my function has one clause per constructor; I recurse on the
sub-expressions and combine."

## Two checks

:::quiz mcq id=M05-L06-q1
Why does `eval` return `value option` rather than `value`?

- [ ] OCaml functions cannot return non-option values from a `match`.
- [x] Because some expressions cannot produce a `value`.
- [ ] Because every variable lookup might fail, and that is the only failure mode.
- [ ] It is a style preference; `value` would work just as well.

**Why:** two sources of failure: an off-shape arithmetic operand
(e.g., `Add (Bool true, Int 1)`) and an unbound variable. With no
exceptions yet, `option` is the natural way to surface either one to
the caller. The slogan from Module 4 is at work: `value option`
*forces* the caller to handle failure.
:::

:::quiz mcq id=M05-L06-q2
In the `Add` case, why do we match on the *pair* `(eval env e1, eval
env e2)` instead of nesting two separate `match`es?

- [ ] It is the only way to compile this in OCaml.
- [x] It handles both sub-results in one pattern.
- [ ] Because it is faster.
- [ ] Because nested matches would silently ignore one sub-result.

**Why:** matching on the pair lets one clause name both expected
shapes (`Some (VInt a), Some (VInt b)`) in a single nested pattern.
The catch-all `_` then handles every off-shape pair in one go. Two
nested matches would work too but would force us to repeat the
failure case.
:::

The code task extends the interpreter. It leans on the supporting
definitions from
[the `eval` walkthrough](#eval-values-environment-and-lookup),
which are still in scope; for reference:

```text
type value = VInt of int | VBool of bool
type env   = (string * value) list

val lookup : string -> env -> value option   (* None if unbound *)
```

:::quiz code id=M05-L06-q3
Extend `expr` with a new constructor `Sub of expr * expr` and
complete `eval`'s `Sub` clause. The starter redefines `expr` with
`Sub` and repeats `eval` with the `Sub` clause left as a `TODO`;
the chapter's `ty`, `value`, `env`, and `lookup` are still in
scope.

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Sub of expr * expr
  | If of expr * expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr

let rec eval (env : env) e =
  match e with
  | Int n   -> Some (VInt n)
  | Bool b  -> Some (VBool b)
  | Add (e1, e2) ->
    (match eval env e1, eval env e2 with
     | Some (VInt a), Some (VInt b) -> Some (VInt (a + b))
     | _ -> None)
  | Sub (e1, e2) -> failwith "TODO: the Sub clause"
  | If (c, t, f) ->
    (match eval env c with
     | Some (VBool true)  -> eval env t
     | Some (VBool false) -> eval env f
     | _ -> None)
  | Var x -> lookup x env
  | Let_in (x, _, e1, e2) ->
    (match eval env e1 with
     | Some v -> eval ((x, v) :: env) e2
     | None   -> None)
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (eval [] (Sub (Int 10, Int 3)) = Some (VInt 7)) "10 - 3";
  check (eval [] (Sub (Bool true, Int 1)) = None) "ill-typed operand";
  check (eval [] (Let_in ("x", None, Int 10, Sub (Var "x", Int 4)))
         = Some (VInt 6)) "sub under a let";
  print_endline "all tests passed"
```
:::

:::solution

The `Sub` clause mirrors `Add` with the operator swapped:
evaluate both children, require two `VInt`s, rebuild with `a - b`,
and collapse everything off-shape to `None`.

:::

## Activity

The point of the activity is to see the
[refactoring-with-the-compiler](M05-L05-exhaustiveness.html#the-big-payoff-refactoring-with-the-compiler)
loop end to end. Add two constructors. Build. Read the warnings.
Update each match site.

:::slide

## Activity

Add `Sub of expr * expr` and `Mul of expr * expr` to `expr`.

- What does the compiler say when you re-build `pretty`,
  `depth`, and `eval`?
- Which match in `depth` can use a *wider* or-pattern after
  the change?
- Does `lookup` need updating? Why or why not?

:::

Run the build before reading on. The compiler should report
three sites that need attention.

:::solution

:::slide

## Activity solution: which matches need updating

Adding `Sub` and `Mul`:

```ocaml
type expr =
  | Int of int
  | Bool of bool
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | If of expr * expr * expr
  | Var of string
  | Let_in of string * ty option * expr * expr
```

- `pretty`, `depth`, `eval`: each gets warning 8, naming
  `Sub _` and `Mul _` as missing.
- `lookup` is untouched: it walks an `env`, not an `expr`.
- The compiler points at every match site, not at every *file*.

:::

:::slide

## Activity solution: `depth` and `eval`

```text
(* depth: extend the binary or-pattern *)
| Add (e1, e2) | Sub (e1, e2) | Mul (e1, e2) ->
    1 + max (depth e1) (depth e2)

(* eval: one clause per new operator *)
| Sub (e1, e2) ->
  (match eval env e1, eval env e2 with
   | Some (VInt a), Some (VInt b) -> Some (VInt (a - b))
   | _ -> None)
| Mul (e1, e2) ->
  (match eval env e1, eval env e2 with
   | Some (VInt a), Some (VInt b) -> Some (VInt (a * b))
   | _ -> None)
```

- `depth`'s or-pattern grows naturally: same right-hand side,
  three alternatives.
- `eval`'s `Sub` and `Mul` are near-copies of `Add` with the
  operator swapped. The repetition is real; we tame it in
  [Module 6](M06-L04-fold.html).

:::

:::

## What's next

This tutorial closes Module 5. You have seen pattern matching
on flat values
([Lecture 1](M05-L01-basic-patterns.html)),
on recursive structures
([Lecture 2](M05-L02-recursive-patterns.html)),
inside other patterns (records, inline records, the diagonal
idiom, or-patterns)
([Lecture 3](M05-L03-nested-and-or-patterns.html)),
constrained by guards
([Lecture 4](M05-L04-guards.html)),
and under the exhaustiveness checker
([Lecture 5](M05-L05-exhaustiveness.html)).
The interpreter above brings all of those together on a single
recursive ADT.

:::slide

## What you should know after Module 5

- Use literal, variable, wildcard, list, tree, nested, and
  or-patterns fluently.
- Match on records (with `_` for ignored fields), variants,
  and combined shapes.
- Add `when`-guards for predicates the pattern language cannot
  express.
- Read the compiler's exhaustiveness warnings and use them as
  a refactoring aid.
- Walk recursive ADTs by pattern matching on the constructors.
- [Module 6](M06-L01-functions-revisited.html) generalises the
  walker: `map`, `filter`, and `fold` capture the meta-pattern.

:::

## Common pitfalls of interpreters

A handful of mistakes catch almost everyone the first time they
write an interpreter.

:::slide

## Common pitfalls of interpreters

- **Forgetting to parenthesise an inner `match`.** When the
  RHS of a clause is itself a `match`, parenthesise it (or use
  `begin ... end`). Otherwise the inner `|` clauses get parsed
  as part of the outer match. We did this in every recursive
  clause of `eval`.
- **Returning `value` instead of `value option`.** The compiler
  will tell you on the first off-shape input. Once you commit
  to `option`, every recursive call has to deal with it.
- **Forgetting that `Let_in` extends the environment.** The
  body is evaluated under `(x, v) :: env`, not `env`. Try
  swapping the two and watch every let-bound program return
  `None`.
- **Stale environment on `If`.** Both branches evaluate under
  the *same* `env`. Do not accidentally pass `[]` to one of
  them.

:::

## Reading

- **Cornell CS3110**, *Walking an AST*:
  <https://cs3110.github.io/textbook/chapters/data/pattern_matching_advanced.html>
- **Real World OCaml**, *Lists and patterns* (the trees and
  walkers section):
  <https://dev.realworldocaml.org/lists-and-patterns.html>
- John Whitington, *OCaml from the Very Beginning*, Chapter 8
  (data types and pattern matching).

## Sources

The AST in this lecture is the one we built in the
[AST tutorial](M04-L05-tutorial.html), extended with a
single `If` constructor. The interpreter, its environment
representation, and the worked walkers (`pretty`, `depth`,
`eval`) are original to this course. The "refactoring with the
compiler" idea is folklore in the OCaml/SML community and is
also discussed in Cornell CS3110, chapter on pattern matching.
