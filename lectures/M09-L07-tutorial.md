---
title: "Tutorial: testing the expr evaluator with OUnit2 and QCheck"
lecture_no: 7
week: 9
duration_target_min: 25
concepts: [testing tutorial, specifications, test design, OUnit2, QCheck, properties, invariants, expression evaluator, debugging]
keywords: [OCaml, testing, OUnit2, QCheck, tutorial, expression evaluator, AST, property-based testing, debugging, shrinking]
activity_question: "Extend the [expr] AST with unary negation ([Neg of expr]): add the clause to [eval], add the constructor to [gen_expr], then write and run the anchored property: [eval (Neg e)] agrees with [-. (eval e)] under [same_float]."
think_about_this: "If your QCheck property compares the OCaml-implemented eval against a hand-written reference (e.g. via float arithmetic in the property itself), what happens when the reference is also buggy? How do you avoid testing one bug against itself?"
reading:
  - title: "Cornell CS3110, Testing and OUnit"
    url: https://cs3110.github.io/textbook/chapters/data/ounit.html
  - title: "QCheck README and tutorial"
    url: https://github.com/c-cube/qcheck
---

# Tutorial: testing the `expr` evaluator with OUnit2 and QCheck


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: testing the expr evaluator with OUnit2 and QCheck</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 7</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

This tutorial puts the whole module to work on a single larger
example, walking the full arc once, end to end: write the
specification, design the cases, mechanise them with OUnit2,
and quantify them with QCheck. We take a small
arithmetic `expr` AST and its `eval`, a float-valued cousin of
[the interpreter you built in the pattern-matching
tutorial](M05-L06-tutorial.html), give them a full test suite,
deliberately break the implementation, and watch QCheck find
the bug. By the end you should have a complete test file you
could copy into a project and adapt.

We have made one choice that runs through the whole tutorial:
the function under test is the arithmetic evaluator `eval`,
which evaluates a tree of arithmetic operations to a `float`.
We chose it because it is small enough to fit on one screen,
rich enough to have interesting properties, and from a part of
the course that every student has already seen. Two
alternatives would have worked: a
`safe_div : int -> int -> int option` like the one you met in
[the option-monad lecture](M08-L01-option-monad.html), or a
list reversal function. We chose `expr` because it gives
us *both* simple-case unit tests AND structural properties that
exercise the recursive nature of the function. (`safe_div`
returns in a quiz at the end.)

:::slide

## What this tutorial does

- An arithmetic `expr` evaluator: a float cousin of
  [the pattern-matching tutorial's interpreter](M05-L06-tutorial.html).
- Write its **specification**; design **black-box cases** from
  it.
- Mechanise the cases as an **OUnit2 suite**.
- Write **QCheck properties** for invariants.
- Break one operation deliberately; watch QCheck find the bug.
- Walk away with a complete test file.

:::

## The function under test

A five-constructor arithmetic AST over floats, in the mould of
[the interpreter you built in the pattern-matching
tutorial](M05-L06-tutorial.html) (which had integers, booleans,
and variables; this one trades those for IEEE-754 floats):

```ocaml
type expr =
  | Num of float
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr

let rec eval = function
  | Num n      -> n
  | Add (a, b) -> eval a +. eval b
  | Sub (a, b) -> eval a -. eval b
  | Mul (a, b) -> eval a *. eval b
  | Div (a, b) -> eval a /. eval b
```

Five constructors, five clauses, recursive on the structure of
the expression. The expected behaviour: the leaf case returns
the carried number; each internal case recursively evaluates its
two sub-expressions and combines with the named operator.

This is small enough to read at a glance but rich enough that
testing it well takes more than one assertion. Each operator is
a separate place a bug could hide. The recursion is a separate
mechanism that could itself be wrong (off-by-one on which sub-
expression goes left). And `Div` introduces a numerical edge case
(division by zero, infinity, NaN) that needs explicit thought.

:::slide

## Function under test

```ocaml
type expr =
  | Num of float
  | Add of expr * expr | Sub of expr * expr
  | Mul of expr * expr | Div of expr * expr

let rec eval = function
  | Num n      -> n
  | Add (a, b) -> eval a +. eval b
  | Sub (a, b) -> eval a -. eval b
  | Mul (a, b) -> eval a *. eval b
  | Div (a, b) -> eval a /. eval b
```

- Five constructors, five clauses.
- Recursion on the tree structure.
- Each operator a separate place a bug could hide.
- `Div` introduces NaN / infinity edge cases.

:::

## Part 1: the specification

The module's discipline says: before any tool, write the
contract. The clauses are the
[specifications lecture's](M09-L02-specifications-invariants.html):
a *returns* clause, a *raises* clause, an *examples* clause. For
`eval` the whole contract is short, but two of its clauses take
a real decision, and writing them down is what surfaces the
decision.

```text
(** [eval e] is the value of the arithmetic expression [e],
    where [Num n] is [n] and [Add], [Sub], [Mul], [Div]
    denote IEEE-754 float +. , -. , *. and /. on the values
    of their sub-expressions.
    [eval] never raises: division by zero follows float
    semantics ([1/0] is [infinity], [0/0] is [nan]).
    Example: [eval (Mul (Add (Num 1., Num 2.),
                         Sub (Num 4., Num 0.5))) = 10.5]. *)
val eval : expr -> float
```

The first decision is hiding in the words "IEEE-754": the spec
commits `eval` to float arithmetic as it actually is, not
arithmetic as remembered from school. The second is the raises
clause that says there isn't one: dividing by zero is *defined*
behaviour here (`infinity`), not an error. A different contract
(raise, or return an `option`) would be legitimate; this one was
chosen, and now it is written down, every test below has an
authority to appeal to.

With a spec in hand, the test-design lecture's recipe applies.
Boundaries and partitions, read straight off the clauses:

:::slide

## The spec, and the cases it implies

"[eval e] is the value of [e] under IEEE-754 float
arithmetic; never raises; division by zero follows float
semantics."

| Region | Representative case |
| --- | --- |
| the leaf (base case) | `Num 3.0` |
| each operator, once | `Add`, `Sub`, `Mul`, `Div` of two leaves |
| asymmetric operands | `Sub (Num 2., Num 3.)`, not `3 - 3` |
| recursion (glass-box) | a two-level nested tree |
| the div-by-zero clause | `Div (Num 1., Num 0.)` is `infinity` |

- One row per behaviourally distinct region.
- Asymmetric inputs so a swapped-argument bug cannot hide.

:::

## Part 2: OUnit2 unit tests

The table becomes a suite. Each row turns into a named case
that nails down a *known specific behaviour*:

### Case 1: a leaf

The simplest possible expression: a single `Num`. The evaluator
should return its carried value.

```ocaml
open OUnit2

let test_num_leaf _ =
  assert_equal ~printer:string_of_float 3.0 (eval (Num 3.0))
```

This case looks trivial but exercises one constructor and the
non-recursive base of the function. If the leaf case were wrong
("`Num n -> 0.0`", a copy-paste mistake we have seen in real
code), every test that does *any* arithmetic would also fail; but
the failure would be hard to diagnose. This case isolates the
leaf.

:::slide

## Case 1: a leaf

```ocaml
open OUnit2

let test_num_leaf _ =
  assert_equal ~printer:string_of_float 3.0 (eval (Num 3.0))
```

- The non-recursive base of the function, isolated.
- A wrong leaf (`Num n -> 0.0`) would fail *every* arithmetic
  test
  - this case points at the leaf itself.

:::

### Case 2: each binary operator

Four small expressions, one per binary constructor:

```ocaml
let test_add _ =
  assert_equal ~printer:string_of_float 5.0
    (eval (Add (Num 2.0, Num 3.0)))

let test_sub _ =
  assert_equal ~printer:string_of_float (-1.0)
    (eval (Sub (Num 2.0, Num 3.0)))

let test_mul _ =
  assert_equal ~printer:string_of_float 6.0
    (eval (Mul (Num 2.0, Num 3.0)))

let test_div _ =
  assert_equal ~printer:string_of_float 0.5
    (eval (Div (Num 1.0, Num 2.0)))
```

One case per operator. Each is the smallest possible expression
that exercises that operator: two leaves joined by one internal
node. The `Sub` case uses asymmetric inputs (`2.0 - 3.0`, not
`3.0 - 2.0`) deliberately, because a swapped-arguments bug would
return `1.0` instead of `-1.0` and the case would catch it; a
symmetric input like `3.0 - 3.0` would not distinguish the bug.

:::slide

## Case 2: each binary operator

```ocaml
let test_add _ =
  assert_equal ~printer:string_of_float 5.0
    (eval (Add (Num 2.0, Num 3.0)))

let test_sub _ =
  assert_equal ~printer:string_of_float (-1.0)
    (eval (Sub (Num 2.0, Num 3.0)))

let test_mul _ =
  assert_equal ~printer:string_of_float 6.0
    (eval (Mul (Num 2.0, Num 3.0)))

let test_div _ =
  assert_equal ~printer:string_of_float 0.5
    (eval (Div (Num 1.0, Num 2.0)))
```

- The smallest expression per operator: two leaves, one node.
- `Sub` gets *asymmetric* inputs: `2.0 - 3.0`, not `3.0 - 3.0`
  - a swapped-arguments bug returns `1.0`, not `-1.0`.

:::

### Case 3: nested expressions

The recursion is its own thing to test. A two-level nested
expression exercises both leaf and recursive cases:

```ocaml
let test_nested _ =
  (* (1 + 2) * (4 - 0.5) = 3 * 3.5 = 10.5 *)
  let expr =
    Mul (Add (Num 1.0, Num 2.0),
         Sub (Num 4.0, Num 0.5))
  in
  assert_equal ~printer:string_of_float 10.5 (eval expr)
```

This is the tutorial's running example. It exercises the recursive
case for `Mul`, which has two sub-expressions, each of which is
itself a binary node. If the recursion forgot to recurse (e.g.
`Mul (a, _) -> eval a *. eval a`, a typical typo), this case
would catch it.

:::slide

## Case 3: nested expressions

```ocaml
let test_nested _ =
  (* (1 + 2) * (4 - 0.5) = 3 * 3.5 = 10.5 *)
  let expr =
    Mul (Add (Num 1.0, Num 2.0),
         Sub (Num 4.0, Num 0.5))
  in
  assert_equal ~printer:string_of_float 10.5 (eval expr)
```

- The recursion is its own thing to test.
- Both sub-expressions are themselves binary nodes.
- A forgot-to-recurse typo (`eval a *. eval a`) fails here.

:::

### Case 4: division by zero

The honest edge case. In IEEE-754 float, `1.0 /. 0.0` is
`infinity`, not an exception. So:

```ocaml
let test_div_by_zero _ =
  assert_equal ~printer:string_of_float infinity
    (eval (Div (Num 1.0, Num 0.0)))
```

We are not asserting that `eval` raises here; we are asserting it
returns `infinity`, which is what float division actually does.
This case documents the function's behaviour on a corner that
naive code might handle differently. If a future revision adds a
guard "raise if dividing by zero", this case will fail
immediately, which is the *desired* signal: someone has changed
the contract, and the test suite is forcing them to acknowledge
it.

If you wanted the *option* shape (`int_eval` returning `int
option`, raising on division by zero), you would replace this
case with `assert_raises`. The choice depends on your contract.

:::slide

## Case 4: division by zero

```ocaml
let test_div_by_zero _ =
  assert_equal ~printer:string_of_float infinity
    (eval (Div (Num 1.0, Num 0.0)))
```

- The spec says: `infinity`, not an exception.
- A future "raise on zero" guard makes this case fail
  - the desired signal: someone changed the contract.
- A raising contract would use `assert_raises` here instead.

:::

### Assembling the OUnit2 suite

```ocaml
let suite =
  "expr evaluator" >::: [
    "leaf" >:: test_num_leaf;
    "binary operators" >::: [
      "add" >:: test_add;
      "sub" >:: test_sub;
      "mul" >:: test_mul;
      "div" >:: test_div;
    ];
    "nested" >:: test_nested;
    "edges" >::: [
      "division by zero produces infinity" >:: test_div_by_zero;
    ];
  ]

let _ = run_test_tt_main suite
```

Seven cases, three named groups. Run it right here (in a
project, `dune runtest` does the same). All pass on the correct
implementation; the report is seven dots and an `OK`. Note the
suite is also *path-complete* in the test-design lecture's
sense: `eval` has five match arms, and between the leaf case,
the four operator cases, and the nested case, every arm runs.

:::slide

## OUnit2 suite shape

```ocaml
let suite =
  "expr evaluator" >::: [
    "leaf" >:: test_num_leaf;
    "binary operators" >::: [
      "add" >:: test_add; "sub" >:: test_sub;
      "mul" >:: test_mul; "div" >:: test_div;
    ];
    "nested" >:: test_nested;
    "edges" >::: [
      "division by zero" >:: test_div_by_zero;
    ];
  ]

let _ = run_test_tt_main suite
```

- One case per region of the spec table.
- Asymmetric inputs: a swapped-argument bug cannot hide.

:::

## Part 3: QCheck properties

The unit tests check seven specific behaviours. We now write
*properties* that should hold of any well-formed `expr`. The
generator for `expr` is the new piece; once we have it, the
properties almost write themselves.

### A generator for `expr`

`expr` is not a built-in type, so QCheck does not have a generator
out of the box. We have to build one, and the first decision is
the *leaves*. The spec names `infinity` and `nan` as defined
behaviour, so the generator must actually visit them; a leaf
drawn only from `float_range` never produces either, and every
property below would silently test only the comfortable region.
That is the distribution lesson from the PBT lecture, applied to
floats:

```ocaml
let gen_leaf =
  QCheck.Gen.(oneof_weighted [
    (8, map (fun n -> Num n) (float_range (-100.0) 100.0));
    (1, return (Num infinity));
    (1, return (Num nan));
  ])
```

`oneof_weighted` is `oneof` with weights: eight draws in ten a
small in-range float, one in ten `infinity`, one in ten `nan`.
The rest of the special-value family arises downstream
(`Sub (Num 0., Num infinity)` is negative infinity, `0/0` more
NaN), so two seeded specials are enough to flood the trees: more
than half of the generated expressions evaluate to NaN.

The recursive case is the other interesting part: we need to
limit recursion depth so we do not generate infinite trees.

```ocaml
let rec gen_expr depth =
  let open QCheck.Gen in
  if depth <= 0 then gen_leaf
  else
    let sub = gen_expr (depth - 1) in
    oneof [
      gen_leaf;
      map2 (fun a b -> Add (a, b)) sub sub;
      map2 (fun a b -> Sub (a, b)) sub sub;
      map2 (fun a b -> Mul (a, b)) sub sub;
      map2 (fun a b -> Div (a, b)) sub sub;
    ]
```

The generator picks a depth (we hard-code 4 here), and at each
level either generates a leaf or recurses into one of the four
binary constructors. The depth bound is essential: without it
the random walk has a positive probability of recursing
indefinitely, and the test would hang. Depth 4 is enough to
exercise nontrivial trees but not so deep that float arithmetic
loses precision.

Counterexamples need to be *readable*, so before wrapping the
generator up we write a printer that renders an `expr` back as
source. `QCheck.make` then turns the generator into an
`arbitrary` (usable with `QCheck.Test.make`), with the printer
attached for failure messages:

```ocaml
let rec expr_str = function
  | Num n -> Printf.sprintf "%g" n
  | Add (a, b) -> "(" ^ expr_str a ^ " + " ^ expr_str b ^ ")"
  | Sub (a, b) -> "(" ^ expr_str a ^ " - " ^ expr_str b ^ ")"
  | Mul (a, b) -> "(" ^ expr_str a ^ " * " ^ expr_str b ^ ")"
  | Div (a, b) -> "(" ^ expr_str a ^ " / " ^ expr_str b ^ ")"

let _ = expr_str (Mul (Num 0.0, Div (Num 1.0, Num 0.0)))  (* = "(0 * (1 / 0))" *)

let arb_expr = QCheck.make ~print:expr_str (gen_expr 4)
```

One thing we deliberately leave off: a `~shrink`. As the PBT
lecture warned, a `QCheck.make` generator carries no shrinker
unless you attach one, so a failing `expr` would be reported
verbatim. The one custom shrinker this module writes is the
model-based lecture's command-list shrinker; here we accept
unshrunk trees, and the one property below that does fail
generates float *pairs*, which carry built-in shrinkers.

:::slide

## Leaves include the corners

```ocaml
let gen_leaf =
  QCheck.Gen.(oneof_weighted [
    (8, map (fun n -> Num n) (float_range (-100.0) 100.0));
    (1, return (Num infinity));
    (1, return (Num nan));
  ])
```

- The spec *names* `infinity` and `nan`
  - so the generator must visit them: `float_range` never would.
- `oneof_weighted`: `oneof` with weights, 8 : 1 : 1.
- Negative infinity and more NaN arise downstream
  - `Sub (Num 0., Num infinity)`, `0/0`.

:::

:::slide

## Generator for `expr`

```ocaml
let rec gen_expr depth =
  let open QCheck.Gen in
  if depth <= 0 then gen_leaf
  else
    let sub = gen_expr (depth - 1) in
    oneof [
      gen_leaf;
      map2 (fun a b -> Add (a, b)) sub sub;
      map2 (fun a b -> Sub (a, b)) sub sub;
      map2 (fun a b -> Mul (a, b)) sub sub;
      map2 (fun a b -> Div (a, b)) sub sub;
    ]
```

- Depth bound prevents infinite recursion.
- At each level: leaf or one of four binary nodes.

:::

:::slide

## Readable counterexamples

```ocaml
let rec expr_str = function
  | Num n -> Printf.sprintf "%g" n
  | Add (a, b) -> "(" ^ expr_str a ^ " + " ^ expr_str b ^ ")"
  | Sub (a, b) -> "(" ^ expr_str a ^ " - " ^ expr_str b ^ ")"
  | Mul (a, b) -> "(" ^ expr_str a ^ " * " ^ expr_str b ^ ")"
  | Div (a, b) -> "(" ^ expr_str a ^ " / " ^ expr_str b ^ ")"

let _ = expr_str (Mul (Num 0.0, Div (Num 1.0, Num 0.0)))  (* = "(0 * (1 / 0))" *)

let arb_expr = QCheck.make ~print:expr_str (gen_expr 4)
```

- `~print`: failure messages show source, not `<opaque>`.
- `QCheck.make` wraps the generator into an `arbitrary`.

:::

### Property 1: `eval` terminates and returns a `float`

The weakest possible property: just *running* `eval` on any
generated expression should return *something*, without exception
(except possibly via division-by-zero producing `infinity`/`nan`,
which is a normal `float` value in IEEE-754, not an exception).

```ocaml
let test_eval_terminates =
  QCheck.Test.make
    ~name:"eval returns a float on any expr"
    ~count:1000
    arb_expr
    (fun e ->
       let _ : float = eval e in
       true)

let _ = QCheck_runner.run_tests ~colors:false [test_eval_terminates]  (* = 0 *)
```

A trivial body: ignore the result; return `true`. The point of
this property is *not* the boolean it returns; it is that the
test fails if `eval` *raises* on any generated input. If our
generator ever produced an expression that crashed the
evaluator, this property would catch the crash.

This is sometimes called a *liveness* property: "the function
makes progress, on any input." It is the floor of correctness.
Many real-world bugs at the API boundary (unhandled NaN, stack
overflow on deep recursion) get caught by exactly this style of
property.

### Property 2: identity laws

`Add (Num 0.0, e)` should evaluate to the same value as `e`.
Similarly `Mul (Num 1.0, e)` should give `e`.

```ocaml
let same_float a b =
  (Float.is_nan a && Float.is_nan b) || a = b

let test_add_identity =
  QCheck.Test.make
    ~name:"0 + e = e"
    ~count:1000
    arb_expr
    (fun e -> same_float (eval (Add (Num 0.0, e))) (eval e))

let test_mul_identity =
  QCheck.Test.make
    ~name:"1 * e = e"
    ~count:1000
    arb_expr
    (fun e -> same_float (eval (Mul (Num 1.0, e))) (eval e))

let _ = QCheck_runner.run_tests ~colors:false
          [test_add_identity; test_mul_identity]  (* = 0 *)
```

Both rewrites are *exact* in IEEE-754: `0.0 +. v` and
`1.0 *. v` return `v`'s value unchanged for every `v`,
including infinities. The caveat is NaN: `1.0 *. nan` is `nan`,
and NaN is not equal to itself, so `nan = nan` is `false`. With
our NaN-seeding leaves, more than half the generated trees hit
exactly that, and a bare `=` property would fail in its
*comparison*, not its subject.

Why not skip those trees with the `QCheck.assume` the PBT
lecture introduced? Because that lecture also gave the rule: a
precondition that rejects most of what the generator makes is a
sign to fix the generator or the property, not the filter. Here
the property is the thing to fix: `same_float` says what
agreement *means* for floats: two NaNs agree. It is the
observation-equality move from the model-based lecture, shrunk
to a single comparison, and it turns the NaN corner from
something skipped into something tested: the property
now asserts that `0 + e` is NaN *exactly when* `e` is.

`same_float` patches NaN and inherits `=`'s one remaining blind
spot: the sign of zero. With infinities in the trees, `eval e`
can be `-0.0` (one route: `-1 / infinity`), and `0.0 +. -0.0`
is `+0.0`; bit for bit, the addition changed the value, but `=`
calls the two zeros equal. For this property that is the
agreement we want; a bit-level comparison would be stricter
than the spec promises.

### Property 3: distributivity (carefully)

`Mul (a, Add (b, c))` should equal `Add (Mul (a, b), Mul (a, c))`
in mathematics. Here, finally, float algebra breaks:
addition and multiplication are individually exact-commutative
in IEEE-754, but *distributing* a multiplication recomputes the
same value along two differently-rounded routes, and the two
results disagree for many inputs. So we write the property as
an *approximate* equality:

```ocaml
let test_distributes_approx =
  QCheck.Test.make
    ~name:"Mul distributes over Add (approx)"
    ~count:1000
    QCheck.(triple arb_expr arb_expr arb_expr)
    (fun (a, b, c) ->
       let lhs = eval (Mul (a, Add (b, c))) in
       let rhs = eval (Add (Mul (a, b), Mul (a, c))) in
       not (Float.is_finite lhs && Float.is_finite rhs)
       || (let denom = max (abs_float lhs) (abs_float rhs) in
           abs_float (lhs -. rhs) <= 1e-6 *. denom +. 1e-9))

let _ = QCheck_runner.run_tests ~colors:false [test_distributes_approx]  (* = 0 *)
```

The threshold (`1e-6` of the magnitude plus a small absolute
floor) is a typical pattern for float comparison: equal if the
relative error is small *or* if both sides are small. This
property captures "the algebra is right" in a way that tolerates
the floating-point reality.

The first line of the body restricts the property's *domain*,
and the restriction is not cosmetic: distributivity fails
outside the finite range. Take `a = Num infinity`,
`b = Num 2.`, `c = Num (-1.)`: the left route is
`infinity *. 1. = infinity`, while the expansion is
`infinity +. neg_infinity = nan`. No tolerance rescues that; the
honest property simply does not claim distributivity for
infinite routes. Written as an implication
(`not in-domain || claim`), the property is vacuously true off
its domain, with no skipping involved. That makes three tools
for partial claims, each with its place: `assume` skips a rare
corner, `same_float` redefines agreement, and an implication
restricts the domain.

:::slide

## Property 1: the liveness floor

```ocaml
let test_eval_terminates =
  QCheck.Test.make ~name:"eval returns a float on any expr"
    ~count:1000 arb_expr (fun e -> let _ : float = eval e in true)

let _ = QCheck_runner.run_tests ~colors:false [test_eval_terminates]  (* = 0 *)
```

- Fails only if `eval` *raises* on some generated tree.
- The floor of correctness: the function makes progress.

:::

:::slide

## Property 2: identity laws

```ocaml
let same_float a b =
  (Float.is_nan a && Float.is_nan b) || a = b

let test_add_identity =
  QCheck.Test.make ~name:"0 + e = e" ~count:1000 arb_expr
    (fun e -> same_float (eval (Add (Num 0.0, e))) (eval e))

let test_mul_identity =
  QCheck.Test.make ~name:"1 * e = e" ~count:1000 arb_expr
    (fun e -> same_float (eval (Mul (Num 1.0, e))) (eval e))

let _ = QCheck_runner.run_tests ~colors:false
          [test_add_identity; test_mul_identity]  (* = 0 *)
```

- The trap: `nan = nan` is `false`, and half our trees are NaN.
- `same_float`: two NaNs *agree*
  - the corner is tested, not skipped.

:::

:::slide

## Property 3: distributivity, approximately

```ocaml
let test_distributes_approx =
  QCheck.Test.make
    ~name:"Mul distributes over Add (approx)" ~count:1000
    QCheck.(triple arb_expr arb_expr arb_expr)
    (fun (a, b, c) ->
       let lhs = eval (Mul (a, Add (b, c))) in
       let rhs = eval (Add (Mul (a, b), Mul (a, c))) in
       not (Float.is_finite lhs && Float.is_finite rhs)
       || (let denom = max (abs_float lhs) (abs_float rhs) in
           abs_float (lhs -. rhs) <= 1e-6 *. denom +. 1e-9))

let _ = QCheck_runner.run_tests ~colors:false [test_distributes_approx]  (* = 0 *)
```

- Exact equality would fail: two differently-rounded routes.
- The implication: finite routes only, false for infinities.

:::

## Part 4: a deliberately buggy implementation

Suppose someone "refactors" `eval` and introduces a bug. The
classic version of this is: they confuse left and right operand
in `Sub`:

```ocaml
let rec bad_eval = function
  | Num n      -> n
  | Add (a, b) -> bad_eval a +. bad_eval b
  | Sub (a, b) -> bad_eval b -. bad_eval a    (* SWAPPED! *)
  | Mul (a, b) -> bad_eval a *. bad_eval b
  | Div (a, b) -> bad_eval a /. bad_eval b

let _ = bad_eval (Sub (Num 2.0, Num 3.0))  (* = 1., should be -1. *)
```

A single character changed: `bad_eval b -. bad_eval a` instead of
`bad_eval a -. bad_eval b`. The function still type-checks. All
the leaves still work. `Add`, `Mul`, `Div` are unaffected. Only
`Sub` is wrong. This is the opening lecture's well-typed-but-wrong
function, met in the wild: the type `expr -> float` is satisfied;
the specification is not.

How does our test suite catch this?

**The OUnit2 cases catch it twice**: on `sub` itself, and on
`nested`, whose tree contains a `Sub` node. Run against the
buggy evaluator, the report reads (log-file lines elided):

```text
..F..F.
==============================================================
Error: expr evaluator:1:binary operators:1:sub.

expected: -1. but got: 1.
--------------------------------------------------------------
==============================================================
Error: expr evaluator:2:nested.

expected: 10.5 but got: -10.5
--------------------------------------------------------------
Ran: 7 tests in: 0.11 seconds.
FAILED: Cases: 7 Tried: 7 Errors: 0 Failures: 2 ...
```

The most specific failing case is where to look: `nested` fails
only because it contains a `Sub`, while `sub` isolates the
operator. The message names the expected and actual values, and
the diagnosis is immediate: `Sub` is producing the negative of
the right answer, so the arguments are probably swapped.

**The QCheck properties are all blind to it.** Run the three
properties above with `bad_eval` in place of `eval`: all pass,
ten thousand times over. Termination does not care what `Sub`
returns. The identity laws never build a `Sub` node of their
own, and inside the generated `e` the swap happens identically
on both sides of the comparison. Distributivity compares two
arrangements of the *same* evaluator against itself, so a bug
that is consistent on both routes slips through. A property
that never pins the result to something *outside* the function
under test cannot see this bug.

Suppose we try a Sub-specific property:

```ocaml
let test_sub_antisymmetric =
  QCheck.Test.make
    ~name:"Sub (a, b) = -(Sub (b, a))"
    QCheck.(pair arb_expr arb_expr)
    (fun (a, b) ->
       same_float (bad_eval (Sub (a, b))) (-. (bad_eval (Sub (b, a)))))

let _ = QCheck_runner.run_tests ~colors:false
          [test_sub_antisymmetric]  (* = 0: it passes, on the BUGGY eval *)
```

The mathematical fact: `a - b = -(b - a)`. (The `same_float` is
the usual NaN-aware agreement; the blindness we are about to see
has nothing to do with NaN.) The correct `eval` satisfies this.
The buggy one, as the cell above shows, does too. Surprise: this property *does not catch the bug*, because
the bug *swaps the operands of Sub*, and the property is
symmetric under exactly that swap. This is a real and useful
warning sign: a property whose *form* is symmetric in the
inputs cannot catch a bug that swaps those inputs.

A better property *anchors* the result to a reference outside
the evaluator: the OCaml `-.` operator itself. Aim it at the
buggy evaluator and run it:

```ocaml
let test_sub_matches_minus =
  QCheck.Test.make
    ~name:"Sub (Num a, Num b) evaluates to a -. b"
    QCheck.(pair (float_range (-100.0) 100.0) (float_range (-100.0) 100.0))
    (fun (a, b) -> bad_eval (Sub (Num a, Num b)) = a -. b)

let _ = QCheck_runner.run_tests ~colors:false
          [test_sub_matches_minus]  (* = 1, it FAILS *)
```

The failure report names a shrunk pair, typically `(0., 1.)` or
something equally minimal (the exact pair and the number of
shrink steps vary with the seed): the smallest asymmetric pair
the shrinker can find. Read it against the anchor: the property
expected `0. -. 1. = -1.`; the buggy evaluator computed
`1. -. 0. = 1.`. Two numbers and a subtract; the bug is
obvious. In the final suite, the same property is written with
`eval`, where it passes; here we aimed it at `bad_eval` to
watch it work.

:::slide

## The planted bug

```ocaml
let rec bad_eval = function
  | Num n      -> n
  | Add (a, b) -> bad_eval a +. bad_eval b
  | Sub (a, b) -> bad_eval b -. bad_eval a    (* SWAPPED! *)
  | Mul (a, b) -> bad_eval a *. bad_eval b
  | Div (a, b) -> bad_eval a /. bad_eval b

let _ = bad_eval (Sub (Num 2.0, Num 3.0))  (* = 1., should be -1. *)
```

- Type-checks; only `Sub` is wrong.
- OUnit2: `sub` and `nested` fail, five other cases pass.
- All three QCheck properties pass: they never pin `Sub` to
  anything outside the evaluator.

:::

:::slide

## The anchored property catches it

```ocaml
let test_sub_matches_minus =
  QCheck.Test.make ~name:"Sub (Num a, Num b) evaluates to a -. b"
    QCheck.(pair (float_range (-100.0) 100.0) (float_range (-100.0) 100.0))
    (fun (a, b) -> bad_eval (Sub (Num a, Num b)) = a -. b)

let _ = QCheck_runner.run_tests ~colors:false
          [test_sub_matches_minus]  (* = 1, it FAILS *)
```

- The *symmetric* `Sub (a, b) = -(Sub (b, a))` passes on the
  buggy eval: blind under the very swap it should catch.
- The *anchored* one (pin to `-.`) fails, shrunk to a pair
  like `(0., 1.)`.

:::

## The lesson: choose properties that distinguish bugs

The reason the antisymmetric property `Sub (a, b) = -(Sub (b, a))`
did not catch the bug is illustrative. If a property is invariant
under the *transformation that the bug performs*, the property is
blind to that bug. Swapping operands of `Sub` is the bug; the
property's left and right sides swap operands of `Sub`; the
property is invariant under that swap; therefore the property
holds even on the buggy code.

The general rule, and one of the deeper craft-skills of PBT:
*each property should break some specific implementation that you
care about ruling out.* A good test of a property is to ask, "what
bug would this property catch?" If the answer is "any function
satisfying the right type", the property is too weak. (The PBT
lecture called those *tautological*; the swapped-operand episode
shows a property can also be tautological *relative to a
particular bug* while looking substantive.)

Properties anchored against an external reference (the
`-.` operator, in our case) are the strongest. They are also the
most demanding to write, because you have to have a reference at
hand. For many functions you do: `List.length`, `( + )`, `( *. )`,
`String.equal` are all in the standard library and serve as
references for the things they implement. If this rings a bell,
it should: anchoring is the model-based testing idea in
miniature. There the reference was a whole module, a plain-list
queue standing oracle for the two-list one; here it is a single
stdlib operator. Same move, smaller scale.

:::slide

## The PBT craft

- If a property is *invariant under the bug's transformation*,
  the property will not catch the bug.
- The strongest properties are *anchored*: pin to an external
  reference (`-.`, `( + )`, `List.length`, ...).
  - the model-based lecture's reference idea, in miniature.
- Ask: "what bug would this property catch?" If "none specific",
  the property is too weak.

:::

## Part 5: putting it together

The complete test file, all parts assembled:

```text
open OUnit2

type expr =
  | Num of float
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr

let rec eval = function
  | Num n      -> n
  | Add (a, b) -> eval a +. eval b
  | Sub (a, b) -> eval a -. eval b
  | Mul (a, b) -> eval a *. eval b
  | Div (a, b) -> eval a /. eval b

(* --- OUnit2 unit tests --- *)
let test_num_leaf _ =
  assert_equal ~printer:string_of_float 3.0 (eval (Num 3.0))

let test_add _ =
  assert_equal ~printer:string_of_float 5.0
    (eval (Add (Num 2.0, Num 3.0)))

let test_sub _ =
  assert_equal ~printer:string_of_float (-1.0)
    (eval (Sub (Num 2.0, Num 3.0)))

let test_mul _ =
  assert_equal ~printer:string_of_float 6.0
    (eval (Mul (Num 2.0, Num 3.0)))

let test_div _ =
  assert_equal ~printer:string_of_float 0.5
    (eval (Div (Num 1.0, Num 2.0)))

let test_nested _ =
  let e = Mul (Add (Num 1.0, Num 2.0), Sub (Num 4.0, Num 0.5)) in
  assert_equal ~printer:string_of_float 10.5 (eval e)

let test_div_by_zero _ =
  assert_equal ~printer:string_of_float infinity
    (eval (Div (Num 1.0, Num 0.0)))

let ounit_suite =
  "expr evaluator (ounit2)" >::: [
    "leaf"   >:: test_num_leaf;
    "add"    >:: test_add;
    "sub"    >:: test_sub;
    "mul"    >:: test_mul;
    "div"    >:: test_div;
    "nested" >:: test_nested;
    "div by zero" >:: test_div_by_zero;
  ]

(* --- QCheck properties --- *)
let gen_leaf =
  QCheck.Gen.(oneof_weighted [
    (8, map (fun n -> Num n) (float_range (-100.0) 100.0));
    (1, return (Num infinity));
    (1, return (Num nan));
  ])

let rec gen_expr depth =
  let open QCheck.Gen in
  if depth <= 0 then gen_leaf
  else
    let sub = gen_expr (depth - 1) in
    oneof [
      gen_leaf;
      map2 (fun a b -> Add (a, b)) sub sub;
      map2 (fun a b -> Sub (a, b)) sub sub;
      map2 (fun a b -> Mul (a, b)) sub sub;
      map2 (fun a b -> Div (a, b)) sub sub;
    ]

let same_float a b =
  (Float.is_nan a && Float.is_nan b) || a = b

let rec expr_str = function
  | Num n -> Printf.sprintf "%g" n
  | Add (a, b) -> "(" ^ expr_str a ^ " + " ^ expr_str b ^ ")"
  | Sub (a, b) -> "(" ^ expr_str a ^ " - " ^ expr_str b ^ ")"
  | Mul (a, b) -> "(" ^ expr_str a ^ " * " ^ expr_str b ^ ")"
  | Div (a, b) -> "(" ^ expr_str a ^ " / " ^ expr_str b ^ ")"

let arb_expr = QCheck.make ~print:expr_str (gen_expr 4)

let qcheck_tests = [
  QCheck.Test.make
    ~name:"eval terminates"
    arb_expr
    (fun e -> let _ : float = eval e in true);

  QCheck.Test.make
    ~name:"0 + e = e"
    arb_expr
    (fun e -> same_float (eval (Add (Num 0.0, e))) (eval e));

  QCheck.Test.make
    ~name:"Sub matches -."
    QCheck.(pair (float_range (-100.0) 100.0)
                 (float_range (-100.0) 100.0))
    (fun (a, b) -> eval (Sub (Num a, Num b)) = a -. b);
]

(* --- entry point ---
   Illustrative only. `run_test_tt_main` calls `exit` after the
   OUnit2 run, so the QCheck call below never fires. In a real
   project, split the two suites into separate test executables
   (see the dune note that follows). *)
let () =
  run_test_tt_main ounit_suite;
  QCheck_runner.run_tests_main qcheck_tests
```

Two suites, one entry point. `run_test_tt_main` exits after
running OUnit2, so the QCheck call below it never actually
fires. In a real project, you split them: one test executable
per suite, each with its own `(test ...)` stanza in `dune`. For
this tutorial we keep them adjacent in one file to highlight
the contrast between specific OUnit2 cases and quantified
QCheck properties.

And the corresponding `dune`:

```dune
(test
 (name test_expr)
 (libraries ounit2 qcheck))
```

Two library dependencies, one test executable, one `dune runtest`
that exercises everything.

## Activity

:::quiz code id=M09-L07-q1
Extend the AST with unary negation. The cell below is
self-contained (it redefines `expr`, so everything the property
needs is rebound here). Three steps:

1. Add the missing `Neg` clause to `eval`.
2. Add a `Neg` case to `gen_expr`, so random trees contain
   negations: one `map` over the `sub` generator.
3. Write the anchored property `test_neg_anchored`: for every
   generated `e`, `eval (Neg e)` agrees with `-. (eval e)`.
   Compare with `same_float` (NaN trees are common), and build
   the `arbitrary` with `QCheck.make (gen_expr 4)`.

The anchor is OCaml's own `-.`, the same move that caught the
swapped `Sub`. Negation is *exact* in IEEE-754 (it just flips
the sign bit, even on NaN), so agreement should hold on every
generated tree, the special values included.

```ocaml
type expr =
  | Num of float
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | Neg of expr                                  (* new *)

let rec eval = function
  | Num n      -> n
  | Add (a, b) -> eval a +. eval b
  | Sub (a, b) -> eval a -. eval b
  | Mul (a, b) -> eval a *. eval b
  | Div (a, b) -> eval a /. eval b
  | Neg e      -> failwith "TODO"

let gen_leaf =
  QCheck.Gen.(oneof_weighted [
    (8, map (fun n -> Num n) (float_range (-100.0) 100.0));
    (1, return (Num infinity));
    (1, return (Num nan));
  ])

let rec gen_expr depth =
  let open QCheck.Gen in
  if depth <= 0 then gen_leaf
  else
    let sub = gen_expr (depth - 1) in
    oneof [
      gen_leaf;
      map2 (fun a b -> Add (a, b)) sub sub;
      map2 (fun a b -> Sub (a, b)) sub sub;
      map2 (fun a b -> Mul (a, b)) sub sub;
      map2 (fun a b -> Div (a, b)) sub sub;
      (* TODO: a Neg case *)
    ]

let same_float a b =
  (Float.is_nan a && Float.is_nan b) || a = b

let test_neg_anchored =
  QCheck.Test.make
    ~name:"eval (Neg e) = -. (eval e)"
    ~count:1000
    (QCheck.make (gen_expr 4))
    (fun _e -> failwith "TODO: same_float (eval (Neg e)) (-. (eval e))")
```

```ocaml skip
let rec contains_neg = function
  | Num _ -> false
  | Neg _ -> true
  | Add (a, b) | Sub (a, b) | Mul (a, b) | Div (a, b) ->
    contains_neg a || contains_neg b

let () =
  assert (eval (Neg (Num 3.0)) = -3.0);
  assert (eval (Neg (Neg (Num 2.5))) = 2.5);
  assert (eval (Add (Num 1.0, Neg (Num 4.0))) = -3.0);
  (* the generator must actually produce Neg nodes *)
  let samples = QCheck.Gen.generate ~n:100 (gen_expr 4) in
  assert (List.exists contains_neg samples);
  (* and the anchored property must pass *)
  let errs = QCheck_runner.run_tests ~colors:false [test_neg_anchored] in
  assert (errs = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type expr =
  | Num of float
  | Add of expr * expr
  | Sub of expr * expr
  | Mul of expr * expr
  | Div of expr * expr
  | Neg of expr

let rec eval = function
  | Num n      -> n
  | Add (a, b) -> eval a +. eval b
  | Sub (a, b) -> eval a -. eval b
  | Mul (a, b) -> eval a *. eval b
  | Div (a, b) -> eval a /. eval b
  | Neg e      -> -. (eval e)

let gen_leaf =
  QCheck.Gen.(oneof_weighted [
    (8, map (fun n -> Num n) (float_range (-100.0) 100.0));
    (1, return (Num infinity));
    (1, return (Num nan));
  ])

let rec gen_expr depth =
  let open QCheck.Gen in
  if depth <= 0 then gen_leaf
  else
    let sub = gen_expr (depth - 1) in
    oneof [
      gen_leaf;
      map2 (fun a b -> Add (a, b)) sub sub;
      map2 (fun a b -> Sub (a, b)) sub sub;
      map2 (fun a b -> Mul (a, b)) sub sub;
      map2 (fun a b -> Div (a, b)) sub sub;
      map  (fun e -> Neg e) sub;
    ]

let same_float a b =
  (Float.is_nan a && Float.is_nan b) || a = b

let test_neg_anchored =
  QCheck.Test.make
    ~name:"eval (Neg e) = -. (eval e)"
    ~count:1000
    (QCheck.make (gen_expr 4))
    (fun e -> same_float (eval (Neg e)) (-. (eval e)))

let _ = QCheck_runner.run_tests ~colors:false [test_neg_anchored]  (* = 0 *)
```

Three small additions, each in the mould the tutorial built:
one clause in the evaluator (`Neg` has a single sub-expression,
so no left/right to confuse), one unary case in the generator
(only one `sub`, against the binary cases' two), and one
anchored property. Negation in IEEE-754 just flips the sign
bit, exactly, even on NaN; with `same_float` saying that two
NaNs agree, the property holds on every generated tree, special
values included.

:::

:::quiz mcq id=M09-L07-q2
A colleague writes a single QCheck property for an option-returning
`safe_div : int -> int -> int option`:

```text
let test = QCheck.Test.make QCheck.(pair int int)
  (fun (a, b) ->
     match safe_div a b with
     | Some q -> q * b + (a mod b) = a   (* division law *)
     | None -> b = 0)
```

The property passes on 1000 random inputs. Why is this a *stronger*
test than a hand-written unit test that just checks
`safe_div 10 2 = Some 5`?

- [ ] Because PBT proves correctness; unit tests merely sample.
- [x] Because the property exercises *every* generated `(a, b)`
  pair, including unusual ones (negatives, zero divisors,
  overflow-adjacent), and the property simultaneously checks the
  arithmetic law AND the contract that `None` means "divisor was
  zero".
- [ ] Because OCaml's type system makes properties redundant.
- [ ] Because PBT runs faster than unit tests.

**Why:** PBT *generates* inputs the author would not think to
write, including negatives, zero divisors, and large values. The
property checks two things at once: when `safe_div` returns
`Some q`, the result obeys the division law; when it returns
`None`, the contract guarantees the divisor was zero. A unit
test checks one pair `(10, 2)` and trusts that the rest of the
function behaves analogously. PBT does *not* prove correctness
(1000 cases is still a sample), but it is a much stronger sample
than one case can be.
:::

## Common pitfalls

**Pitfall 1: properties that hold of the bug.** Discussed above.
The antisymmetric `Sub` property satisfies the buggy
implementation; an anchored property does not. Anchor when you
can.

**Pitfall 2: float equality in properties.** `nan <> nan`,
`0.1 +. 0.2 <> 0.3`. Use approximate comparison
(`abs_float (a -. b) < eps`) when working with floats, or
restrict the generator to integers when you do not want to
think about it.

**Pitfall 3: generators that produce mostly trivial inputs.**
A generator that almost always returns `Num 0.0` will not exercise
much. Use `QCheck.oneof` to balance leaves and internal nodes.

**Pitfall 4: missing edge cases in the manual suite.** Unit
tests are still the place for *specific known behaviours*. If
the spec says "the empty list returns 0", a unit test that
checks exactly that is more honest than a property which sort-of
implies it.

**Pitfall 5: trusting the test suite to be exhaustive.** Even
when OUnit2 and QCheck agree, you have *not* proved the function
correct. You have a strong sample. Trust it; do not deify it.

## What you should be able to do now

After this module:

- Articulate why a well-typed program can still be wrong, and
  what testing adds on top of types
  ([L01](M09-L01-why-test-typed-code.html)).
- Write a function's contract (returns, requires, raises,
  examples) and a data abstraction's AF / RI / `rep_ok`
  ([L02](M09-L02-specifications-invariants.html)).
- Design test cases deliberately: boundaries and partitions
  from the spec, paths and coverage from the code
  ([L03](M09-L03-test-design.html)).
- Write OUnit2 unit tests for any module of your own:
  `assert_equal`, `assert_raises`, `>::`, `TestList`, `dune`
  integration ([L04](M09-L04-unit-testing.html)).
- Write QCheck properties for invariants of a function:
  generators, properties, shrinking
  ([L05](M09-L05-property-based-testing.html)).
- Test stateful data structures against a reference
  implementation using sequences of operations
  ([L06](M09-L06-model-based-testing.html)).
- Build a generator for a recursive type of your own, with a
  depth bound and a `QCheck.make` wrap (this lecture).
- Combine the toolkit on a real function: spec-derived cases,
  an anchored property, and a deliberately introduced bug
  caught and shrunk (this lecture).

The next module, [Memory safety and security](M10-L01-memory-safety-and-security.html),
moves in the other direction: from what tests catch to what
*types and the runtime* catch. We have argued that types and tests
are complementary; M10 makes the type side precise in the
context of memory safety, with security as the application.

:::slide

## What you can do now

- Explain why a well-typed program can still be wrong (L1).
- Write contracts and rep invariants (L2).
- Design cases: black-box boundaries, glass-box paths,
  coverage (L3).
- Write OUnit2 unit tests (L4).
- Write QCheck properties for invariants (L5).
- Apply model-based testing to stateful code (L6).
- Combine the toolkit, plus a custom generator and an anchored
  property, on a real function (this lecture).

Next module: M10 on memory safety. Tests catch behaviour;
*types and the runtime* catch the next layer.

:::

## Reading

- **Cornell CS3110**, *Testing, Debugging, and Specifications*
  (chapter spanning unit testing, randomised testing, and
  specifications):
  <https://cs3110.github.io/textbook/chapters/correctness/test_debug.html>
- **QCheck README and tutorial**:
  <https://github.com/c-cube/qcheck>
- **OUnit2 README and API documentation**:
  <https://github.com/gildor478/ounit>
- **Real World OCaml**, *Testing*:
  <https://dev.realworldocaml.org/testing.html>

## Sources

This tutorial's prose, worked examples, and quizzes are original
to this course. The `expr` AST and `eval` function are this
tutorial's own, a float-valued variant of
[the pattern-matching tutorial's interpreter](M05-L06-tutorial.html),
itself original. The
deliberate-bug pattern (swapping operands of `Sub`) is folklore
in the PBT community, presented here in our own words. Cornell
CS3110's testing chapter is the conceptual antecedent for the
unit-and-property structure of this lecture; its prose is
CC BY-NC-ND licensed and has not been derivatively reused. The
QCheck library (Simon Cruanes and contributors) and OUnit2
(Sylvain Le Gall and contributors) are linked above and used
through their public APIs. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
