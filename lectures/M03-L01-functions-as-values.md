---
title: "Functions as values, and anonymous functions"
lecture_no: 1
week: 3
youtube_id: DaNWJpjy9AI
duration_target_min: 24
concepts: [first-class functions, anonymous functions, fun, lambda, higher-order, function values]
keywords: [OCaml, functions, first-class, anonymous functions, fun, lambda, higher-order]
activity_question: "What is the type of [fun x -> x +. 1.0]? Predict, then check by binding it to a name."
think_about_this: "What does it mean for a function to be a 'first-class value'? Name three things you can do with a value (like an int). Now name the corresponding three things you can do with a function in OCaml."
reading:
  - title: "Cornell CS3110, Functions"
    url: https://cs3110.github.io/textbook/chapters/basics/functions.html
  - title: "Real World OCaml, Functions"
    url: https://dev.realworldocaml.org/variables-and-functions.html
---

# Functions as values


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Functions as values, and anonymous functions</h2>
<p class="title-slide-label">Module 3 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

In OCaml, a function is a *value*, the same way `42` and `"hello"`
are values. You can name a function with `let`, pass it as an
argument to another function, return it from a function, and store
it in a data structure. The slogan is that functions are
*first-class values*: they have the same rights as any other value
in the language. This lecture is about what that actually means in
practice, what new things you can express because of it, and the
syntax for creating functions on the fly.

:::slide

## Functions are values

- `42` is a value. `"hello"` is a value. **A function is a value too.**
- You can:
  - name a function with `let`,
  - pass it as an argument,
  - return it from another function,
  - store it in a list, tuple, record.
- The slogan: functions are **first-class values**.

:::

If you arrived from C or Python, the phrase "functions are values"
may sound right but the practice takes adjusting to. Functions in C
are *pointers to code*, not really values: you can pass a function
pointer but you cannot create new functions at runtime. Functions
in Python are objects, closer to the OCaml picture, but their
defining-and-using syntax is heavyweight (`def name(...)` then a
body) compared to OCaml's. Lambda-expressions ([added to Java in 8](https://docs.oracle.com/javase/tutorial/java/javaOO/lambdaexpressions.html),
to [C++ in 11](https://en.cppreference.com/w/cpp/language/lambda))
are how mainstream languages have caught up to the OCaml-style
treatment of functions; you may already know them. In OCaml this
treatment is *the default*, not a bolt-on.

Module 3 is built around this idea. This first lecture establishes
that functions are values; the next four lectures
([recursion](M03-L02-recursion.html),
[currying](M03-L03-currying.html),
[tail recursion](M03-L04-tail-recursion.html),
[local and mutual recursion](M03-L05-local-and-mutual.html))
put the machinery to work. By the end of the module you will be
writing functions that produce functions, returning functions from
functions, and reasoning about function types without effort.

:::slide

## The plan for Module 3

- **L1** (today): functions as values; anonymous functions.
- **L2** ([recursion](M03-L02-recursion.html)): writing self-referential functions.
- **L3** ([currying](M03-L03-currying.html)): every multi-argument function in OCaml is really a chain of one-argument functions.
- **L4** ([tail recursion](M03-L04-tail-recursion.html)): recursion that runs in constant stack.
- **L5** ([local and mutual recursion](M03-L05-local-and-mutual.html)): `let rec ... and ...` and `let rec ... in ...`.
- **L6** ([tutorial](M03-L06-tutorial.html)): putting it together.

:::

## Two ways to define a function

You already know one syntax for defining a function:

```ocaml
let double x = x + x
```

`let name args = body` is the everyday form, used in every example
so far. There is a second form, more verbose but more revealing:

```ocaml
let double = fun x -> x + x
```

:::slide

## Two ways to define a function

You already know one:

```ocaml
let double x = x + x
```

This is **syntactic sugar** for:

```ocaml
let double = fun x -> x + x
```

- `fun x -> x + x` is an **anonymous function** (a lambda).
- Evaluates to a function value; `let` binds it.
- Use the shorter form for named functions, `fun` for one-offs.

:::

The expression `fun x -> x + x` is an *anonymous function*. In other
language traditions this is called a *lambda* (after Alonzo
Church's lambda calculus, the mathematical foundation of functional
programming). The `fun` keyword introduces a parameter list (one
parameter, `x`, in this case); the `->` separates the parameters
from the body; the body is the expression that defines what the
function does.

`fun x -> x + x` is, all on its own, a value. It has a type
(`int -> int`). It can be bound to a name with `let`. It can be
passed to another function. It can be returned from a function. It
can sit in a list. If you accept that `42` is a value with type
`int`, you should accept that `fun x -> x + x` is a value with type
`int -> int`. They participate in the language at exactly the same
level.

The shorthand `let double x = x + x` is *syntactic sugar* for
`let double = fun x -> x + x`. The compiler treats them as
identical. Use the shorthand for named functions; use the explicit
`fun` form for functions you do not want to name (one-off computations
passed to a higher-order function, for instance).

## Anonymous functions in expressions

`fun x -> e` is an expression. It evaluates to a function value.

```ocaml
let _ = fun x -> x + 1  (* : int -> int = <fun> *)
```

The toplevel reports `int -> int = <fun>` and binds the result to
`_`. The function exists; we just have not named it. We could
apply it on the spot:

```ocaml
let _ = (fun x -> x + 1) 7  (* = 8 *)
```

:::slide

## Anonymous functions

- `fun x -> e` is the expression form.
- It's a value of function type.

```ocaml
let _ = fun x -> x + 1  (* : int -> int = <fun> *)
```

- The function exists; just unnamed.

:::

:::slide

## Anonymous functions, applied on the spot

```ocaml
let _ = (fun x -> x + 1) 7  (* = 8 *)
```

- Parenthesize, then apply.
- Parens are needed: application binds tighter than `fun`.
- Key point: `fun ... -> ...` is a real expression.

:::

The parentheses are necessary because function application binds
tighter than the `fun` syntax: without them, OCaml would parse
`fun x -> x + 1 7` as `fun x -> (x + 1 7)`, which is nonsense.

In practice you rarely apply an anonymous function on the spot
(why not just write the value?), but you constantly *pass* anonymous
functions as arguments to other functions, which we will see in a
moment.

## Multiple parameters

What about a function of two or more parameters? Three ways to
write the same function:

```ocaml
let add x y = x + y
let add' = fun x y -> x + y
let add'' = fun x -> fun y -> x + y
```

:::slide

## Multiple parameters

```ocaml
let add x y = x + y
let add' = fun x y -> x + y
let add'' = fun x -> fun y -> x + y
```

- All three define the same function.
- Third form makes it explicit: a "two-argument function" is really
  a one-argument function returning another one-argument function.
- Deeper dive: **currying**, Lecture 3.

:::

All three define the same function. The third form makes this
explicit: a "two-argument function" in OCaml is really a
*one-argument function that returns another one-argument function*.
The `fun x -> fun y -> x + y` reads "given `x`, return the function
that, given `y`, returns `x + y`." This is called *currying* (after
Haskell Curry, the same person Haskell is named for); we devote
Lecture 3 of this module to it.

For now, the takeaway: `fun x y -> ...` and `fun x -> fun y -> ...`
are interchangeable. The compiler treats them identically. The
shorthand `let add x y = ...` desugars to the curried form.

## Functions are values you can name

Once we accept that functions are values, three things follow:
you can name them, you can pass them around, and you can return
them. Let's see each.

```ocaml
let plus_one = fun x -> x + 1
let double   = fun x -> x * 2
let triple   = fun x -> x * 3

let _ = plus_one 5  (* = 6 *)
let _ = double 5    (* = 10 *)
let _ = triple 5    (* = 15 *)
```

:::slide

## Functions are values you can name

```ocaml
let plus_one = fun x -> x + 1
let double   = fun x -> x * 2
let triple   = fun x -> x * 3

let _ = plus_one 5  (* = 6 *)
let _ = double 5    (* = 10 *)
let _ = triple 5    (* = 15 *)
```

- Three function values, named with `let`, then applied.
- Same shape as `let pi = 3.14`; the value just happens to be a function.

:::

Three `let` bindings. The shape is identical to `let pi = 3.14`,
or `let greeting = "hello"`: a name bound to a value. The only
difference is that the *value* happens to be a function. The
language does not distinguish.

A related case: a *thunk* is a function whose parameter is the
unit value `()`. Its type is `unit -> 'a` for some `'a`. The body runs not when the thunk is
defined, but each time you call it with `()`:

```ocaml
let greet () = "hello"

let _ = greet     (* : unit -> string = <fun> *)
let _ = greet ()  (* = "hello" *)
```

`greet` is the thunk: a value of type `unit -> string`. The first
`let _ = greet` does not invoke the body; it simply names the
function value. The second, `greet ()`, applies the thunk and
produces `"hello"`. Each application re-runs the body. The thunk
is the canonical way to bundle a computation as a value and
decide *later* when to perform it; you will see thunks again in
[the streams-and-laziness lecture](M07-L04-streams-and-laziness.html),
where a stream's tail is exactly a `unit -> 'a stream` thunk.

## Functions can be returned from other functions

The next step: a function whose return value is *another function*.

```ocaml
let make_adder n = fun x -> x + n

let plus_five = make_adder 5
let plus_ten  = make_adder 10

let _ = plus_five 3  (* = 8 *)
let _ = plus_ten 3   (* = 13 *)
```

:::slide

## Functions can be returned from other functions

```ocaml
let make_adder n = fun x -> x + n

let plus_five = make_adder 5
let plus_ten  = make_adder 10

let _ = plus_five 3  (* = 8 *)
let _ = plus_ten 3   (* = 13 *)
```

- `make_adder : int -> (int -> int)`.
- `make_adder 5`: a new function that adds 5.
- `make_adder 10`: another that adds 10.
- First **higher-order function**: takes or returns functions.

:::

`make_adder` has type `int -> (int -> int)`: it takes an `int` and
returns a function from `int` to `int`. The two calls produce two
*different* functions: `plus_five` always adds 5 (regardless of
what other code does); `plus_ten` always adds 10. Each call to
`make_adder` produces a fresh function value.

This is our first *higher-order function*: a function that takes
or returns other functions. We will devote all of
[Module 6](M06-L01-functions-revisited.html) to higher-order
functions; for this lecture, just notice that the machinery exists
and works.

## A function value remembers its environment

Here is the subtle part. When `plus_five 3` runs, the body is
`x + n`. The parameter `x` is bound to `3`. But
where does `n` come from? It is not a parameter of `plus_five`. It
was a parameter of `make_adder`, and `make_adder` has long since
returned.

The answer is that the function value `plus_five` does not just
hold "the function body"; it also holds a record of "what `n` was
when this function was created." The value `n = 5` was *captured*
by the function at the moment of its creation. Such a function-value-with-captured-environment
is called a *closure*. We saw closures briefly in
[the let-bindings lecture](M02-L02-let-bindings.html#why-shadowing-differs-from-mutation-closures-see-the-old-value)
(the function captures the *value*, not the *name*).

:::slide

## A function value remembers its environment

```ocaml
let make_adder n = fun x -> x + n

let plus_five = make_adder 5
let _ = plus_five 100  (* = 105 *)
```

- In `plus_five 100`, body is `x + n`. Where does `n` come from?
- It was `make_adder`'s parameter; `make_adder` has long returned.
- OCaml functions are **closures**: they capture values at creation.
- `plus_five` remembers `n = 5` forever.

:::

`plus_five 100` returns `105`. The captured `n = 5` is used in
the body. The closure ensures that `plus_five` keeps working even
after `make_adder` has returned and its activation frame is gone.

## What is a closure?

Here is the definition in precise form. A name that appears in a
function's body but is not bound by the function's parameters or
by any `let` inside the body is called a *free variable* of the
function. When the function is created at runtime, OCaml records
the current value of each free variable into the function value
itself; this recording step is called *capture*, and the table
of captured values is called the *environment of the closure*. A
*closure*, then, is a function value paired with its environment.

At application time the rule for the body is: a parameter gets its
value from the call's argument, and a free variable gets its value
from the environment. In `plus_five 100`, the body `x + n` runs
with `x = 100` (the argument) and `n = 5` (read from the
environment); no other source of values exists.

The point of the environment is that the captured values can be
read *long after* the surrounding scope that originally bound
them has gone away. The function value is self-contained: body
plus environment.

One free variable:

```ocaml
let make_adder n = fun x -> x + n
```

The inner `fun x -> x + n` has parameter `x` and one free
variable `n`. Each call `make_adder k` returns a closure whose
environment contains `n = k`.

Two free variables:

```ocaml
let between lo hi = fun x -> lo <= x && x <= hi
```

The inner `fun x -> ...` has parameter `x` and two free
variables, `lo` and `hi`. `between 0 10` returns a closure whose
environment contains `lo = 0` and `hi = 10`; that closure then
takes one `int` and returns a `bool`.

A function with no free variables (`fun x -> x + 1`) is still a
closure, just with an empty environment.

:::slide

## What is a closure?

A function whose body refers to bindings that are in scope but
are **not** parameters of the function.

- The referenced name is a **free variable** of the function.
- When the function is created, the current value of each free
  variable is **captured**.
- The captured values form the closure's **environment**.

A function value = its body + its environment.

:::

:::slide

## Closures: one free variable

```ocaml
let make_adder n = fun x -> x + n
```

- The inner `fun x -> x + n` has
  - parameter `x` and
  - one free variable `n`.
- `make_adder 5` returns a closure.
- Environment holds `n = 5`.

:::

:::slide

## Closures: two free variables

```ocaml
let between lo hi = fun x -> lo <= x && x <= hi
```

- The inner `fun x -> ...` has
  - parameter `x` and
  - two free variables: `lo`, `hi`.
- `between 0 10` returns a closure.
- Environment holds `lo = 0`, `hi = 10`.

:::

## Closures capture values, not names

The capture is of *values at the time of creation*, not of names
that get looked up later.

```ocaml
let n = 10
let f = fun x -> x + n
let n = 99
let _ = f 1
```

What does `f 1` return?

:::slide

## Closures are not magic

```ocaml
let n = 10
let f = fun x -> x + n
let n = 99
let _ = f 1
```

What does `f 1` return? `11`.

- `f` captured the **value** `10` when defined.
- Later `let n = 99` shadows the outer `n` but doesn't change what `f` saw.
- Same shadowing-vs-mutation point from Module 2.

:::

Returns `11`. The closure captured `n = 10` when `f` was defined;
the later `let n = 99` shadows the outer `n` but does not change
the value `f` saw. This is the same point from
[the let-bindings lecture](M02-L02-let-bindings.html#shadowing)
(shadowing is not mutation), applied to function closures.

OCaml uses *static scoping with value capture*: the binding that
was in scope when `f` was defined is the one `f` uses, forever. In
a language where names were re-looked-up at call time, or where the
closure held a *reference* to the variable rather than its value,
`f 1` could see a later assignment. OCaml does neither.

## Functions can be passed as arguments

The third thing you can do with a value: pass it as an argument.

```ocaml
let apply_twice f x = f (f x)

let _ = apply_twice (fun x -> x + 1) 5  (* = 7 *)
let _ = apply_twice double 5            (* = 20 *)
```

:::slide

## Functions can be passed as arguments

```ocaml
let apply_twice f x = f (f x)

let _ = apply_twice (fun x -> x + 1) 5  (* = 7 *)
let _ = apply_twice double 5            (* = 20 *)
```

- `apply_twice f x = f (f x)`.
- First call: anonymous `fun x -> x + 1`. Second: `double`.
- Toplevel: `val apply_twice : ('a -> 'a) -> 'a -> 'a = <fun>`.
- `'a` is a **type variable**: any type, same one each occurrence.
- Works at `int -> int`, `float -> float`, `string -> string`, ...
- This is **polymorphism**. Formal treatment:
  [the recursive-types lecture](M04-L04-recursive-types.html#polymorphism).

:::

`apply_twice` takes a function `f` and a value `x`, and computes
`f (f x)`. The first call passes the anonymous function `fun x ->
x + 1` (so we get `((5 + 1) + 1) = 7`); the second passes `double`
(so we get `(5 * 2) * 2 = 20`).

The toplevel reports `val apply_twice : ('a -> 'a) -> 'a -> 'a =
<fun>`. Parsed: takes a function from `'a` to `'a`, plus an `'a`,
and returns an `'a`. The `'a` is a *type variable*: it stands for
"some type, the same one in each occurrence." A function whose
type contains type variables is called *polymorphic*: it works at
every choice of `'a`, with no special-casing per type. The same
`apply_twice` works for `int -> int` functions, `float -> float`
functions, `string -> string` functions, etc.

This is the first time we are seeing a type variable; we will
return to polymorphism formally in
[the recursive-types lecture](M04-L04-recursive-types.html#polymorphism),
once we have parameterised variants (lists of *anything*) to motivate
it. For now, read `'a -> 'a` as "any type to itself."

## Anonymous functions are everywhere

You will write `fun x -> ...` a lot. It is the standard way to pass
a small one-off function to a higher-order utility like `List.map`.

```ocaml
let nums = [1; 2; 3; 4; 5]
let _ = List.map (fun x -> x * x) nums  (* = [1; 4; 9; 16; 25] *)
```

:::slide

## Anonymous functions are everywhere

- Standard way to pass a small one-off function (e.g. to `List.map`).

```ocaml
let nums = [1; 2; 3; 4; 5]
let _ = List.map (fun x -> x * x) nums  (* = [1; 4; 9; 16; 25] *)
```

Without anonymous functions:

```ocaml
let square x = x * x
let _ = List.map square nums  (* = [1; 4; 9; 16; 25] *)
```

- First form is shorter; idiom leans this way for one-offs.

:::

`List.map` is the standard library function that applies a function
to every element of a list. We will see [`List.map`](M06-L02-map.html)
and its friends in detail in Module 6. For now, notice that the
natural way to write "the function `x -> x * x`" right at the call
site is the anonymous-function form `fun x -> x * x`.

Without anonymous functions, you would have to invent a name for
this little computation:

```ocaml
let square x = x * x
let _ = List.map square nums  (* = [1; 4; 9; 16; 25] *)
```

Both are fine. The anonymous-function form is shorter and keeps the
logic close to where it is used; the named form is reusable
elsewhere. Idiomatic OCaml leans toward anonymous functions for
small, single-use functions.

## Reading function types: `->` is right-associative

When you write `int -> int -> int`, OCaml reads this as `int ->
(int -> int)`. The arrow is right-associative.

```
val add : int -> int -> int
val apply_twice : ('a -> 'a) -> 'a -> 'a
```

:::slide

## Type signatures: `->` is right-associative

```text
val add : int -> int -> int
```

- Reads as `int -> (int -> int)`.
- Arrows associate right.

:::fragment

```text
val apply_twice : ('a -> 'a) -> 'a -> 'a
```

- Reads as `('a -> 'a) -> ('a -> 'a)`.
- First arg is a function; parens make it explicit.

Read left-to-right, inserting "and given an X, produces":

> "given an `('a -> 'a)`, produces (given an `'a`, produces an `'a`)"

:::

:::

`int -> int -> int` parses as `int -> (int -> int)`: a function
that takes an `int` and returns a `(int -> int)` (which is itself
a function from `int` to `int`). The right-associative reading
matches currying: `add 3` is meaningful (an `int -> int` function),
because `add` is really a one-argument function returning a function.

`('a -> 'a) -> 'a -> 'a` parses as `('a -> 'a) -> ('a -> 'a)`. The
parentheses around the first argument are *necessary*: without
them, the type would be `'a -> 'a -> 'a -> 'a`, meaning "takes
three `'a`s and returns one." With them, "takes a function from
`'a` to `'a`, then an `'a`, and returns an `'a`."

You will get fluent with practice. The trick: read left to right,
inserting "and given an X, produces" between each arrow.

## A quick check

:::quiz mcq id=M03-L01-q3
What is the type of `fun s -> s ^ "!"`?

- [x] `string -> string`
- [ ] `char -> string`
- [ ] `'a -> string`
- [ ] `'a -> 'a`

**Why:** the literal `"!"` is a `string`, and the concatenation
operator `^` works on strings only. It forces its left operand
(the parameter `s`) to be `string`, and the result of the
concatenation is `string`. So the anonymous function is
`string -> string`. The operator pins both ends; nothing is left
polymorphic.
:::

:::quiz mcq id=M03-L01-q2
What does `apply_twice (fun x -> x + 1) 5` evaluate to?

- [ ] `5`
- [ ] `6`
- [x] `7`
- [ ] `10`

**Why:** `apply_twice f x = f (f x)`. With `f = fun x -> x + 1`
and `x = 5`: the inner `f 5` is `6`; the outer `f 6` is `7`.
:::

A code challenge:

:::quiz code id=M03-L01-q1
Define `compose : ('b -> 'c) -> ('a -> 'b) -> ('a -> 'c)` that
takes two functions `g` and `f` and returns the composed function
`fun x -> g (f x)`.

```ocaml
let compose g f =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let inc x = x + 1
let neg x = -x
let () =
  check ((compose neg inc) 5 = -6) "neg . inc";
  check ((compose inc neg) 5 = -4) "inc . neg";
  check ((compose (fun x -> x * 2) (fun x -> x + 1)) 3 = 8) "*2 . +1";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution: `let compose g f = fun x -> g (f x)`, or
equivalently `let compose g f x = g (f x)`. Function composition
is used constantly in functional programming; we will return to
it in [Module 6](M06-L05-pipelines.html#function-composition).

:::

## Activity

:::slide

## Activity

What does the toplevel report as the type of:

```ocaml
fun x -> x +. 1.0
```

Predict before binding it.

:::

:::slide

## Activity discussion

```ocaml
fun x -> x +. 1.0
```

- Type: `float -> float`.
- `+.` forces `x` to be `float`; result is `float`.

Trickier:

```ocaml
fun f x -> f (f x)
```

- Anonymous `apply_twice`.
- Type: `('a -> 'a) -> 'a -> 'a`.

:::

The trickier one in the slide is the anonymous version of
`apply_twice`. The inferred type `('a -> 'a) -> 'a -> 'a` is forced
by the body: `f (f x)` requires that the output of `f` be a valid
input to `f`, so `f`'s output and input types must match (both
`'a`). The starting `x` must also be `'a` (since it is fed to `f`).
The whole expression's result is `f`'s output type, which is `'a`.

## What's next

We have established that functions are values. The next lecture,
[M03-L02](M03-L02-recursion.html), covers *recursion*: functions
that call themselves. This is how OCaml expresses iteration; you
do not write `for` loops in OCaml (well, you can, but you rarely
will). After recursion, [M03-L03](M03-L03-currying.html) covers
currying in full,
[M03-L04](M03-L04-tail-recursion.html) covers tail recursion and
the accumulator pattern (the technique for making recursion fast),
and [M03-L05](M03-L05-local-and-mutual.html) covers local and
mutual recursion. [M03-L06](M03-L06-tutorial.html) is the tutorial.

:::slide

## What's next

Lecture 2: **recursion**.

- Functions that call themselves to process structures.
- Bread and butter of functional programming.

:::

## Reading

- **Cornell CS3110**, *Functions*: the corresponding chapter:
  <https://cs3110.github.io/textbook/chapters/basics/functions.html>
- **Real World OCaml**, *Variables and functions*: same material
  from a different angle:
  <https://dev.realworldocaml.org/variables-and-functions.html>
- John Whitington, *OCaml from the Very Beginning*, Chapter 3:
  for a gentler pace.
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
