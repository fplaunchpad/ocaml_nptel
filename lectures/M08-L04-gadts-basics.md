---
title: "GADTs: variants with type-level information"
lecture_no: 4
week: 8
duration_target_min: 24
concepts: [GADT, generalized algebraic data types, type-level information, pattern matching on GADTs, polymorphic recursion, units of measure, phantom types]
keywords: [OCaml, GADT, type refinement, type-safe AST, polymorphic recursion, units of measure, phantom type]
activity_question: "Extend the lecture's [type _ expr] with a constructor [Is_zero : int expr -> bool expr] and add the matching case to [eval]. Notice how one constructor takes an [int expr] yet produces a [bool expr]."
think_about_this: "An ordinary variant says: 'each constructor produces a value of the type'. A GADT says: 'each constructor produces a value of a *specific* type that may differ from the others'. What is the cost of this extra precision?"
reading:
  - title: "Real World OCaml, GADTs"
    url: https://dev.realworldocaml.org/gadts.html
---

# GADTs: variants with type-level information


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">GADTs: variants with type-level information</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

This lecture switches gears entirely from the
[monad story](M08-L01-option-monad.html). So far in Module 8 we have
been about *sequencing* computations; now we turn to a more
advanced type-system feature called *generalized algebraic data
types*, almost always abbreviated *GADTs*. They are the second
half of the OCaml toolkit needed for typed embedded languages, and
they show up in serious OCaml code whenever you want the compiler
to do more work for you.

[Ordinary variants](M04-L03-variants.html) say "this value is one
of a finite set of cases". GADTs add: "and each case can have a
*different* type index". The practical consequence is that the
compiler can prove things at compile time that an ordinary variant
would have to check at runtime. Wrong combinations become type
errors, not crashes.

The idea is in some ways simple; the notation is unusual; the type
theory is involved. We keep it light and lean on worked examples.

:::slide

## This lecture: GADTs

- Module 8 shifts gears: from sequencing (monads) to a more
  advanced type-system feature.
- *Generalized algebraic data types* (GADTs).
  - Ordinary variants: "value is one of a finite set of cases".
  - GADTs add: "and each case can have a *different* type index".
- Practical consequence: wrong combinations become type errors,
  not runtime crashes.
- Idea is simple; notation is unusual; type theory is involved.
  - We keep the theory light and focus on worked examples; more
    substantial use cases follow next lecture.

:::

## Ordinary variant: same parameter for all constructors

To set the contrast, an
[ordinary parameterised variant](M04-L04-recursive-types.html):

:::slide

## Ordinary variant: same parameter for all constructors

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
```

- `'a` is the same for every constructor.
- Every value of `'a tree` has the same `'a`.
- The compiler does not distinguish "tree of int" from "tree of
  string" except by tracking `'a`.

:::

Here `'a tree` is uniformly indexed: every `Leaf` and every `Node`
inside an `'a tree` value uses the same `'a`. If `'a = int`, then
the `Node` values carry `int`s; if `'a = string`, they carry
strings. The constructors do not choose their own type index; they
share whatever the surrounding type says.

That is fine for most data structures. A list of `int`s, a tree
of `string`s, a record of options: in all these the parameter is
fixed by the outside. But sometimes the constructors need to
choose their own indices independently. That is the case GADTs
handle.

## The GADT form

Look at this expression-AST type:

:::slide

## GADT: constructors with specific indices

```ocaml
type _ expr =
  | Int_lit  : int  -> int expr
  | Bool_lit : bool -> bool expr
  | Add      : int expr * int expr -> int expr
  | If       : bool expr * 'a expr * 'a expr -> 'a expr
```

Reading the constructors:

- `Int_lit : int -> int expr`: takes an `int`, produces an `int expr`.
- `Bool_lit : bool -> bool expr`: takes a `bool`, produces a `bool expr`.
- `Add : int expr * int expr -> int expr`: requires two `int expr`s.
- `If : bool expr * 'a expr * 'a expr -> 'a expr`: condition is
  `bool expr`; the two branches share an `'a`.

The `_` in `type _ expr` is a placeholder; each constructor decides
what fills it in.

:::

The syntax `Constructor : args -> result_type` is unusual. Read it
as an explicit type signature for the constructor: like a function
signature, but for a data constructor. Ordinary variant constructors
implicitly have a result type of "the type being defined, with the
same parameters as the type header". GADT constructors say so
explicitly, which lets them choose *different* result types.

Concretely:

- `Int_lit n` is a value of type `int expr`. So `Int_lit 3 : int expr`.
- `Bool_lit b` is a value of type `bool expr`. So `Bool_lit true : bool expr`.
- `Add (a, b)` is a value of type `int expr`, *and* it can only be
  built if both `a` and `b` already have type `int expr`. You
  cannot pass an `int expr` and a `bool expr` to `Add`.
- `If (c, t, e)` is a value of type `'a expr` for some `'a`, with
  the constraint that the condition is `bool expr` and the two
  branches share the same `'a`. So an `If` returning `int expr`
  must have two `int expr` branches; an `If` returning `bool expr`
  must have two `bool expr` branches.

This is what we mean by "type-level information". The constructor
not only tags the data; it pins down the *type* of the value, and
the compiler uses that information at compile time.

## What we get: type-safe construction

Compare what the compiler accepts and rejects:

:::slide

## What we get: type-safe construction

```ocaml
type _ expr =
  | Int_lit  : int  -> int expr
  | Bool_lit : bool -> bool expr
  | Add      : int expr * int expr -> int expr
  | If       : bool expr * 'a expr * 'a expr -> 'a expr

let e1 : int expr = Add (Int_lit 1, Int_lit 2)
let e2 : int expr = If (Bool_lit true, Int_lit 5, Int_lit 10)
```

Both compile. `Add` is given two `int expr`s; `If` has a
`bool expr` condition and matching branches.

:::

:::slide

## The broken versions are caught at compile time

```ocaml skip
let bad = Add (Int_lit 1, Bool_lit true)
let worse = If (Int_lit 5, Int_lit 1, Int_lit 2)
```

- `Add` rejects `Bool_lit true`: it wants `int expr`.
- `If` rejects `Int_lit 5` as a condition: it wants `bool expr`.
- A dynamically-typed AST raises a *runtime* error here.
- A GADT-typed AST raises a *compile* error.

:::

This is the GADT design payoff: programs that would otherwise crash
an interpreter become type errors. With ordinary variants you would
have to write an interpreter, walk the AST, and check at every node
that the children have compatible types. With a GADT, the compiler
refuses to even build a tree with incompatible children. The runtime
check vanishes; the bad construction is rejected before any code
runs.

The cost is on the construction side: every constructor application
has to be at the right index. The compiler is unforgiving about
this. If you want to write a program that builds an `int expr`,
every step of the construction has to commit to int-typed values.
You cannot have a runtime-dispatched "I will figure out later
what type this is" because the compiler wants to know now.

## Pattern matching with type refinement

So far you have seen GADT syntax, the `_` placeholder, and what
type-safe construction buys. The section below is the centerpiece
of the lecture: how the compiler uses the constructor's result
type to refine the type during pattern matching, and the
`type a. ...` annotation that turns this on. Read the `eval`
walkthrough that follows slowly; the four cases each illustrate
a different facet of the refinement.

First, see why a plain annotation will not do. The obvious
`eval : 'a expr -> 'a` does not type-check:

:::slide

## First: why the naive version fails

```ocaml skip
let rec eval : 'a expr -> 'a = function
  | Int_lit n  -> n   (* this branch needs 'a = int  *)
  | Bool_lit b -> b   (* this branch needs 'a = bool *)
  (* ... and the other constructors ... *)
```

- Without help, OCaml fixes a *single* `'a` across the whole match.
- `Int_lit` forces `'a = int`; `Bool_lit` forces `'a = bool`: they
  conflict, so it is a type error.

:::

The fix is the `type a.` annotation: it lets `a` be a *different*
type in each branch. With it, OCaml's
[pattern matching](M05-L01-basic-patterns.html) *refines* the type
index per case: each branch knows which constructor fired and
specialises `a` accordingly.

:::slide

## Pattern matching: type refinement

```ocaml
let rec eval : type a. a expr -> a = function
  | Int_lit  n -> n
  | Bool_lit b -> b
  | Add (a, b) -> eval a + eval b
  | If (c, t, e) -> if eval c then eval t else eval e

let _ = eval (Add (Int_lit 3, Int_lit 4))                 (* = 7 *)
let _ = eval (If (Bool_lit true, Int_lit 5, Int_lit 10))  (* = 5 *)
```

Two new things:

- `type a. ...` is a *locally abstract type* annotation: "for any
  `a`, this function takes an `a expr` and returns an `a`."
- Each case refines `a`: `Int_lit n -> n` forces `a = int`, so
  `n : int` matches the return type.
- *Required*, not optional: `eval` recurses at a different type than
  its own (*polymorphic recursion*), which OCaml cannot infer.

:::

The `type a. ...` syntax says "this function is polymorphic in `a`,
and inside the body `a` is an abstract type." Why is it needed here,
when most OCaml functions need no annotation at all? Because `eval`
does *polymorphic recursion*: it calls itself at a *different* type
than the one it was called at. In the `If` case, the condition `c`
is a `bool expr` even when the whole `If` is an `int expr`, so
`eval c` recurses at `bool` while the outer call is at `int`.
OCaml's automatic inference assumes a recursive function calls
itself at the *same* type (that assumption is what keeps inference
decidable), so it cannot work this case out on its own. The
`type a.` annotation supplies the type up front, and that is exactly
what lets each branch refine `a` independently. This is one of the
few places in OCaml where an annotation is not optional.

Reading the cases:

- `Int_lit n -> n`. The constructor `Int_lit : int -> int expr`
  fires. The compiler refines: in this branch, `a = int`. The
  variable `n : int`. The return type is `a`, which is now `int`.
  The expression `n` is an `int`. Type-checks.
- `Bool_lit b -> b`. Similarly, `a = bool` in this branch.
  `b : bool`. Returning `b` has type `bool`, which is `a` here.
  Type-checks.
- `Add (a, b) -> eval a + eval b`. The constructor's result is
  `int expr`, so this branch refines `a = int`. The two
  recursive calls `eval a` and `eval b` (where `a` and `b` are
  the GADT's sub-expressions) produce `int`s. Adding them gives
  an `int`, which matches the refined `a = int`. Type-checks.
- `If (c, t, e)`. The constructor preserves `'a`, so no refinement
  happens here; `a` stays whatever it was. The condition `c :
  bool expr`, so `eval c : bool`. The branches `t, e : a expr`,
  so `eval t : a` and `eval e : a`. The `if` returns an `a`.
  Type-checks.

The compiler is doing real work in every case: tracking which
constructor matched, refining the abstract type accordingly, and
type-checking the right-hand side under the refinement. This is
the central feature that distinguishes GADTs from ordinary
variants. With ordinary variants the index is fixed across
branches; with GADTs it can change.

## Why is this useful?

:::slide

## Why is this useful?

- **Make illegal states unrepresentable.** Crashes become type
  errors.
- **Compose typed DSLs.** Embedded languages inherit host typing.
- **Carry compile-time metadata.** "List known non-empty",
  "value known positive".
- **Cost:** type-level reasoning is heavier.
- Some patterns need locally abstract types or explicit
  constraints.

:::

A more concrete way to think about the first benefit: when you
build a program with `Add (Bool_lit true, Int_lit 5)`, an
ordinary AST would represent the program just fine, and the
*interpreter* would eventually try to add a boolean to an integer
and raise a runtime "type error". The compiler had no way to
notice the mistake when you wrote the source. With a GADT, the
compiler refuses to compile the source: the construction itself
is ill-typed, before any evaluation runs.

For a toy interpreter that is a parlour trick. For a real
language (a [SQL query
builder](https://hackage.haskell.org/package/beam), a financial
calculation engine, an embedded scripting language), the difference
is large: bugs that would otherwise hide in branches your tests
never exercise become impossible to write.

The cost is real too. GADTs require more annotations, more
locally-abstract-type declarations, and more thought. Pattern
matching can occasionally need explicit type assertions to help
the compiler refine correctly. The error messages, when GADT
inference fails, are harder to read than ordinary type errors.
Most OCaml code does not need GADTs and is better off without
them; the code that *does* need them needs them in a serious way.

## Units of measure

:::slide

## A units bug that cost $125 million

- In 1999 the **Mars Climate Orbiter** was lost to a units mix-up.
  - One team used imperial units, the other metric; the two were
    combined as if identical.
- A GADT lets one program hold *several* units at once yet refuse to
  mix them, catching the bug *by construction*.

:::

The Orbiter was not even the first famous unit victim. In 1983,
Air Canada flight 143 ran out of fuel at 41,000 feet because the
ground crew, mid-way through Canada's imperial-to-metric
transition, computed the fuel load in pounds where the new 767
expected kilograms; the aircraft, suddenly a 132-seat glider,
dead-sticked onto a drag strip at Gimli with no fatalities
([the Gimli Glider](https://en.wikipedia.org/wiki/Gimli_Glider)).
Sixteen years apart, the same bug: a number travelled without
its unit.

That Mars Climate Orbiter loss is the motivating example: types can
make a units mix-up impossible. We tag a `float` with its unit by
declaring three *uninhabited* types, `kelvin`, `celsius`, and
`fahrenheit`, that have no values of their own and exist only to sit
in a type index. Then a GADT `temp` whose constructor picks the
unit:

:::slide

## Units of measure: a typed temperature

```ocaml
type kelvin
type celsius
type fahrenheit

type _ temp =
  | Kelvin     : float -> kelvin temp
  | Celsius    : float -> celsius temp
  | Fahrenheit : float -> fahrenheit temp
```

- `kelvin` / `celsius` / `fahrenheit` are empty types used only as
  *labels* (the index `'a` in `'a temp` is phantom).
- `Kelvin 300. : kelvin temp`, `Celsius 25. : celsius temp`:
  distinct types, though each just holds a `float`.

:::

Now write addition so it can only ever combine temperatures of the
*same* unit:

:::slide

## Adding temperatures, units enforced

```ocaml
let add_temp : type u. u temp -> u temp -> u temp =
  fun a b -> match a, b with
  | Kelvin x, Kelvin y         -> Kelvin (x +. y)
  | Celsius x, Celsius y       -> Celsius (x +. y)
  | Fahrenheit x, Fahrenheit y -> Fahrenheit (x +. y)

let _ = add_temp (Kelvin 20.) (Kelvin 30.)   (* = Kelvin 50. *)
```

```ocaml skip
let _ = add_temp (Kelvin 20.) (Celsius 12.)
(* error: celsius temp is not compatible with kelvin temp *)
```

- Both arguments share the unit `u`, so the only possible pairs are
  Kelvin/Kelvin, Celsius/Celsius, Fahrenheit/Fahrenheit: the three
  cases are exhaustive.
- Adding a kelvin to a celsius is a *compile* error, though both are
  `float` underneath. The mix-up that lost the orbiter cannot be
  written.

:::

This is a *phantom type* encoded with a GADT: the unit lives only in
the type index, never in the runtime value, yet it is enough for the
compiler to keep the units apart. Real OCaml code uses exactly this
pattern for units, currencies, and tagged identifiers.

## When to reach for GADTs

:::slide

## When to reach for GADTs

Use a GADT when:

- You are building an embedded language with multiple value types.
- You want some construction to be a compile-time error.
- You need polymorphic recursion that ordinary variants cannot
  express.

Avoid them when:

- A regular variant plus `option`/`result` is enough.
- The complexity exceeds the safety gain.

Rare in everyday code; heavy use in interpreters, query builders,
library cores.

:::

A useful question to ask before reaching for a GADT: "what
specifically would go wrong if I used an ordinary variant and
runtime checks?" If the answer is "I would crash with a
type-mismatch error after running for hours", GADTs are worth it.
If the answer is "I would have to add an
[`option`](M04-L04-recursive-types.html#the-option-type) return
type and pattern-match in two places", they are probably not.

The [next lecture](M08-L05-gadts-use-cases.html) shows real use
cases that pull this into focus, typed pretty-printers, type-safe
builders, and length-indexed lists, and the lecture after adds
heterogeneous lists and the GADT machinery behind `Printf`.

## A quick check

:::quiz mcq id=M08-L04-q3
What is the type of `Add (Int_lit 1, Int_lit 2)`?

- [x] `int expr`
- [ ] `bool expr`
- [ ] `(int * int) expr`
- [ ] `int expr * int expr`

**Why:** the constructor's signature is `Add : int expr * int expr
-> int expr`. Given two `int expr` arguments, the result type is
`int expr`. The compiler refuses to apply `Add` to anything else.
:::

:::quiz mcq id=M08-L04-q2
Why does the `eval` function need the annotation `type a. a expr
-> a`?

- [ ] OCaml requires every function to be annotated.
- [x] Its branches refine `a` to different concrete types.
- [ ] It is purely cosmetic; the compiler infers it anyway.
- [ ] It optimises the compiled code.

**Why:** without the locally-abstract-type annotation, the
compiler tries to infer a single concrete type for `a` and fails
because different branches refine it differently. The `type a. ...`
annotation says "treat `a` as fresh and abstract", which is what
GADT pattern matching needs. This is a recurring quirk: GADT
functions often need this annotation explicitly.
:::

:::slide

## Activity

The lecture's `expr` has `Int_lit`, `Bool_lit`, `Add`, `If`. Add a
constructor `Is_zero : int expr -> bool expr` (true when its
`int expr` evaluates to 0) and extend `eval` to handle it. It
takes an `int expr` but produces a `bool expr`.

:::

:::solution

:::slide

## Activity solution: the type

```ocaml
type _ expr =
  | Int_lit  : int  -> int expr
  | Bool_lit : bool -> bool expr
  | Add      : int expr * int expr -> int expr
  | If       : bool expr * 'a expr * 'a expr -> 'a expr
  | Is_zero  : int expr -> bool expr
```

- `Is_zero` consumes an `int expr` but its result type is
  `bool expr`, so it can sit in `If`'s condition slot.

:::

:::slide

## Activity solution: `eval`

```ocaml
let rec eval : type a. a expr -> a = function
  | Int_lit  n -> n
  | Bool_lit b -> b
  | Add (x, y) -> eval x + eval y
  | If (c, t, e) -> if eval c then eval t else eval e
  | Is_zero e -> eval e = 0

let _ = eval (If (Is_zero (Add (Int_lit 2, Int_lit (-2))),
                  Int_lit 1, Int_lit 0))            (* = 1 *)
```

- The `Is_zero` case computes the inner `int`, then compares to 0.

:::

:::

A code quiz:

:::quiz code id=M08-L04-q1
Define a GADT `type _ value` with two constructors `VInt : int ->
int value` and `VBool : bool -> bool value`. Write `unwrap : type
a. a value -> a` that returns the underlying value.

```ocaml
type _ value =
  | VInt  : int -> int value
  | VBool : bool -> bool value

let unwrap : type a. a value -> a = fun _ -> failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (unwrap (VInt 42) = 42) "VInt";
  check (unwrap (VBool true) = true) "VBool true";
  check (unwrap (VBool false) = false) "VBool false";
  print_endline "all tests passed"
```

:::

:::solution

Reference solution:

```
let unwrap : type a. a value -> a = function
  | VInt n -> n
  | VBool b -> b
```

The `type a. ...` annotation makes `a` locally abstract so that
each branch can refine it (`a = int` for `VInt`, `a = bool` for
`VBool`). Without the annotation, the compiler cannot find a
single concrete `a` to satisfy both branches.

:::

## What is next

:::slide

## What is next

Lecture 5: **GADT use cases**.

- Typed pretty-printers and type witnesses.
- Type-safe builders.
- Length-indexed lists: the list's length in its type.
- Then Lecture 6 (hlists, the `Printf` trick) and the Lecture 7
  tutorial.

:::

The [next lecture](M08-L05-gadts-use-cases.html) takes the basic
machinery here and shows real applications. The
[tutorial](M08-L07-tutorial.html) later combines a GADT-based typed
AST with an [option-monad](M08-L01-option-monad.html) evaluator
that can fail at runtime (division by zero, say) while still
guaranteeing type safety on the success path. That is the capstone
for the OCaml half of the course.

## Reading

- **Real World OCaml**, *GADTs*:
  <https://dev.realworldocaml.org/gadts.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
