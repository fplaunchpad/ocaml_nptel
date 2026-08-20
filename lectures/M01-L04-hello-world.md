---
title: "Your first OCaml program: hello, world (and beyond)"
lecture_no: 4
week: 1
duration_target_min: 20
concepts: [print_endline, top-level evaluation, let bindings as statements, the unit type]
keywords: [OCaml, hello world, print_endline, unit, let, beginner OCaml]
activity_question: "A file has two top-level [let ()] bindings: the first prints [A] then [B] (sequenced with [;]), the second prints [C]. In what order do the three lines appear? Predict before running."
think_about_this: "Why does OCaml use the unit value [()] for the result of [print_endline] instead of returning a void / null / None?"
reading:
  - title: "Real World OCaml, Chapter 1: A Guided Tour"
    url: https://dev.realworldocaml.org/guided-tour.html
  - title: "Cornell CS3110, The OCaml toplevel"
    url: https://cs3110.github.io/textbook/chapters/basics/intro.html
---

# Your first OCaml program


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Your first OCaml program: hello, world (and beyond)</h2>
<p class="title-slide-label">Module 1 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: hello, world

- Our first program that *runs*: visible output to the world.
- Two concepts you will use in every program from here on:
  - the `unit` type (the value `()`);
  - the sequencing operator `;`.
- An OCaml program is a *sequence of `let` bindings*.
- Different shape from C's `int main()` or Python's `if __name__`.
- Short lecture; the shape matters.

:::

In the [previous lecture](M01-L03-ocaml-tour.html) we toured the
values and expressions of OCaml: numbers, booleans, strings, `let`
bindings, type inference. We have not yet written anything that
*runs* in the sense of "does something visible to the world." This
short lecture closes that gap. We will write the canonical first
program in any language, talk about what makes it work in OCaml
specifically, and introduce two concepts you will use in every
program from here on: the `unit` type and the sequencing operator
`;`.

The lecture is short because the material is simple. The reason it
deserves its own lecture is that OCaml's "hello world" looks slightly
different from the equivalent in C, Java, or Python, and the
difference is worth understanding properly before you move on. The
shape of an OCaml program is *a sequence of `let` bindings*, and that
shape is not obvious if you arrive from a language where programs
look like `int main() { ... }` or `if __name__ == "__main__": ...`.

## Hello, world

Here is the shortest interesting OCaml program. Click Run.

```ocaml
let () = print_endline "hello, world"
```

The cell prints `hello, world` on its own line, and that is all:
there is no `val ...` report. Every `let` binding you ran in the
previous lecture earned an echo like `val x : int = 42`, but a
`let ()` binding binds *no names*, so there is nothing for the
toplevel to report. The output of the program is the string; the
absence of a `val` line tells us the binding exists purely for
its side effect.

:::slide

## Hello, world

```ocaml
let () = print_endline "hello, world"
```

Click **Run**.

- Prints `hello, world`, and nothing else.
- No `val ...` report: `let () = ...` binds no name.

We just wrote an executable program.

:::

That single line is doing more than it looks. Let's read it carefully,
because every piece is doing real work and you will see this shape
in essentially every OCaml file you ever write.

## Reading the line

```ocaml
let () = print_endline "hello, world"
```

Parsed left to right:

- `let () = ...` is a binding. The pattern on the *left* of the `=`
  is `()` (the empty tuple, also the only value of the `unit` type).
  The expression on the *right* is what we are binding.
- `print_endline "hello, world"` is a function application. The
  function is `print_endline`, defined in the standard library; the
  argument is the string `"hello, world"`. The function writes the
  string to standard output, followed by a newline. Its return
  value is `()`.

:::slide

## Reading the line

```ocaml
let () = print_endline "hello, world"
```

Parsed left to right:

- `let () = ...` binds the right-hand side to the pattern `()`
  (the only value of `unit`).
- `print_endline "hello, world"`: function call; writes the string
  and returns `()`.
- The `let () = ...` form says: *evaluate for the side effect,
  assert the value is unit*.

:::

Read together, the line says: "evaluate `print_endline "hello,
world"` (which writes the string, has return type `unit`), and
match the resulting `()` against the pattern `()` (which always
succeeds, because the right-hand side is `unit` and `()` is the
only `unit` value)." The match-against-`()` part may sound silly
("of course it succeeds; there is nothing else it could be"); the
point is that we are *checking* the type. If you accidentally wrote
`let () = 42`, the compiler would reject it because `42` is not
`unit`. The pattern serves as a type assertion.

This is the standard idiom for "a side-effecting expression executed
at the top level." The shape is `let () = EXPR` where EXPR is
something whose return value you do not care about (typically a
print or a write). It tells anyone reading your code: this line is
here for its effect.

## What is `unit`?

OCaml has a type called `unit` whose only value is written `()`. The
notation is suggestive: `()` is the empty tuple. Just as `(1, 2)` is
a pair and `(1, 2, 3)` is a triple, `()` is a "zero-tuple", and the
type of zero-tuples is `unit`. There is exactly one such value, so
the type carries no information beyond its own existence.

If `unit` carries no information, why does the language bother to
have it? The answer is that OCaml is an *expression*-based language:
every construct, including ones with side effects, has a value of
some type. Even `print_endline`, which seems to be "all side effect,
no value", has to return *something* so it has a type. That
something is `()`, of type `unit`. The convention is that any
function whose purpose is the side effect (not the return value)
returns `unit`.

:::slide

## What is `unit`?

- OCaml's "no useful value" type.
- Exactly one value, written `()` (empty tuple).
- Functions that exist for their side effects return `unit`.

```ocaml
let _ = print_endline "first"
let _ = print_endline "second"
let _ = print_endline "third"
```

- Three side-effecting calls, each returning `()`.

:::

:::notes
Some students find unit weird at first. The analogy is C's [void]:
"this function returns nothing useful, but the call exists for the
effect." Unlike C, OCaml's unit *is* a real value (you can store it,
pattern-match against it), it's just the only one of its type.
:::

The closest analogue in other languages is C's `void`, Java's
`void`, Python's `None`, Rust's `()` (which Rust took from the ML
family). All of these mean "this function does not return a useful
value." The difference from `void` is that in OCaml (as in Rust),
`unit` is a real type with a real value `()`. You
can store `()` in a list (`[(); (); ()]` is a valid OCaml list of
length 3) or return `()` from a function. Storing and returning
are unusual; the value carries no information so it is hard to
do anything useful with one. *Taking* `()` as an argument, on
the other hand, is everyday OCaml: `fun () -> ...` is the standard
idiom for a *thunk*, a computation deferred until someone calls
it. You will see this all over the standard library and the
ecosystem.

The phrase "no useful value" is doing a lot of work. `unit` is the
*absence* of information, but it is the absence-as-a-value, not the
absence-as-a-type-system-feature. This distinction will matter again
when we get to [`Option`](M04-L04-recursive-types.html) (Module 4),
which is the way OCaml handles "this function might or might not
return a useful value." `Option` is *not* the same as `unit`; the
two answer different questions.

:::quiz mcq id=M01-L04-q3
Which of these expressions has type `unit`?

- [ ] `42`
- [ ] `"hello"`
- [x] `print_endline "hi"`
- [ ] `1 + 1`

**Why:** `unit` is the type of expressions that exist for their side
effect: their only useful behaviour is what they *do*, not what they
return. `print_endline` writes its argument to stdout and returns
`()` (the only value of type `unit`). The other three return values
of types `int`, `string`, and `int` respectively. Note: it is not
that `42` *cannot* be `unit`; the literal `42` has type `int`,
period. You cannot "cast" a non-unit value to `unit` (though you
*can* discard a value with `let _ = ...` or `ignore ...`, which we
will see soon).
:::

## A program is a sequence of `let` bindings

Now that we have the shape of one binding, we have the shape of an
entire OCaml program. A program is, at the top level, a sequence of
`let` bindings, evaluated in order from top to bottom.

```ocaml
let greeting = "hello, "
let name = "NPTEL"
let () = print_endline (greeting ^ name)
```

Three lines, three bindings. The first two bind names to string
values; the third binds the side-effect of `print_endline` to `()`.
Each later binding can refer to names introduced by earlier ones.

:::slide

## A program is a sequence of `let` bindings

```ocaml
let greeting = "hello, "
let name = "NPTEL"
let () = print_endline (greeting ^ name)
```

- Three `let` lines: two value bindings, one print.
- Order matters: each `let` can refer to names bound above it.

:::

Compare this to the Java equivalent, which would be something like:

```java
public class Hello {
    public static void main(String[] args) {
        String greeting = "hello, ";
        String name = "NPTEL";
        System.out.println(greeting + name);
    }
}
```

The Java version has substantial scaffolding: a class declaration, a
main method, a special argument convention. The OCaml version is
just three lines of bindings. There is no main, no class, no
boilerplate. The compiler treats the file as a sequence of
bindings; when you compile and run the program, those bindings are
evaluated in order. Side effects (like printing) happen as their
bindings are evaluated.

This is more like Python or a Bash script in that respect: a file
of statements that run top-to-bottom. The difference from Python is
that every "statement" in OCaml is really a `let` binding (or
sometimes a `module` declaration, which we will see in
[Module 7](M07-L06-module-basics.html)). There are no bare
statements; every line of code is binding something to a name. Even
`let () = print_endline "x"` is "binding the value `()` to the
pattern `()` (i.e. type-checking it as unit) while evaluating the
right-hand side for its effect."

## Worked example with names

A slightly less trivial program:

```ocaml
let pi = 3.14159
let radius = 5.0
let area = pi *. radius *. radius
let () = print_endline (Printf.sprintf "area = %.4f" area)
```

Four bindings. The first three are pure value bindings: `pi`,
`radius`, and `area` get their values. The fourth is the printing
side effect. `Printf.sprintf` is like `printf` from C, but it
returns the formatted string instead of writing to stdout. On its
own:

```ocaml
let msg = Printf.sprintf "area = %.4f" 3.14159  (* = "area = 3.1416" *)
```

The format string comes first, then one argument per `%` specifier;
the result is an ordinary `string` you can bind, concatenate, or, as
in the program above, hand to `print_endline`. The specifier `%.4f`
means "a `float`, four digits after the decimal point," same as in
C's printf.

:::slide

## Naming a value, then using it

```ocaml
let pi = 3.14159
let radius = 5.0
let area = pi *. radius *. radius
let () = print_endline (Printf.sprintf "area = %.4f" area)
```

- `Printf.sprintf` returns the formatted string; `print_endline` prints it.
- `%.4f`: a float, four digits after the decimal point.

:::

The `Printf` module provides type-safe formatted output: the
compiler reads the format string at compile time, infers the types
required by each `%` specifier, and checks them against the
arguments you pass. If you write `Printf.sprintf "%d" 3.14`, OCaml
rejects it at compile time, because `%d` expects an `int` but `3.14`
is a `float`. This is unusual; in C, format-string mismatches are
runtime bugs (or, with newer compilers, lint warnings). OCaml puts
them in the type system. We will not dwell on Printf now; just
know that it works and that the format specifiers are the same as
C's.

## What if you forget `let ()`?

The toplevel is more permissive than a compiled file. You can type a
bare expression and the toplevel will evaluate it.

```ocaml
print_endline "hello"
```

This prints "hello" and the toplevel reports `- : unit = ()` (no
binding name). At the file level, when you save this to a `.ml`
file and compile it, you would get a warning ("this expression
should have type unit") unless you wrap it in `let () = ...`. The
warning exists because a bare expression at the file level usually
indicates a mistake: you wrote a computation and then *forgot to
do anything with the result*.

A useful habit: always wrap top-level side-effecting calls in `let
() = ...`, even in the toplevel where you don't strictly need to.
It documents intent and catches accidents.

:::slide

## What happens if you forget `let ()`?

```ocaml
print_endline "hello"
```

- Toplevel accepts a bare expression.
- File compiler wants `let () = ...`.
- Habit: always wrap side-effecting calls in `let () = ...`.

:::

:::slide

## Why bother: `let () = 42` is refused

```ocaml skip
let () = 42
```

- The `()` pattern declares the RHS must have type `unit`.
- `42` is `int`, not `unit`: compile-time error.
- Documents intent and catches the kind of accident you can't see by eye.

:::

The `let () = 42` example above is useful as a teaching case.
Press **Run** on the cell; the compiler refuses with an
error message like *"The constant 42 has type int but an
expression was expected of type unit."* This is
the pattern-match-as-type-check property doing its job. You said
the result should be `()`; the compiler checked that you actually
produced a `unit`; you didn't (you produced an `int`); the
compiler complains.

If you ever genuinely want to *discard* a non-unit value at the top
level, the idiom is `let _ = EXPR`. The `_` pattern matches anything
and the compiler does not complain about the type. This is fine for
discarding the result of a function whose effect you wanted but
whose return value you do not need.

## Sequencing with `;`

A common need: do several side-effecting things in order. The OCaml
operator for this is `;` (a single semicolon). It sequences two
expressions: evaluate the first (which must have type `unit`), then
evaluate the second, and the whole expression has the type of the
second.

```ocaml
let square x = x * x
let cube x = x * x * x

let () =
  Printf.printf "square 5 = %d\n" (square 5);
  Printf.printf "cube 5   = %d\n" (cube 5);
  Printf.printf "square 5 + cube 5 = %d\n" (square 5 + cube 5)
```

:::slide

## A small interactive program

```ocaml
let square x = x * x
let cube x = x * x * x

let () =
  Printf.printf "square 5 = %d\n" (square 5);
  Printf.printf "cube 5   = %d\n" (cube 5);
  Printf.printf "square 5 + cube 5 = %d\n" (square 5 + cube 5)
```

- Two helpers, then one `let ()` that sequences three prints.
- `;` sequences side-effecting expressions.
- Run it; expect three lines.

:::

Two function definitions and then one `let () = ...` whose
right-hand side is three printing expressions sequenced together
with `;`. Run it; you should see three lines.

There is a small subtle thing about `;` worth knowing: its left
operand has to be `unit`. If you write `e1; e2` where `e1` does not
have type `unit`, the compiler warns you: "this expression should
have type unit". The warning exists because semicolon-sequencing is
*for* side effects; if `e1` produces a value that is not `unit`,
you are throwing that value away, which is almost always a mistake.

If you genuinely want to throw a non-unit value away (rare, but it
happens), use `ignore e1; e2`. The `ignore` function takes anything
and returns `()`, suppressing the warning.

## Single `;` versus double `;;`

You may have seen `;;` in OCaml tutorials or books, and wondered
how it differs from `;`. They are very different things.

- `;` is the **sequencing operator** in the expression language. It
  sequences two expressions; the left must be `unit`. You use it
  inside an expression (typically inside a `let () = ...` body).
- `;;` is a **phrase separator** between top-level definitions. In
  the OCaml toplevel (the interactive REPL) it doubles as "end of
  input; please evaluate now", which is why tutorials that show
  toplevel transcripts are sprinkled with it. In a `.ml` file the
  compiler can almost always tell where one definition ends and
  the next begins (the keywords `let`, `type`, `module`, and so
  on, mark the boundary), so `;;` is grammatical but redundant
  and idiomatic code omits it.

:::slide

## Two semicolons are different from one

- `;` (single) sequences side-effecting expressions; left side must be `unit`.
- `;;` (double) separates top-level definitions. The interactive
  toplevel also uses it as "end of input; evaluate now".
  - Grammatical in `.ml` files but redundant; idiomatic code omits it.

```ocaml
let () =
  print_endline "first";
  print_endline "second"
```

:::

If you copy-paste code from an old OCaml tutorial that uses `;;`
between every declaration, the code still compiles, but the `;;`
is redundant: you can leave it in or take it out without changing
the meaning. Modern OCaml code rarely uses `;;`. In this course
we will not use it.

## A small code challenge

:::quiz code id=M01-L04-q2
Define `make_greeting : string -> string` that returns the string
`hello, NAME!`, where `NAME` is the function's argument. The
provided `greet` prints that string on its own line. The tests
check the exact string, so mind the comma, the space, and the `!`.

```ocaml
let make_greeting name =
  failwith "not implemented"

let greet name = print_endline (make_greeting name)
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (make_greeting "world" = "hello, world!") "greeting for world";
  check (make_greeting "alice" = "hello, alice!") "greeting for alice";
  greet "world";
  print_endline "all tests passed"
```
:::

Hint: build the string with `^` (string concatenation) or
`Printf.sprintf`. If you use `Printf.sprintf`, you may want
`"hello, %s!"` as the format string.

## Activity

:::slide

## Activity

What does this program print?

```ocaml
let () =
  print_endline "A";
  print_endline "B"

let () = print_endline "C"
```

Predict before pressing Run.

:::

:::quiz mcq id=M01-L04-q1
What does the following OCaml program print?

```ocaml skip
let emit x = print_endline x

let () =
  emit "A";
  emit "B"

let () = emit "C"
```

- [x] A, then B, then C
- [ ] C, then A, then B
- [ ] A and C; B is unreachable
- [ ] The program does not compile.

**Why:** top-level `let` bindings execute in source order. Defining
`emit` prints nothing; it only creates a function. The first
`let () = ...` then uses `;` to call it twice, printing A then B.
The final `let () = ...` runs afterward and prints C.
:::

:::slide

## Activity discussion

`A`, then `B`, then `C`.

- Top-level `let` bindings execute **in order, top to bottom**.
- First `let ()`: sequenced body prints `A` then `B`.
- Second `let ()`: prints `C`.
- An OCaml program is a sequence of top-level bindings.

:::

This is what an OCaml program is, in the simplest form: a file of
`let` bindings, evaluated top to bottom, where some bindings have
side effects. There is no `main()`. There is no entry point. The
file is the program; its bindings are the steps. Later, when we
introduce [modules](M07-L06-module-basics.html) (Module 7), we will
see how to organise larger programs into structured units, but the
basic shape stays the same.

## What's next

We have covered the surface mechanics of writing a program. The
[next lecture](M01-L05-tutorial-recap.html) is Module 1's tutorial:
worked temperature-conversion problems end to end. After that, next
week ([Module 2](M02-L01-literals.html)) we slow down and look at
the type system: what `int`, `float`, `string`, `bool` really are,
how type inference works, how `if`/`then`/`else` is an *expression*
(not a statement), and how all of these compose into more
interesting programs. By the end of Module 2 you will be writing
real (if small) functions in OCaml comfortably.

:::slide

## What's next

- **Next:** [Module 1's tutorial](M01-L05-tutorial-recap.html):
  worked temperature-conversion problems end to end.
- **Then Module 2:** the type system in detail (`int`, `float`,
  `string`, `bool`), type inference, `if` as an expression.

:::

## Reading

- **Real World OCaml**, *A Guided Tour*: still the best
  short-form companion to this material:
  <https://dev.realworldocaml.org/guided-tour.html>
- **Cornell CS3110**, *The OCaml toplevel*:
  <https://cs3110.github.io/textbook/chapters/basics/intro.html>
- John Whitington, *OCaml from the Very Beginning*, Chapters 1-2:
  parallel reading at a gentler pace.
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
