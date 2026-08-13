---
title: "`let` bindings and shadowing"
lecture_no: 2
week: 2
duration_target_min: 22
concepts: [let bindings, let-in expressions, scope, shadowing, immutability, inference rules]
keywords: [OCaml, let, let-in, scope, shadowing, immutability, bindings, semantics]
activity_question: "What does [let x = 10 in let y = x in let x = x + 5 in x + y] evaluate to? Trace the bindings; remember that `y` binds to a value, not to the name `x`."
think_about_this: "If [let x = 1; let x = 2] does not mutate, where does the value [1] go? Can any code reach it after the second binding?"
reading:
  - title: "Cornell CS3110, Let expressions"
    url: https://cs3110.github.io/textbook/chapters/basics/expressions.html
---

# `let` bindings and shadowing


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">`let` bindings and shadowing</h2>
<p class="title-slide-label">Module 2 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: `let` bindings

- Literals gave us values; this lecture gives us *names*.
- Two forms of `let`, same keyword, different scope:
  - `let x = e1 in e2`: local to an expression.
  - `let x = e`: top-level definition, visible to the rest of the file.
- Typing rule (static) and evaluation rule (dynamic) for each.
- *Shadowing*: reusing a name introduces a new binding, not mutation.
- Almost every line of OCaml has a `let` in it.

:::

The [previous lecture](M02-L01-literals.html) introduced literals:
the smallest building blocks of a program. This lecture introduces
the next layer up: *names*. Naming a value lets you compute it once
and use it many times; naming an intermediate result lets you break
a long calculation into readable steps. Almost every line of OCaml
contains at least one `let` binding.

We will treat `let` carefully. OCaml has two related forms with the
same keyword but different scoping, and the differences matter. We
will write down their syntax, give the typing rule (static
semantics) and the evaluation rule (dynamic semantics) for each,
and then look at *shadowing*, the property that reusing a name
introduces a new binding rather than mutating an old one.

## Two forms of `let`

The two forms share the keyword `let` but differ in *scope*: how
far through the program the bound name is visible.

The **`let ... in` expression** introduces a name *local* to a
specific expression. Its abstract syntax is:

$$
\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2
$$

Here $x$ is the bound identifier, $e_1$ is the *binding expression*
that supplies the value, and $e_2$ is the *body* in which $x$ is in
scope. The whole `let ... in` form is itself an expression: it
denotes the value $e_2$ evaluates to.

```ocaml
let _ = let y = 5 in y + 5  (* = 10 *)
```

The toplevel reports `int = 10`. The name `y` is bound to `5` inside
the body `y + 5`. Outside the `let ... in`, `y` is no longer in
scope.

:::slide

## `let ... in` expression

$$
\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2
$$

- $x$: the bound identifier.
- $e_1$: the binding expression (value to bind).
- $e_2$: the body (where $x$ is in scope).
- The whole form is *itself* an expression.

```ocaml
let _ = let y = 5 in y + 5
```

`int = 10`. Outside the `in`, `y` does not exist.

:::

The **top-level `let`** introduces a name visible to the rest of
the file:

$$
\mathtt{let}\ x = e
$$

Read this as "let $x = e$ in *the rest of the program*". The body
is everything that follows in the same file (or in the toplevel
session). Top-level `let`s are sometimes called **definitions** to
emphasise that they bind a name into the program's namespace, not
into a local expression.

```ocaml
let a = "Hello"
let b = "World"
let c = a ^ " " ^ b
```

The toplevel reports `val c : string = "Hello World"`. Each
top-level `let` binding is in scope for every binding that follows.

:::slide

## Top-level `let` (a *definition*)

$$
\mathtt{let}\ x = e
$$

Read as "$\mathtt{let}\ x = e\ \mathtt{in}$ *the rest of the program*."

```ocaml
let a = "Hello"
let b = "World"
let c = a ^ " " ^ b
```

`val c : string = "Hello World"`. The names `a` and `b` stay in scope
for every later binding in the file.

:::

The two forms are deeply related. A top-level `let x = e` is, in
effect, the same as `let x = e in <the rest of the file>`. The
language gives the `in` part implicitly at the file level so you
don't have to keep nesting.

## Typing judgements

Before we write down what the type system says about `let`, we
need a notation for *what type an expression has*. Programming-
languages people write this with a colon:

$$
e : t
$$

read as "expression $e$ has type $t$". This is a *typing
judgement*: a statement *about* a piece of program text. Some
examples we have already seen:

- $5 : \mathtt{int}$
- $\mathtt{3.14} : \mathtt{float}$
- $\mathtt{"hello"} : \mathtt{string}$
- $\mathtt{true} : \mathtt{bool}$
- $(\mathtt{let}\ x = 5\ \mathtt{in}\ x + 5) : \mathtt{int}$

Each one is just a fact: the expression on the left has the type
on the right. The compiler's job, when it type-checks your
program, is to produce a judgement like this for every expression
in it.

:::slide

## Typing judgements

$$
e : t
$$

reads "expression $e$ has type $t$". Some judgements:

- $5 : \mathtt{int}$
- $\mathtt{"hello"} : \mathtt{string}$
- $(\mathtt{let}\ x = 5\ \mathtt{in}\ x + 5) : \mathtt{int}$

The compiler produces a judgement like this for every expression
it type-checks.

:::

## Inference rules

We rarely state typing judgements in isolation. Most of the time
we want to say: "*if* you know that these sub-expressions have
these types, *then* the bigger expression has this type." That is
exactly the job of an **inference rule**.

An inference rule has *premises* above a horizontal bar and a
*conclusion* below. Read it as "if every premise holds, then the
conclusion holds". The bar is shorthand for "implies".

Here is the inference rule that captures what `+` does to types:

$$
\dfrac{e_1 : \mathtt{int} \qquad e_2 : \mathtt{int}}
      {e_1 + e_2 : \mathtt{int}}
$$

Read top-to-bottom: *if* $e_1$ has type `int` *and* $e_2$ has type
`int`, *then* `e_1 + e_2` has type `int`. The whole type system is
a collection of such rules, one per language construct.

:::slide

## Inference rules

$$
\dfrac{\text{premise}_1 \qquad \text{premise}_2 \qquad \cdots
       \qquad \text{premise}_n}
      {\text{conclusion}}
$$

- Read as "if every premise holds, the conclusion holds".
- The horizontal bar is shorthand for "implies".

Example: the rule for integer `+`:

$$
\dfrac{e_1 : \mathtt{int} \qquad e_2 : \mathtt{int}}
      {e_1 + e_2 : \mathtt{int}}
$$

:::

## A typing rule for `let`

The `let ... in` rule is slightly more interesting than `+`,
because the body $e_2$ is type-checked *under an assumption*: it
gets to use the name $x$, which has the type the bound expression
$e_1$ produced. We write that assumption with a turnstile,
$\vdash$. The judgement $x : t_1 \vdash e_2 : t_2$ reads:
"*assuming* $x$ has type $t_1$, the expression $e_2$ has type
$t_2$."

With that, the typing rule for `let ... in` is:

$$
\dfrac{e_1 : t_1 \qquad x : t_1 \vdash e_2 : t_2}
      {(\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2) : t_2}
$$

Read top-to-bottom: *if* $e_1$ has type $t_1$ *and* $e_2$ has type
$t_2$ *under the assumption that $x : t_1$*, *then* the whole `let`
has type $t_2$. The type of the binding form is the type of its
body. The bound expression's type flows in through the assumption
about $x$.

:::slide

## Typing rule for `let ... in` (static semantics)

$$
\dfrac{e_1 : t_1 \qquad x : t_1 \vdash e_2 : t_2}
      {(\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2) : t_2}
$$

- **Static semantics**: this rule produces a *type*, not a value.
- $\vdash$ ("turnstile") reads as "assuming".
- The body's typing uses the assumption $x : t_1$.
- The whole `let` has the type of its **body** ($t_2$).
- Dynamic semantics (how it *evaluates*) comes next.

:::

For our example `let y = 5 in y + 5`: $e_1$ is `5`, which has type
`int`, so $t_1$ is `int`. Under the assumption $y : \mathtt{int}$,
the body `y + 5` has type `int` (by the rule for `+`). So $t_2$ is
`int`, and the whole expression has type `int`. The typing rule
reproduces what the toplevel told us.

## Dynamic semantics: how `let` evaluates

Static semantics gives us the *type* of an expression. *Dynamic*
semantics gives us its *value*. We use the same inference-rule
shape, but the judgement is now about evaluation: $e \to v$ reads
"$e$ evaluates to $v$". And $e_2[x := v]$ means "the result of
substituting $v$ for every free occurrence of $x$ in $e_2$".

The evaluation rule for `let ... in` is:

$$
\dfrac{e_1 \to v_1 \qquad e_2[x := v_1] \to v_2}
      {(\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2) \to v_2}
$$

Read: evaluate $e_1$ first to a value $v_1$. Substitute $v_1$ for
every $x$ inside $e_2$. Evaluate the resulting expression to $v_2$.
That $v_2$ is the value of the whole `let`.

This *substitution model* is a useful mental model for OCaml. To
work out what an expression evaluates to, you can substitute the
value into the body and re-evaluate. The real implementation does
not actually copy values around; it maintains an environment
mapping names to values. But for reasoning about what a program
*means*, substitution is the cleaner picture.

:::slide

## Evaluation rule for `let ... in` (dynamic semantics)

$$
\dfrac{e_1 \to v_1 \qquad e_2[x := v_1] \to v_2}
      {(\mathtt{let}\ x = e_1\ \mathtt{in}\ e_2) \to v_2}
$$

- **Dynamic semantics**: this rule produces a *value*, not a type.
- $e \to v$ reads "$e$ evaluates to $v$".
- Evaluate $e_1$ first; substitute $v_1$ for $x$ in $e_2$;
  evaluate the result.
- The *substitution model*. The implementation uses an environment,
  but the meaning is the same.

:::

## Nesting `let ... in`

Because `let ... in` is an expression, the body $e_2$ can itself
be another `let ... in`. Chain them to compute intermediate
values:

```ocaml
let _ =
  let x = 5 in
  let y = 10 in
  x + y  (* = 15 *)
```

Result: `int = 15`. The parsing is right-associative: the chain
above is `let x = 5 in (let y = 10 in (x + y))`. Each binding is
in scope for the rest of the chain.

:::slide

## Nested `let ... in`

```ocaml
let _ =
  let x = 5 in
  let y = 10 in
  x + y
```

`int = 15`. Parsed right-associatively:

$$
\mathtt{let}\ x = 5\ \mathtt{in}\ (\mathtt{let}\ y = 10\ \mathtt{in}\ x + y)
$$

:::

Trace through the evaluation rule for this expression, applying
substitution at each step. The outer `let` is the first to fire:
$e_1$ is `5`, $e_2$ is `let y = 10 in x + y`. Evaluating $e_1$ gives
`5`; the rule substitutes `5` for `x` in $e_2$ and re-evaluates.
That gives us the inner `let`, where $e_1$ is `10`, $e_2$ is
`5 + y`. Evaluating $e_1$ gives `10`; substitute and we have
`5 + 10`, which evaluates to `15`.

Written as a sequence of substitution steps:

$$
\begin{aligned}
& \mathtt{let}\ x = 5\ \mathtt{in}\ (\mathtt{let}\ y = 10\ \mathtt{in}\ x + y) \\
\to\ & \mathtt{let}\ y = 10\ \mathtt{in}\ (5 + y) \qquad [x := 5] \\
\to\ & 5 + 10 \qquad [y := 10] \\
\to\ & 15
\end{aligned}
$$

Each $\to$ is one application of the `let` evaluation rule (the
$e_1 \to v_1$ premise resolves the bound expression; substitution
delivers the next state).

:::slide

## Tracing the substitution

$$
\begin{aligned}
& \mathtt{let}\ x = 5\ \mathtt{in}\ (\mathtt{let}\ y = 10\ \mathtt{in}\ x + y) \\
\to\ & \mathtt{let}\ y = 10\ \mathtt{in}\ (5 + y) \qquad [x := 5] \\
\to\ & 5 + 10 \qquad [y := 10] \\
\to\ & 15
\end{aligned}
$$

Each $\to$ applies the `let` evaluation rule once: evaluate the
bound expression, substitute its value for the name in the body,
evaluate the result.

:::

You can also let-bind an entire `let`. The right-hand side of a
binding is any expression, so:

```ocaml
let _ =
  let x = 5 in
  let y =
    let z = 10 in z + z
  in
  x + y  (* = 25 *)
```

Result: `int = 25`. The inner `let z = 10 in z + z` evaluates to
`20`, which becomes the value bound to `y`. Then `x + y` is `25`.

## Shadowing

OCaml lets you reuse a name in a new binding without mutating
anything. This is called **shadowing**. Here is the classic
example:

```ocaml
let x = 1
let x = x + 1
let x = x * 10
```

After three lines, the name `x` refers to `20`.

Read carefully. On line 2, on the *right-hand side* of the `=`,
`x` still means "the first `x` (which is `1`)". So the right-hand
side evaluates to `2`. After the line, the name `x` refers to the
new binding, where `x = 2`. The original binding of `x = 1` is
still there, just no longer reachable by typing `x`.

On line 3, on the right-hand side, `x` means "the most recently
bound `x`", which is `2`. So the right-hand side is `20`. After
the line, `x = 20` and the previous two bindings live in memory
where no name reaches them.

This is *not* mutation. There is no single cell named `x` that
holds successive values. There are three separate values, all
called `x` for the duration of their existence, with the most
recent one being the one you reach when you type `x`.

Shadowing works for `let ... in` too:

```ocaml
let _ =
  let x = 5 in
  let x = x + 5 in
  x  (* = 10 *)
```

Result: `int = 10`. The right-hand side of the inner `let x = x +
5` reads the outer `x` (which is `5`), computes `10`, and binds
that to a *fresh* `x` that hides the outer one for the rest of the
expression. Two `x` slots: the outer one is read on the RHS, the
inner one is the new binding the body sees.

:::slide

## Shadowing in `let ... in`

```ocaml
let _ =
  let x = 5 in
  let x = x + 5 in
  x
```

`int = 10`. The RHS `x + 5` reads the outer `x = 5`; the result
`10` binds a fresh inner `x` that hides the outer for the body.
**Two separate $x$ slots, no mutation.**

:::

## Why shadowing differs from mutation: closures see the old value

The clearest demonstration that shadowing is not mutation comes
from [closures](M03-L01-functions-as-values.html#a-function-value-remembers-its-environment),
which we will study in Module 3 but can already use in a simple
example. The `()` in `f ()` is the unit value, which we met in
[the hello-world lecture](M01-L04-hello-world.html#what-is-unit):
`f` is defined to take no useful argument, and we call it by
passing the placeholder `()`. Full treatment of unit-taking
functions comes in Module 3.

```ocaml
let x = 1
let f () = x
let x = 99
let _ = f ()
```

What does the last line evaluate to?

:::slide

## Shadowing is not mutation

```ocaml
let x = 1
let f () = x
let x = 99
let _ = f ()
```

What does `f ()` return? `1`.

- `f` captured the **value** `1` when defined, not the name `x`.
- Later `let x = 99` does **not** change what `f` sees.
- If `let` were mutation, `f` would return `99`.

:::

The answer is `1`. Read carefully: when `f` was defined, `x` was
`1`. The function body refers to `x`. OCaml does *not* re-look-up
the name `x` every time `f` is called; it captured the *value* `x
= 1` when `f` was defined. After `let x = 99`, the name `x` now
refers to a different binding, but `f` is unaffected; it still
returns what `x` meant when `f` was defined.

This is the property of *closures*: a function body, at the moment
of definition, captures the bindings that were in scope. We will
see closures in much more detail in
[Module 3](M03-L01-functions-as-values.html#a-function-value-remembers-its-environment).
The key fact for this lecture: the *value* gets captured, not "the
current meaning of the name."

In a language where `let` actually mutates a cell, the same code
would produce different behaviour. Some languages do work that way
(Python is closer to this model: a closure captures a *reference*
to the variable, not its value, so reassignment is visible through
the closure). OCaml's choice (capture the value) is what people
mean by *static scoping with value capture*: it is more
predictable, easier to reason about, and matches what mathematical
functions do.

## Scope: outer versus inner

When a local `let ... in` shadows an outer binding, the inner
binding is in scope only inside its `in` expression. Outside, the
outer binding is restored.

```ocaml
let x = 100

let _ =
  let x = 1 in
  x  (* = 1 *)

let _ = x  (* = 100 *)
```

The first `let _ = ...` evaluates to `1`: inside the expression,
the local `x` shadows the outer one. The second `let _ = x`
evaluates to `100`: the local `x` is out of scope, and the
top-level binding `x = 100` is what's reachable.

:::slide

## Scope: outer vs inner

```ocaml
let x = 100

let _ =
  let x = 1 in
  x

let _ = x
```

- First `_` is `1`: inner `x` shadows for the body only.
- Second `_` is `100`: outer `x` restored after the `in`.

Same shape as nested scopes in C / Java.

:::

## Idiom: shadowing for step-by-step transformations

A common idiom is to transform a value through several steps and
rebind the same name at each step. This reads top-to-bottom like
a procedure, but it is a single expression with three nested
`let ... in`s:

```ocaml
let _ =
  let s = "  Hello World  " in
  let s = String.trim s in
  let s = String.lowercase_ascii s in
  s  (* = "hello world" *)
```

Result: `string = "hello world"`. Each `let s = ... in` introduces
a new binding of `s`, scoped to the rest of the chain. The
right-hand sides reference the *previous* binding of `s` (because
that is the meaning of `s` at the moment the right-hand side is
evaluated).

You can name each step descriptively instead of shadowing:

```ocaml
let _ =
  let raw      = "  Hello World  " in
  let trimmed  = String.trim raw in
  let lowered  = String.lowercase_ascii trimmed in
  lowered  (* = "hello world" *)
```

Same computation; three distinct names. Whether you prefer
shadowing or distinct names is taste. The shadowing version
emphasises "this is one value being transformed"; the descriptive
version names what each intermediate is.

## Underscore: "I don't care about the name"

The pattern `_` matches any value and discards it. You can use it
in a `let` binding when you want to evaluate something for its
side effect (or to make the toplevel print the result) but don't
need to bind a name.

```ocaml
let _ = print_endline "hi"
let _ = 3 + 4  (* = 7 *)
```

:::slide

## Underscore: "I don't care about the name"

```ocaml
let _ = print_endline "hi"
let _ = 3 + 4  (* = 7 *)
```

- `_` matches any value and discards it.
- `let _ = print_endline ...`: side-effecting call; result is `()`.
- `let _ = 3 + 4`: toplevel prints, no binding kept.
- `let _name = ...`: bind but don't warn me if unused.

:::

The first line is the same as `let () = print_endline "hi"`
except more permissive: `_` accepts any type, `()` only accepts
`unit`. In practice, prefer `let () = ...` for side-effecting
calls because it documents intent (and catches the case where you
forgot to return `unit`).

The second line is just for the toplevel: the value `7` gets
discarded, but the toplevel prints it (`- : int = 7`).

A related convention: a name starting with `_` (like `_unused`)
tells the compiler "I am binding this, but I might not use it; do
not warn me." This is useful in pattern matching when you want to
*name* something for documentation but never reference it. We will
see this in [Module 5](M05-L01-basic-patterns.html#versus-a-variable-name).

## Sequencing with `;`

The sequencing operator `;` appeared when we wrote
[the first programs](M01-L04-hello-world.html#sequencing-with):
`e1; e2` evaluates `e1`, discards its value, then evaluates `e2`,
and the whole expression takes the value of `e2`:

```ocaml
let _ = print_endline "hi"; 6  (* = 6 *)
```

The connection to `let`: `e1; e2` is *syntactic sugar* for
`let _ = e1 in e2`. Same evaluation, same result. The semicolon
is shorter, which is why you will see it in most real code.

Because the value of `e1` is thrown away, the compiler expects
`e1` to have type `unit`: a value with nothing useful to discard.
If it does not, OCaml issues a *warning*, not an error:

```ocaml skip
let _ = 5; 6
```

The compiler emits `Warning 10 [non-unit-statement]: this
expression should have type unit.` The program still compiles and
runs (and produces `6`); the warning is OCaml suggesting that
discarding an `int` is probably a mistake.

:::slide

## Sequencing with `;`

```ocaml
let _ = print_endline "hi"; 6
```

- `e1; e2`: evaluate `e1`, discard, then `e2`; result is `e2`.
- Sugar for `let _ = e1 in e2`.
- Prints `hi`, then evaluates to `int = 6`.

:::

:::slide

## `;`: the unit expectation

- `e1; e2` expects `e1` to have type `unit`.
- Not enforced; it's a **warning**, not an error.

```ocaml skip
let _ = 5; 6
```

- Compiles, evaluates to `int = 6`, but warns:
  `Warning 10 [non-unit-statement]: this expression should have
  type unit.`

:::

## Activity

:::slide

## Activity

Predict the value, then run:

```ocaml
let _ =
  let x = 10 in
  let y = x in
  let x = x + 5 in
  x + y
```

What does `x + y` evaluate to at the end?

:::

:::quiz mcq id=M02-L02-q2
What is the result of this nested expression?

```ocaml
let _ =
  let x = 10 in
  let y = x in
  let x = x + 5 in
  x + y
```

- [ ] `30`
- [x] `25`
- [ ] `20`
- [ ] `15`

**Why:** the first `let x = 10` binds `x` to `10`. The next line
`let y = x in ...` binds `y` to the current value of `x`, which is
`10`. *That binding does not refer back to the name `x` later*; it
captured the value `10`. The third line `let x = x + 5` shadows
the outer `x`; the new `x` is `15` (using the outer `x = 10` on
the right-hand side). The body `x + y` is `15 + 10 = 25`. The key
point: `y` is bound to the *value* `10`, not to "whatever `x`
means right now," so shadowing the outer `x` does not change `y`.
:::

:::slide

## Activity discussion

```ocaml
let _ =
  let x = 10 in
  let y = x in
  let x = x + 5 in
  x + y
```

- `let x = 10`: $x = 10$.
- `let y = x`: $y$ binds to the *value* `10`, not to the name `x`.
- `let x = x + 5`: shadows; new $x = 15$. $y$ still `10`.
- $x + y = 15 + 10 = 25$.

**Bindings capture values, not names.**

:::

An aside about garbage collection that's worth flagging in passing,
without dwelling on it (the full story comes in the secure-systems
half). In a language without GC (like C), reusing names by
shadowing-style allocation would leak: every "old `x`" you stopped
referring to would still take space. In OCaml the garbage collector
recognises that nothing reachable refers to the old `x` and frees
it. GC and immutability fit well together: GC makes immutability
cheap, and immutability makes GC's job easier (no in-place updates
means no need for write barriers in the common case). The full GC
story comes back in
[Module 10](M10-L02-memory-safety-by-construction.html) when we look at
how OCaml rules out the memory-safety bugs that haunt C.

## A small code challenge

:::quiz code id=M02-L02-q1
Define a function `four_step : int -> int` that, given input `n`,
returns `((n + 1) * 2 - 3) * 5`. Use shadowing (rebind a single
name `x` four times) so the code reads step by step.

```ocaml
let four_step n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (four_step 0  = ((0 + 1) * 2 - 3) * 5)  "four_step 0";
  check (four_step 5  = ((5 + 1) * 2 - 3) * 5)  "four_step 5";
  check (four_step 10 = ((10 + 1) * 2 - 3) * 5) "four_step 10";
  print_endline "all tests passed"
```
:::

:::solution

One sample solution:

```ocaml
let four_step n =
  let x = n + 1 in
  let x = x * 2 in
  let x = x - 3 in
  let x = x * 5 in
  x
```

Four shadowing bindings, each one transformation step. There is no
mutation. Each `let x = ... in` is a brand new binding.

:::

## What's next

We have written down both forms of `let`, their typing rules, and
their evaluation rules. The
[next lecture](M02-L03-types-and-inference.html) takes the static
side further: type inference, what it can and cannot do for you,
and when to write annotations. After that, lectures on
[operators](M02-L04-operators.html) and on
[`if`/`then`/`else`](M02-L05-if-expressions.html) complete Module
2. Then [Module 3](M03-L01-functions-as-values.html) starts on
functions.

:::slide

## What's next

- Next: **static vs dynamic semantics**, type inference.
- What it means to *catch errors before running the program*.
- Where OCaml lands on that spectrum.

:::

## Reading

- **Cornell CS3110**, *Let expressions*: thorough chapter on the
  same material with more worked examples:
  <https://cs3110.github.io/textbook/chapters/basics/expressions.html>
- **Real World OCaml**, *A Guided Tour* (let bindings section):
  <https://dev.realworldocaml.org/guided-tour.html>

## Sources

This lecture follows the structure of CS3100 lecture 3
(*Expressions*) at IIT Madras, including the formal-syntax and
inference-rule notation. The prose, worked examples, and quizzes
are original to this course; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
