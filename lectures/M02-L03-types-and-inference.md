---
title: "Static vs dynamic semantics, and type inference"
lecture_no: 3
week: 2
duration_target_min: 26
concepts: [static typing, dynamic typing, type errors, type inference, type signatures]
keywords: [OCaml, static typing, dynamic typing, type inference, Hindley-Milner, type errors]
activity_question: "Without running it, what type does OCaml infer for [let f x y = x +. y *. 2.0]? Why?"
think_about_this: "If OCaml can figure out the types itself, why would you ever write a type annotation? Where are annotations actually useful?"
reading:
  - title: "Cornell CS3110, Type checking"
    url: https://cs3110.github.io/textbook/chapters/basics/expressions.html
  - title: "Real World OCaml, Type inference"
    url: https://dev.realworldocaml.org/guided-tour.html
---

# Static vs dynamic semantics, and type inference


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Static vs dynamic semantics, and type inference</h2>
<p class="title-slide-label">Module 2 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Programming languages catch errors at different times. Some catch
them while you are compiling; some catch them while you are running;
some never catch them. Where a language draws this line shapes how
you write code in it. The earlier a bug is caught, the cheaper it is
to fix: a bug a compiler reports in milliseconds is cheaper than a
bug a test discovers in minutes, which is cheaper than a bug a user
discovers in production.

OCaml lands on the *more static* end of this spectrum: many of the
errors a Python or JavaScript program would discover at runtime, an
OCaml program rejects at compile time. The mechanism that makes this
work without forcing you to write types everywhere is *type
inference*, which we glimpsed in the [tour](M01-L03-ocaml-tour.html#type-inference)
and now develop in depth. Inference gives you the safety of a strong
type system without the syntactic burden of annotations. This
lecture covers both: the static-vs-dynamic distinction first, then
inference in detail.

By the end you should be able to look at any OCaml function you have
written and predict, without running it, what type the compiler will
infer. That skill is the difference between fighting OCaml's type
errors and reading them.

## Static versus dynamic: two kinds of meaning

Every expression in any programming language has two kinds of
meaning. The *static* meaning is what you can determine without
running the code: in OCaml, the most important static fact is the
expression's *type*. The *dynamic* meaning is what happens when you
execute the code: the *value* it produces (and any side effects on
the way).

```ocaml
let _ = 23 + 45  (* = 68 *)
```

- Static semantics: this expression is the application of `(+)`
  (with type `int -> int -> int`) to two `int` literals. The
  expression has type `int`.
- Dynamic semantics: when evaluated, it produces the value `68`.

:::slide

## Two kinds of semantics

Every expression has both:

- **Static semantics**: meaning *before* you run; mainly its **type**.
- **Dynamic semantics**: what happens when you *run* it; a **value**.

```ocaml
let _ = 23 + 45
```

- Static: `int + int`, expression has type `int`.
- Dynamic: evaluates to `68`.
- Static catches whole classes of bug before Run.

:::

The two kinds of meaning are independent: knowing the type of an
expression does not, in general, tell you its value (it tells you
which *kind* of values are possible). Knowing the value does not
formally tell you the type, though usually it constrains it.

A *type error* is a violation of static semantics: the compiler
notices a mismatch and refuses to produce a runnable program. A
*runtime exception* (like division by zero, or out-of-bounds array
access) is a violation of dynamic semantics: the program runs and
encounters an unexpected situation at execution time.

The static-vs-dynamic lens is one we will return to throughout the
course. Each time we introduce a new construct (functions, records,
variants, modules), we will ask: what type does this expression
have, and what happens at runtime? They are two questions.

## A spectrum of languages

It is helpful to think of programming languages as falling along a
spectrum, not into a binary "static" versus "dynamic" box. Different
languages catch different fractions of errors statically.

:::slide

## A spectrum of languages

Spectrum, not binary:

- **Mostly dynamic** (JavaScript, Python): everything checked at runtime.
- **Some static** (C): types declared but weak; casts and `void*` sidestep it.
- **More static** (Java, Scala, Rust, Kotlin, Swift): strong typing,
  but nulls and downcasts surface at runtime.
- **Mostly static** (OCaml, Haskell): almost no runtime type errors.

OCaml sits at the **mostly static** end.

:::

**Mostly dynamic** (JavaScript, Python, Ruby). Almost everything is
checked at runtime. You can write `x + "1"` in Python and find out
*at execution time* whether it makes sense (it does not, in
Python 3, if `x` is anything other than `string`). Programs work in test until an untested code path runs;
a typo in a method name is a runtime error, not a compile error.

**Some static, mostly dynamic** (C). Types are declared, but the
type system is weak: casts and `void*` give you escape hatches that
the compiler does not police. Pointer arithmetic can manufacture
nonsense without complaint. Memory errors (use-after-free,
buffer overflow) are detected (if at all) at runtime, often
silently corrupting data before crashing somewhere else.

**More static** (Java, Scala, Rust, Kotlin, Swift, C#). Stronger
type systems; many errors that would be runtime in dynamic
languages are compile-time here. But there are still escape
hatches: null references are usually nullable by default in Java
(NullPointerException at runtime), downcasts can fail at runtime,
generics have erasure issues. Rust is closer to fully static.

**Mostly static** (OCaml, Haskell, Idris). Almost no runtime type
errors in well-typed code. There is no `null` by default (you opt
in via `Option`, which the type system tracks). Casts that the
type checker can't verify are explicit and rare. Most of the
errors you would discover at runtime in Python or Java, you
discover at compile time in OCaml.

The trade-off is real: more static checking means more upfront
work to get the types right, in exchange for fewer runtime
surprises. OCaml's bet is that the upfront cost is small (because
of inference, see below) and the runtime payoff is large. The same
bet underlies Rust and Haskell.

## A static error

Here is a small program that does not even compile, because of a
static-semantics violation.

```ocaml skip
let _ = 23 = 45.0
```

:::slide

## A static error

```ocaml skip
let _ = 23 = 45.0
```

- Rejected: left is `int`, right is `float`.
- `=` requires both sides to have the **same type**.

```
Error: The constant 45.0 has type float but an expression was
       expected of type int
```

- Program does not run; static check fails first.

:::

The left operand of `=` is an `int`, the right is a `float`. The
equality operator `(=)` requires both operands to be of the *same*
type. `int` and `float` are different types; the constraint cannot
be satisfied; the compiler rejects the program.

This is helpful behaviour, not annoying. The program author
probably intended to compare two numbers of the same type;
mixing `int` with `float` here is almost certainly a typo (was
the literal supposed to be `45`? Or was the variable supposed to
be `23.0`?). Either way, the compiler asks before the program
runs.

## A dynamic check (not an error)

Compare with this:

```ocaml
let _ = 23 = 45  (* = false *)
```

:::slide

## A dynamic check (not an error)

```ocaml
let _ = 23 = 45
```

- Both sides `int`: static check passes, type is `bool`.
- Runtime: evaluates to `false`. A **value**, not an error.

:::

Both sides are `int`; the types match; static check passes. The
expression has type `bool`. At runtime, it evaluates to `false`
(because 23 ≠ 45). This is *not* an error; it is what equality
means. The static check was about whether the comparison was
well-formed; the dynamic answer is about whether it happens to
hold for these particular values.

This is the distinction worth internalising: type errors and
"wrong answers" are different categories of failure. The first is
a question about the *shape* of your program; the second is about
its *behaviour*. Static checking aims at the first.

## Why catch errors statically?

Why bother with this whole static apparatus, when dynamic languages
let you write code faster? Four reasons that compound:

:::slide

## Why catch errors statically?

- **Earlier is cheaper.** Compile-time bugs can't ship.
- **Better localization.** Compiler points at file and line.
- **Fearless refactoring.** Rename a field; compiler lists every call site.
- **Documentation.** Types annotate the API, mechanically checked.

**Cost:** upfront friction. Trade fewer bugs later for more work now.

:::

**Earlier is cheaper.** Bugs found by the compiler never ship; they
get fixed before the code is even committed. Bugs found in tests
get fixed before the code is deployed. Bugs found in production are
the most expensive to fix, because users were affected and you
need a hot-fix release. The earlier in this chain the compiler
catches an error, the cheaper it is.

**Better localization.** When the compiler reports a type error, it
points at the file, line, and (usually) the offending sub-expression,
plus what was expected versus what was found. Compare this to a
runtime null-pointer exception that surfaces three calls deep into a
library you did not write, where the error message is the *symptom*
(`undefined is not a function`) rather than the *cause* (a typo in
a field name).

**Fearless refactoring.** This is the one that makes the largest
practical difference. If you rename a field of a record in OCaml,
the compiler immediately tells you every call site that needs to be
updated, by reporting type errors. You fix them; the program
compiles; it works (or at least, has not regressed). In a dynamic
language, the equivalent rename means hunting through string
matches in the codebase and hoping you have tests for every code
path. Refactoring in OCaml is fast and confident; in Python or
JavaScript it is slow and nervous. This is why large codebases in
typed languages stay maintainable over years.

**Documentation that cannot lie.** A function's type signature is
documentation: a one-line description of what it expects and what
it returns, that the compiler keeps honest. If the documentation
were a doc comment ("this function takes an int and returns a
string"), it could drift out of sync with the code; the type
signature can't. We will exploit this heavily in Module 7 when we
get to module signatures.

The cost: you have to think about types upfront. Programs that
would run-but-silently-misbehave in Python are rejected by OCaml
until they are well-typed. To people used to typing fast and
testing fast, this can feel like friction. The trade is that you
catch problems early; the question is whether the friction is
worth the savings. For programs intended to last more than a week
(which is most real software), the savings dwarf the friction.

## Type inference

The reason the static type system is bearable in OCaml is *type
inference*: the compiler works out what types your expressions have
without you having to write them down. OCaml's inference is based
on the [Hindley-Milner algorithm](https://en.wikipedia.org/wiki/Hindley%E2%80%93Milner_type_system)
(developed by Roger Hindley in combinatory logic and rediscovered
by Robin Milner for ML in the 1970s). The intuition is straightforward, even if the algorithm
itself has some clever parts:

1. Every expression has some type. Initially the compiler treats
   each unknown type as a fresh type variable (`'a`, `'b`, ...).
2. Operators and literal forms generate *constraints*: `+` says its
   two operands must be `int` and its result is `int`. The literal
   `3.14` says it is `float`. A function call says the argument's
   type must match the function's parameter type.
3. The compiler collects all these constraints and *solves* them: it
   finds a consistent assignment of types to every expression in
   the program. If no consistent assignment exists, you get a type
   error.
4. The final inferred type of each binding is reported.

You will never implement this algorithm yourself in this course;
you only need to read its output. When the toplevel reports a type
for a function you wrote, it ran inference.

:::slide

## Inference for a simple function

```ocaml
let mean x y = (x + y) / 2
```

Toplevel reports: `val mean : int -> int -> int = <fun>`.

- `+` and `/` both have type `int -> int -> int`.
- The literal `2` is `int`.
- So `x : int`, `y : int`, result `int`.
- Therefore `mean : int -> int -> int`.
- **Zero annotations written.** Compiler did the work.

:::

Walk through:

- `+` has type `int -> int -> int` (the integer addition operator).
- In `x + y`, both operands of `+` must be `int`. So `x : int` and
  `y : int`.
- `/` is integer division, type `int -> int -> int`. The literal
  `2` is `int`. So `(x + y) / 2` is well-typed `int`.
- The function body has type `int`.
- The function takes `x` (an `int`) and `y` (an `int`) and returns
  an `int`. So `mean : int -> int -> int`.

Every step is a constraint generated from an operator or literal;
the inference algorithm runs through them all and reports the type.
We wrote no annotations.

### As an inference rule

The same reasoning, written formally. The typing rule for `+` is:

$$
\dfrac{e_1 : \mathtt{int} \qquad e_2 : \mathtt{int}}
      {e_1 + e_2 : \mathtt{int}}
$$

For our function body `(x + y) / 2`, the premises of `+` ask
`x : int` and `y : int`; the premises of `/` ask its operands to be
`int`. Those become the *constraints* the algorithm collects.
Solving them gives `mean : int -> int -> int`. The inference engine
is essentially building a derivation tree out of these rules and
reading the leaves to assign types to the parameters.

:::slide

### As an inference rule

The typing rule for `+`:

$$
\dfrac{e_1 : \mathtt{int} \qquad e_2 : \mathtt{int}}
      {e_1 + e_2 : \mathtt{int}}
$$

For `x + y` (and similarly `... / 2`), the premises force
`x : int` and `y : int`. Solving the collected constraints gives
`mean : int -> int -> int`.

:::

```ocaml
let mean_f x y = (x +. y) /. 2.0
```

Same shape, float operators. `+.` and `/.` both have type
`float -> float -> float`; the literal `2.0` is `float`. So `x`
and `y` are forced to be `float`, the result is `float`, and the
function has type `float -> float -> float`.

:::slide

## A different operator changes everything

```ocaml
let mean_f x y = (x +. y) /. 2.0
```

`val mean_f : float -> float -> float = <fun>`. The typing rule
for `+.` mirrors the one for `+`, with `float` everywhere:

$$
\dfrac{e_1 : \mathtt{float} \qquad e_2 : \mathtt{float}}
      {e_1 \mathbin{\mathtt{+.}} e_2 : \mathtt{float}}
$$

- Same shape; `+.` and `/.` instead of `+` and `/`.
- Float operators force both args to `float`; result `float`.
- **Secret**: operators carry type information.
- Inference propagates it through the rest of the function.

:::

**The operator drives the inference.** This is the punchline I want
you to internalise from this lecture. When you read OCaml code and
want to predict the type, look at the operators and function calls;
each one imposes constraints; the constraints propagate; the type
falls out.

## A trickier example

Here is a function whose type may surprise you the first time:

```ocaml
let mag x y = sqrt (x *. x +. y *. y)
```

What is the type?

:::slide

## A trickier example

```ocaml
let mag x y = sqrt (x *. x +. y *. y)
```

`val mag : float -> float -> float = <fun>`.

- `sqrt : float -> float`, argument must be `float`.
- So `x *. x +. y *. y` must be `float`.
- `*.` and `+.` force operands to `float`.
- Hence `x : float`, `y : float`, result `float`.
- Many languages need this spelled out as annotations; OCaml infers it.

:::

Trace:

- `sqrt` has type `float -> float`. So its argument must be `float`.
- The argument is `x *. x +. y *. y`. The result of `+.` is `float`.
- The operands of `+.` (which are `x *. x` and `y *. y`) must each
  be `float`. The result of `*.` is `float`.
- The operands of `*.` (which are `x` and `x`, and `y` and `y`)
  must each be `float`. So `x : float` and `y : float`.
- The result of the whole function body, `sqrt (...)`, is `float`.
- Therefore `mag : float -> float -> float`.

Inference chained four operator constraints to determine both
parameters and the return type. In a language without inference
(Java, C, C++), you would have written `float mag(float x, float y)`
with all three types explicit. In OCaml the compiler does the work.

### As a derivation tree

We can write the same reasoning out as a *derivation tree*, in the
formal style introduced earlier. Let $\Gamma$ stand for the
*context* of assumptions:

$$
\Gamma = \mathtt{sqrt} : \mathtt{float} \to \mathtt{float},\ x : \mathtt{float},\ y : \mathtt{float}.
$$

`sqrt` is on the left of the turnstile because it comes from the
ambient environment (the standard library); `x` and `y` are on
the left because they are the function's parameters. The *variable
rule* lets us pull each binding out of $\Gamma$ as its own
typing judgement:

$$
\dfrac{(z : t) \in \Gamma}{\Gamma \vdash z : t}
$$

so $\Gamma \vdash x : \mathtt{float}$, $\Gamma \vdash y : \mathtt{float}$,
and $\Gamma \vdash \mathtt{sqrt} : \mathtt{float} \to \mathtt{float}$
are all immediate. With those as leaves, the body of `mag` has
the derivation:

$$
\dfrac
  {\Gamma \vdash \mathtt{sqrt} : \mathtt{float} \to \mathtt{float}
   \qquad
   \dfrac
     {\dfrac{\Gamma \vdash x : \mathtt{float} \qquad \Gamma \vdash x : \mathtt{float}}
            {\Gamma \vdash x \mathbin{\mathtt{*.}} x : \mathtt{float}}
      \qquad
      \dfrac{\Gamma \vdash y : \mathtt{float} \qquad \Gamma \vdash y : \mathtt{float}}
            {\Gamma \vdash y \mathbin{\mathtt{*.}} y : \mathtt{float}}}
     {\Gamma \vdash (x \mathbin{\mathtt{*.}} x) \mathbin{\mathtt{+.}} (y \mathbin{\mathtt{*.}} y) : \mathtt{float}}}
  {\Gamma \vdash \mathtt{sqrt}\ ((x \mathbin{\mathtt{*.}} x) \mathbin{\mathtt{+.}} (y \mathbin{\mathtt{*.}} y)) : \mathtt{float}}
$$

The bottom is the goal: the whole body has type `float`. The right
sub-tree applies the `+.` rule, whose two premises (the `*.`
sub-derivations) each unfold further into a pair of var-rule
leaves $\Gamma \vdash x : \mathtt{float}$ or $\Gamma \vdash y :
\mathtt{float}$. The left premise is the var-rule for `sqrt`. The
conclusion uses the function-application rule:

$$
\dfrac{e_1 : t_1 \to t_2 \qquad e_2 : t_1}
      {e_1\ e_2 : t_2}
$$

Read the whole tree top-down (premises first) and you reproduce
the constraint-collection-and-solve that inference actually does.

:::slide

## Derivation tree for `mag`

Let $\Gamma = \mathtt{sqrt} : \mathtt{float} \to \mathtt{float},\
x : \mathtt{float},\ y : \mathtt{float}$. Variable rule:
$\dfrac{(z : t) \in \Gamma}{\Gamma \vdash z : t}$.

$$
\scriptsize
\dfrac
  {\Gamma \vdash \mathtt{sqrt} : \mathtt{float} \to \mathtt{float}
   \quad
   \dfrac
     {\dfrac{\Gamma \vdash x : \mathtt{float} \quad \Gamma \vdash x : \mathtt{float}}
            {\Gamma \vdash x \mathbin{\mathtt{*.}} x : \mathtt{float}}
      \quad
      \dfrac{\Gamma \vdash y : \mathtt{float} \quad \Gamma \vdash y : \mathtt{float}}
            {\Gamma \vdash y \mathbin{\mathtt{*.}} y : \mathtt{float}}}
     {\Gamma \vdash (x \mathbin{\mathtt{*.}} x) \mathbin{\mathtt{+.}} (y \mathbin{\mathtt{*.}} y) : \mathtt{float}}}
  {\Gamma \vdash \mathtt{sqrt}\ ((x \mathbin{\mathtt{*.}} x) \mathbin{\mathtt{+.}} (y \mathbin{\mathtt{*.}} y)) : \mathtt{float}}
$$

- Leaves: var-rule lookups for `sqrt`, `x`, `y` from $\Gamma$.
- Inner steps: the `*.` rule, then the `+.` rule.
- Bottom step: function application.

:::

## When to write annotations

Type annotations were introduced in
[the tour of OCaml](M01-L03-ocaml-tour.html#type-annotations-when-you-want-them):
they are optional, and the compiler checks them against what
inference would have produced. Now that we have seen what
inference actually does, the practical question is *when* to
write them.

:::slide

## When to write annotations

- Introduced in
  [the tour of OCaml](M01-L03-ocaml-tour.html#type-annotations-when-you-want-them):
  optional, and they must agree with what inference would
  produce.
- **Use annotations** to:
  - document a public API (the annotation is the contract);
  - pin down a too-general inferred type;
  - localise a confusing type error.
- For `.mli` signatures (Module 7), annotations **are the API**.
- For everyday local helpers, **leave them off**.

:::

Use annotations when:

- **The function is part of a public API.** Then the annotation is
  documentation: it tells a reader what the function expects without
  forcing them to read the body.
- **You want to constrain inference.** Occasionally inference would
  produce a more general type than you want. Annotating constrains
  it.
- **You are debugging a confusing type error.** Adding annotations
  to suspect functions narrows where the error gets reported. The
  compiler now blames *that* function instead of some caller.

[Module signatures](M07-L07-signatures.html) (`.mli` files, Module
7) are entirely annotations: they list the types of a module's
exports, and the compiler enforces them against the module's
implementation. We will see this in detail later.

For ordinary local helpers, leave annotations off. They clutter.

## A quick check

:::quiz mcq id=M02-L03-q2
Which of the following best describes the difference between a
*static* error and a *dynamic* error?

- [ ] Static errors happen at runtime; dynamic errors happen at
      compile time.
- [x] Static errors are caught by the compiler before the
      program runs; dynamic errors only show up while the
      program is running.
- [ ] Static errors are warnings; dynamic errors are fatal.
- [ ] Static and dynamic errors are two names for the same
      thing.

**Why:** "static" means *at compile time*, before the program
runs. The OCaml compiler rejects programs whose types don't
line up; you never get to run them. "Dynamic" means *at run
time*: even a well-typed program can still raise an exception
(e.g. division by zero), but that surfaces only once execution
reaches the bad expression. Languages differ in where they put
that line; OCaml puts a lot on the static side.
:::

:::quiz mcq id=M02-L03-q3
The toplevel reports

```text
val g : float -> int -> float = <fun>
```

for some function `g`. Which call type-checks?

- [ ] `g 1 2`
- [ ] `g 1.0 2.0`
- [x] `g 1.0 2`
- [ ] `g 2 1.0`

**Why:** the inferred signature says `g` takes a `float` first
and an `int` second, and returns a `float`. So the first
argument must be a `float` literal (`1.0`) and the second must
be an `int` literal (`2`). OCaml does not implicitly convert
between `int` and `float`; the literal `1` is `int`, the
literal `1.0` is `float`, and the compiler does not silently
coerce one to the other.
:::

## Activity

:::slide

## Activity

What type does OCaml infer for:

```ocaml
let f x y = x +. y *. 2.0
```

Predict, then run.

:::

:::quiz mcq id=M02-L03-q1
What type does OCaml infer for `let f x y = x +. y *. 2.0`?

- [ ] `int -> int -> int`
- [ ] `bool -> bool -> bool`
- [x] `float -> float -> float`
- [ ] `float -> int -> float`

**Why:** the literal `2.0` is `float`. The operator `*.` forces `y`
to be `float` and the product `y *. 2.0` to be `float`. The
operator `+.` forces `x` and the product to be `float`; the result
of `+.` is `float`. So both arguments are `float` and the result
is `float`. If you had written `+` instead of `+.`, the compiler
would have rejected the function because the operator `+` expects
two `int` arguments but the inner expression `y *. 2.0` is
`float`.
:::

:::slide

## Activity discussion

```ocaml
let f x y = x +. y *. 2.0
```

`val f : float -> float -> float = <fun>`.

- `2.0` is `float`.
- `y *. 2.0` forces `y : float`; result `float`.
- `x +. (...)` forces `x : float`; result `float`.
- So `f : float -> float -> float`.

If you'd written `x + y *. 2.0`: type error. `+` wants `int`, `*.`
wants `float`.

:::

## What's next

We have now seen enough OCaml that the rhythm of writing functions
and reading inferred types should feel manageable. The
[next lecture](M02-L04-operators.html) goes through the operators
in detail: precedence, the ones that catch beginners out, and the
small set of operators you will use 95% of the time. After that,
the [`if` expressions lecture](M02-L05-if-expressions.html) covers
`if`/`then`/`else` as an expression (a small but real shift from
imperative languages), and the module ends with the
[tutorial](M02-L06-tutorial.html).

:::slide

## What's next

- Next: **operators and pitfalls**.
- Precedence, daily operators, and beginner mistakes.

:::

## Reading

- **Cornell CS3110**, *Type checking*: the textbook chapter on
  the same material with formal typing rules:
  <https://cs3110.github.io/textbook/chapters/basics/expressions.html>
- **Real World OCaml**, *A Guided Tour* (type inference section):
  <https://dev.realworldocaml.org/guided-tour.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
