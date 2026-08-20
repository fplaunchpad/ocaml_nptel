---
title: "A tour of OCaml: values, types, and the toplevel"
lecture_no: 3
week: 1
duration_target_min: 25
concepts: [literals, types, type inference, let bindings, the toplevel, integer vs float arithmetic]
keywords: [OCaml, toplevel, let, types, type inference, int, float, bool, string]
activity_question: "What is the type of [let f x = x +. 1.0] in OCaml? Why is it [float -> float] and not [int -> int]?"
think_about_this: "Why does OCaml distinguish [+] (for integers) from [+.] (for floats), instead of overloading [+] like Python and C do?"
reading:
  - title: "Real World OCaml, Chapter 1: A Guided Tour"
    url: https://dev.realworldocaml.org/guided-tour.html
  - title: "Cornell CS3110, OCaml syntax and semantics"
    url: https://cs3110.github.io/textbook/chapters/basics/intro.html
---

# A tour of OCaml

:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">A tour of OCaml: values, types, and the toplevel</h2>
<p class="title-slide-label">Module 1 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: a whirlwind tour

- A working tour, not a deep dive: see the *shape* of an OCaml program.
- Building blocks you will meet today:
  - literals, arithmetic, booleans, strings;
  - `let` bindings, functions, type inference.
- The toplevel reports *type + value* for every expression.
- Mastery comes later; [Module 2](M02-L01-literals.html) onwards goes deep on each.
- Click Run on every cell. Edit them. Play.

:::

The [previous](M01-L01-course-intro.html) [two](M01-L02-why-fp.html)
lectures argued for functional programming in general and for OCaml
in particular. This lecture is different: it is the quick whirlwind
tour. By the end you will have seen, in working form, the basic
building blocks of an OCaml program: literals, arithmetic, booleans,
strings, `let` bindings, functions, and the type inference that
holds the whole thing together. You will not have mastered any of
these; [Module 2](M02-L01-literals.html) onwards goes deep on each.
The goal here is to get the shape into your head, so the rest of
the course has a frame to hang on.

Every cell on this page is runnable. The first cell takes a few
seconds to spin up the in-browser OCaml runtime; after that, each
cell evaluates instantly. Click Run on every single cell as you read.
Edit them. Try variations. The fastest way to learn a language is to
play with it, and the in-browser cells exist precisely to make
that easy.

## The toplevel

Most OCaml work happens in two places: an editor (where you write
files of code that get compiled) and a *toplevel* (an interactive
REPL where you type expressions and see results immediately). The
cells on this page are a toplevel. You type an expression, click
Run, and the toplevel responds with the value and its type.

```ocaml
1 + 2
```

The response is `- : int = 3`, read as "the result has no name (the
`-`), it has type `int`, and it equals `3`." The toplevel does this
for every expression. Type, then value. This double answer (type +
value) is unusual for a REPL; most languages just print the value.
OCaml prints the type because *the type is information* and a key
part of how you understand what your program does.

:::slide

## The toplevel

OCaml has an interactive **toplevel** (often called a REPL): you type
an expression, it tells you the value and the type.

```ocaml
1 + 2
```

The toplevel responds with `- : int = 3`, read as: "the result has no
name, has type `int`, and is equal to `3`".

:::

In a desktop install of OCaml, you would start the toplevel from
the shell by running `ocaml` (the basic one) or
[`utop`](https://github.com/ocaml-community/utop) (a nicer-to-use
version with editing and syntax highlighting). On this website,
the toplevel runs entirely in your browser via
[x-ocaml](https://github.com/art-w/x-ocaml); there is no server,
no installation, no account. Everything stays on your
machine. The same OCaml runtime that ships with the language is
compiled to JavaScript and runs locally; the only network call is
the initial download of that runtime.

## Integers

OCaml has a first-class integer type, `int`, with the standard
arithmetic operators.

```ocaml
2 + 3 * 4
```

Operator precedence works as you would expect from school: `*` binds
tighter than `+`, so this is `2 + 12 = 14`, not `(2 + 3) * 4 = 20`.
The expression evaluates to `14`, of type `int`.

Integer division uses `/`, but in OCaml as in C and Java (and unlike
in Python 3), it *truncates*: it throws away any fractional part.
Later cells in this lecture write `let _ = ...` in front of an
expression; the `_` is a "don't-care" name that just lets the
toplevel print the value without binding it to anything. We cover
the pattern in
[the lecture on `let` bindings](M02-L02-let-bindings.html#underscore-i-dont-care-about-the-name).

```ocaml
17 / 5
```

The result is `3`, not `3.4` and not `4`. The companion operator
`mod` gives you the remainder:

```ocaml
17 mod 5
```

Result is `2`, because `17 = 3 * 5 + 2`. The identity `a = (a / b) *
b + a mod b` holds whenever `b` is positive.

:::slide

## Integers

```ocaml
2 + 3 * 4
```

Standard precedence. `*` binds tighter than `+`.

Integer division truncates:

```ocaml
17 / 5
```

```ocaml
17 mod 5
```

- 63-bit on a 64-bit machine; one bit for runtime tagging.
- For arbitrary precision: [`zarith`](https://github.com/ocaml/Zarith), not built-in `int`.

:::

OCaml's `int` is a *machine integer*: on a 64-bit machine it is 63
bits wide (not 64). The missing bit is used by the runtime to
distinguish `int` values from pointers, which is part of how the
garbage collector stays fast. We will see the full story in a
later module on memory safety; for now, just know that the range
is about ±4.6 × 10^18, which is plenty for almost
any practical computation. If you need bigger, the
[`zarith`](https://github.com/ocaml/Zarith) library gives you
arbitrary precision.

## Floats

OCaml has a separate type, `float`, for IEEE-754 double-precision
floating-point numbers. The arithmetic operators on `float` are
*different from* the ones on `int`: addition is `+.`, multiplication
is `*.`, and so on. The trailing `.` is part of the operator name.

```ocaml
1.0 +. 2.5
```

The result is `3.5`, of type `float`. Try this without the dots:

```ocaml skip
1.0 + 2.5
```

This refuses to compile with an error message like *"The constant
1.0 has type float but an expression was expected of type int"*. OCaml
is telling you that `+` expects two `int` arguments, and `1.0` is a
`float`, so the call is ill-typed. If you wanted float addition,
you had to use `+.`.

:::slide

## Floats

OCaml's float operators are **distinct** from the integer ones:

```ocaml
1.0 +. 2.5
```

- `+.` instead of `+`
- `*.` instead of `*`
- `/.` instead of `/`

Mixing them is a *type error*, caught at compile time:

```ocaml skip
1 + 2.0
```

- This refuses to compile.
- Integer addition and float addition are **genuinely different operations**.
- Other languages hide that; OCaml makes it explicit.

:::

This will catch you out at first. Most other languages overload `+`
to do "whatever makes sense" given the types of its arguments:
integer add for two `int`s, float add for two `double`s, string
concatenation for two strings in Python and JavaScript. OCaml does
not do this. Every operator has *one* meaning, fixed by the symbol.

The reason is that operator overloading complicates type inference
and makes type errors hard to read. If you read `a + b` in OCaml,
you immediately know both `a` and `b` are `int` and the result is
`int`. If you read `a + b` in C++, you have to know the types of
`a` and `b` to know what the operator does. This is a trade-off
between concise syntax (overloaded `+` is shorter) and clarity
(separate operators are unambiguous), and OCaml comes down on the
clarity side. We will see this design philosophy repeated for
strings (`^` for concatenation, not `+`) and for many other
operators.

If you genuinely want to mix integer and float arithmetic in one
expression, you convert explicitly:

```ocaml
let _ = float_of_int 1 +. 2.5  (* = 3.5 *)
```

`float_of_int` is the OCaml function that turns an `int` into a
`float`. There is also `int_of_float`, which goes the other way
(and truncates). The standard library exposes these directly; in
recent versions they are also available as `Float.of_int` and
`Float.to_int` with friendlier names.

## Booleans and comparison

OCaml's boolean type is `bool` with the values `true` and `false`.
Comparison operators return `bool`.

```ocaml
1 < 2
```

Returns `true`, of type `bool`. The full set: `<`, `<=`, `>`, `>=`
for ordering, `=` for equality, `<>` for inequality.

```ocaml
"apple" = "apple"
```

Note this is `=`, not `==`. In OCaml, `=` is *structural* equality:
it compares values by content, recursively. Two strings are `=` if
they have the same bytes; two lists are `=` if they have the same
elements in the same order; two records are `=` if their fields are
correspondingly `=`. This is the operator you almost always want.

There is also `==`, which is *physical* equality (pointer
comparison). It exists for advanced uses we will see later; the
short version is: do not use `==` in your code unless you are sure
you specifically want pointer comparison. The companion negation is
`<>` for structural inequality and `!=` for physical inequality. We
revisit this distinction in the [operators lecture](M02-L04-operators.html#comparison-and-equality)
of Module 2.

```ocaml
true && (false || true)
```

`&&` and `||` are short-circuit, as in C and Java. The right
argument is only evaluated if needed.

:::slide

## Booleans and comparison

```ocaml
1 < 2
```

```ocaml
"apple" = "apple"
```

```ocaml
true && (false || true)
```

- `=` is structural equality; `==` is physical (pointer) equality.
  - Use `=`.
- `&&` and `||` short-circuit.

:::

Repeat after me: in OCaml, the everyday equality operator is `=`,
with one equals sign. The other one, `==`, is reserved for advanced
cases (pointer-identity comparison) and almost never what beginners
want. Mixing them up compiles fine and silently returns the wrong
answer, which is why it tops the list of beginner gotchas. We will
return to this in the [operators lecture](M02-L04-operators.html#comparison-and-equality).

## Strings

Strings are sequences of bytes, written between double quotes.

```ocaml
"hello, " ^ "world"
```

The concatenation operator is `^`, not `+`. Same logic as for
numeric operators: each operator has one meaning, and string
concatenation is a different operation from numeric addition, so it
gets a different operator.

```ocaml
String.length "OCaml"
```

`String.length` returns the number of bytes (which equals the number
of characters for ASCII text, but not for multibyte UTF-8 sequences).
The `String` module is the standard library's collection of string
operations: `String.length`, `String.get`, `String.sub`,
`String.concat`, and so on. We will use these throughout the course.

:::slide

## Strings

```ocaml
"hello, " ^ "world"
```

- `^` is string concatenation.
- `String.length`, `String.get`, `String.sub` for the rest.

```ocaml
String.length "OCaml"
```

:::

A practical note on Unicode: OCaml's `string` is byte-oriented, not
codepoint-oriented. `String.length "café"` (where `é` is the UTF-8
two-byte sequence) returns `5`, not `4`. For Unicode-aware string
processing, you reach for an external library like
[`uutf`](https://erratique.ch/software/uutf) for parsing,
[`uucp`](https://erratique.ch/software/uucp) for character
properties, or [`Camomile`](https://github.com/yoriyuki/Camomile)
for older codebases. Most string code you write will not need any
of these; plain `String` is fine for concatenating, slicing, and
searching bytes. We will revisit this when we cover modules in
[Module 7](M07-L06-module-basics.html).

## Let bindings

`let` is how you give a name to a value.

```ocaml
let pi = 3.14159
```

After this, `pi` is in scope and refers to the value `3.14159`. The
toplevel reports `val pi : float = 3.14159`. The keyword `val` is the
toplevel's way of saying "here is a name binding"; it is not part of
the OCaml source code.

```ocaml
let area_of_circle r = pi *. r *. r
```

Same syntax for functions. `let name args = body` defines a function
`name` taking `args` and returning the value of `body`. There is no
separate `function` keyword, no `def`, no `void`, no `public static`.

```ocaml
let _ = area_of_circle 2.0  (* = 12.56636 *)
```

Calling a function is just juxtaposition: `area_of_circle 2.0`. No
parentheses around the argument. No commas. This is the
single-biggest syntactic surprise to people coming from C or Python.

:::slide

## Let bindings

`let` names a value:

```ocaml
let pi = 3.14159
```

```ocaml
let area_of_circle r = pi *. r *. r
```

```ocaml
let _ = area_of_circle 2.0  (* = 12.56636 *)
```

- Bindings are **immutable** by default.
- `let pi = 3.14159` does NOT create a variable cell; just names a value.
- Calling a function: juxtaposition, no parentheses.

:::

Two important things to internalise about `let` bindings:

**Bindings are immutable by default.** When you write `let pi =
3.14159`, you are not declaring a variable that you will later
reassign. You are introducing a name for a value, and that name
refers to that value, period. There is no `pi = 3.14160` later to
"update" it. If you wanted to refer to a different number, you
introduce a new name. This is one of the cultural shifts from
imperative programming; we discussed it in
[the previous lecture](M01-L02-why-fp.html#immutability-in-practice).

**Bindings are not addresses.** In C, `int pi = 3` allocates a slot
in memory and stores 3 there; later, `pi = 4` writes 4 to that
slot. In OCaml, `let pi = 3.14159` does *not* allocate anything;
it just introduces a name. The compiler is free to inline the value
wherever the name is used, share it across uses, or skip allocating
anything for it at all. Names are not storage.

## Let in expressions

You can introduce a name local to an expression with `let ... in`:

```ocaml
let circle_area r =
  let r_sq = r *. r in
  3.14159 *. r_sq
```

The name `r_sq` is in scope from the `in` keyword to the end of the
enclosing expression (in this case, the body of `circle_area`).
Outside that scope, `r_sq` does not exist.

```ocaml
let _ = circle_area 5.0  (* = 78.53975 *)
```

This is the local-binding form. `let ... in` is an *expression*: the
whole thing `let r_sq = r *. r in 3.14159 *. r_sq` is an
expression that evaluates to the value of its body, with `r_sq`
bound during evaluation. You can nest these freely.

:::slide

## Let in expressions

`let ... in ...` lets you name an intermediate value inside a larger
expression:

```ocaml
let circle_area r =
  let r_sq = r *. r in
  3.14159 *. r_sq
```

```ocaml
let _ = circle_area 5.0  (* = 78.53975 *)
```

The name `r_sq` is in scope inside the body of `circle_area` and
nowhere else.

:::

There are two `let` forms and they look very similar; do not confuse
them. At the top level (in the toplevel or at the start of a file),
`let name = value` introduces a *global* binding that is visible
from that point onward. Inside an expression, `let name = value in
expr` introduces a *local* binding that is in scope only inside
`expr`. They are different things: the first is a declaration, the
second is an expression.
[Module 2 spends a full lecture on this distinction](M02-L02-let-bindings.html).

## Shadowing

You can introduce a binding with a name that already exists in
scope. The new binding *shadows* the old one for any subsequent
reference to that name, but the old binding is still there
(immutability!); you just cannot reach it by name anymore.

```ocaml
let x = 1
let x = x + 1
let y = x
```

After these three lines, `y = 2`. Read the second line carefully:
`let x = x + 1`. On the *right-hand side* of the `=`, the name `x`
still refers to the old binding (where `x = 1`), so `x + 1 = 2`.
After the binding completes, the name `x` now refers to this new
value, `2`. The third line, `let y = x`, picks up the *new* `x`,
so `y = 2`.

:::slide

## Shadowing

You can rebind a name to a new value. The old binding is **shadowed**,
not mutated:

```ocaml
let x = 1
let x = x + 1
let y = x
```

- After: `y = 2`.
- The first `x` (`= 1`) is **no longer reachable by name.**
- If earlier code captured it, that value is still alive, still `1`.

:::

The phrase "old binding is still there" is worth dwelling on,
because it captures a subtle but important point. If, before the
second `let x = x + 1`, you defined a function that *captured* the
first `x`, that function continues to see `x = 1` forever. The
binding it captured is unchanged; the *name* `x` now points to
something different, but the original value is alive as long as the
function holds it. This is one of the consequences of immutability:
captures are stable.

## Type inference

This is OCaml's signature feature. The compiler works out the types
of your expressions and functions automatically; you do not have to
write them down.

```ocaml
let add x y = x + y
```

The toplevel reports `val add : int -> int -> int = <fun>`. This is
the type of `add`: it takes two `int`s and returns an `int`. The
notation `int -> int -> int` is read right-associatively: it is
"function from `int` to (function from `int` to `int`)". We will
unpack this thoroughly in [Module 3 when we cover currying](M03-L03-currying.html).

How did OCaml know that `x` and `y` are `int`? It saw the `+`
operator. `+` requires both arguments to be `int`, so the
expression `x + y` forces both `x` and `y` to have type `int`. The
result of `+` on two `int`s is an `int`, so `add x y` returns
`int`. The compiler chains these constraints together and reports
the resulting type.

:::slide

## Type inference

OCaml *infers* types. You almost never have to write them down:

```ocaml
let add x y = x + y
```

The toplevel reports `val add : int -> int -> int = <fun>`.

----

OCaml has worked out that:

- `x + y` uses integer addition, so both `x` and `y` must be `int`.
- The result of `+` on ints is an `int`, so `add x y` is `int`.

Without writing a single type annotation.

:::

Type inference is what makes OCaml feel as light to write as
Python, even though the language is statically typed. You get the
safety of a strong type system without the syntactic burden of
writing types everywhere. In Java, you write `int x = 5;` because
the compiler insists. In OCaml, you write `let x = 5` and the
compiler figures out `x : int` itself. Multiply this by ten
thousand bindings in a real program and the verbosity savings
are large.

```ocaml
let add_f x y = x +. y
```

The toplevel reports `val add_f : float -> float -> float = <fun>`.
Same inference, different constraint: `+.` requires `float`
arguments, so the function has type `float -> float -> float`.

:::slide

## Inference for floats

```ocaml
let add_f x y = x +. y
```

- Toplevel: `val add_f : float -> float -> float = <fun>`.
- `+.` constrains the arguments to be `float`.
- That's the whole trick; no "guess what the user meant" heuristics.

:::

A useful pedagogical point: *the operator drives the inference*.
When you look at OCaml code and want to know the types, look at the
operators. `+` says int. `+.` says float. `^` says string. `&&`
says bool. `::` (which we have not seen yet) says list. Each
operator has a fixed type, and the rest of the inference falls out
from there. Reading OCaml type errors well is largely about
identifying which operator created the constraint that the compiler
is complaining about.

## Type annotations, when you want them

You *can* write explicit type annotations. They are not required
and are usually omitted, but they are sometimes useful.

```ocaml
let double (x : int) : int = x + x
```

The annotation `(x : int)` says that `x` is `int`; the `: int` after
the parameter list says the return type is `int`. The compiler
checks that the annotations agree with what it would have inferred;
if you write a wrong annotation, you get a type error.

```ocaml
let triple : int -> int = fun x -> x + x + x
```

Same idea, a different syntax: a top-level type annotation on the
whole function. The `fun x -> ...` syntax is OCaml's
[lambda](M03-L01-functions-as-values.html#anonymous-functions-in-expressions);
we will come back to it in Module 3.

:::slide

## Annotations, when you want them

You can write types explicitly. They have to *agree* with what OCaml
would have inferred, otherwise it's a type error:

```ocaml
let double (x : int) : int = x + x
```

```ocaml
let triple : int -> int = fun x -> x + x + x
```

- Most of the time: leave them off.
- On public APIs: put them on for documentation.

:::

The OCaml community convention is to leave type annotations off
local helpers and put them on top-level functions in a module's
public interface (its `.mli` file, which we will cover in
[Module 7](M07-L07-signatures.html#signatures-in-mli-files)).
Annotations on public APIs are documentation: they tell the reader
what the function expects without forcing the reader to read its
body. Annotations on private code clutter without paying their way,
because the compiler already knows the types.

## Putting it together

A worked example combining what we have seen:

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15
let boiling_kelvin = kelvin_of_celsius 100.0
let back_to_celsius = celsius_of_kelvin boiling_kelvin
```

Walk through what the toplevel reports for each binding:

- `kelvin_of_celsius : float -> float = <fun>`: takes a float
  (the operator `+.` forces this), returns a float.
- `celsius_of_kelvin : float -> float = <fun>`: same pattern.
- `boiling_kelvin : float = 373.15`: a `float` value, the result
  of `100.0 + 273.15`.
- `back_to_celsius : float = 100.0`: round-trips, as expected.

:::slide

## Putting it together

```ocaml
let kelvin_of_celsius c = c +. 273.15
let celsius_of_kelvin k = k -. 273.15
let boiling_kelvin = kelvin_of_celsius 100.0
let back_to_celsius = celsius_of_kelvin boiling_kelvin
```

What does the toplevel say about each binding? Type, value? Walk
through it.

:::

This is the rhythm of OCaml work: define small functions, call them
on values, look at the toplevel's response, build up. Names compose
into expressions, expressions become values, values become
arguments to the next function. There are no statements; there is
no main; there is just expression after expression, each producing
a value.

## A quick check

:::quiz mcq id=M01-L03-q3
What does the toplevel print for `let pi = 3.14`?

- [ ] `pi : float = 3.14`
- [x] `val pi : float = 3.14`
- [ ] `let pi = 3.14`
- [ ] Nothing; bindings are silent.

**Why:** the toplevel reports new bindings with the `val` keyword,
followed by the name, type, and value. The shape is exactly `val
NAME : TYPE = VALUE`. This is a formatting convention of the
toplevel itself, not part of the OCaml source.
:::

Now a small code challenge. Try to make this pass:

:::quiz code id=M01-L03-q2
Define a function `fahrenheit_of_celsius : float -> float` that
converts Celsius to Fahrenheit using the formula `F = C * 9/5 + 32`.
Watch the operators: you are working with floats.

```ocaml
let fahrenheit_of_celsius c =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (fahrenheit_of_celsius 0.0 = 32.0)  "0 C = 32 F";
  check (fahrenheit_of_celsius 100.0 = 212.0) "100 C = 212 F";
  check (fahrenheit_of_celsius (-40.0) = -40.0) "-40 C = -40 F";
  print_endline "all tests passed"
```
:::

If you got it: well done. If you got a "this expression has type
int but an expression was expected of type float" error, that is
the operator-mismatch error: you probably wrote `9 / 5` (integer
division, which truncates to `1`) instead of `9.0 /. 5.0`.

## Activity

:::slide

## Activity

What is the type of:

```ocaml
let f x = x +. 1.0
```

And why is it not `int -> int`?

Take a moment, then peek.

:::

:::quiz mcq id=M01-L03-q1
What is the type of `let f x = x +. 1.0` in OCaml?

- [ ] `int -> int`
- [ ] `int -> float`
- [x] `float -> float`
- [ ] OCaml cannot infer this without an annotation.

**Why:** `+.` is the *float* addition operator. Its left operand
must be `float` (and so must its right). The constant `1.0` is
already a `float`. Therefore `x` must be `float`, and `x +. 1.0`
returns a `float`. So `f : float -> float`. If we had written `+`
instead, OCaml would have inferred `int -> int` (the operator
determines the type).
:::

:::slide

## Activity discussion

`f : float -> float`.

- `+.` forces `x` to be `float`.
- Result is `float`. Function is `float -> float`.
- If we'd written `+`: `int -> int` instead.

**The operator drives inference.** That's the whole trick to reading OCaml type errors.

:::

The operator drives the inference. OCaml's type system has no
"this could be either an int or a float, you decide" notion. Every
expression has exactly one type, determined by its operators. When
the compiler complains about a type mismatch, the first thing to
look at is which operator forced which type.

## What's next

Module 1 has two more lectures: a [hello-world walkthrough](M01-L04-hello-world.html)
and the [Module 1 tutorial](M01-L05-tutorial-recap.html). After
those, [Module 2](M02-L01-literals.html) zooms in on expressions:
how `let` bindings work in depth, how type inference handles more
complex cases, how `if`/`then`/`else` is an expression (not a
statement), and how all of these compose into real, if small,
programs.

:::slide

## What's next

- **L04:** [hello-world walkthrough](M01-L04-hello-world.html).
- **L05:** [Module 1 tutorial](M01-L05-tutorial-recap.html).
- **Module 2:** zooms into expressions: literals, `let` bindings,
  operators, type inference, `if`/`then`/`else`.

:::

## Reading

- **Real World OCaml**, *A Guided Tour*: free online, covers very
  similar ground at a more leisurely pace:
  <https://dev.realworldocaml.org/guided-tour.html>
- **Cornell CS3110**, *OCaml syntax and semantics*: the textbook
  treatment of the same material:
  <https://cs3110.github.io/textbook/chapters/basics/intro.html>
- John Whitington, *OCaml from the Very Beginning*, Chapter 1:
  even gentler pace if you want a step-by-step introduction.
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
