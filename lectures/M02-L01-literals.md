---
title: "Literals: integers, floats, booleans, strings"
lecture_no: 1
week: 2
duration_target_min: 22
concepts: [primitive types, literal syntax, OCaml number representation, string syntax]
keywords: [OCaml, int, float, bool, string, literals, primitive types]
activity_question: "What is the type of [3 / 2] in OCaml? What does it evaluate to? Now: what is the type of [3.0 /. 2.0], and what does it evaluate to?"
think_about_this: "Why does OCaml use a separate operator [/.] for floating-point division, instead of letting [/] do the right thing depending on its operands?"
reading:
  - title: "Real World OCaml, Chapter 1: A Guided Tour (numbers section)"
    url: https://dev.realworldocaml.org/guided-tour.html
  - title: "Cornell CS3110, Basic types and values"
    url: https://cs3110.github.io/textbook/chapters/basics/expressions.html
---

# Literals


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Literals: integers, floats, booleans, strings</h2>
<p class="title-slide-label">Module 2 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

:::slide

## This lecture: literals and types

- Almost every piece of an OCaml program is an *expression*.
- Static semantics (type-check) before dynamic semantics (evaluate).
- A *literal* is an expression that is already a value: `5`, `3.14`, `true`, `"hi"`.
- Four primitive kinds dominate everyday code: `int`, `float`, `bool`, `string`.
- OCaml's choices here differ from C, Python, Java; the differences are deliberate.
- Why `1 + 2.0` fails, why `^` not `+` on strings, why `=` is not `==`.

:::

## Expressions

Almost every meaningful piece of an OCaml program is an
*expression*: a piece of syntax that the language evaluates to
produce a value. (Top-level declarations like `let x = e` bind
names; the interesting part of each declaration is the expression
`e` on the right-hand side.) An expression has two things,
*syntax* (how you write it) and *semantics* (what it means). The
semantics in turn split in two:

- *Static semantics* are the type-checking rules. Before any
  evaluation happens, OCaml checks the expression and either
  produces a type or rejects it with an error message.
- *Dynamic semantics* are the evaluation rules. If type-checking
  succeeded, OCaml then evaluates the expression to produce a
  *value* (or it raises an exception, or it runs forever).

Crucially, evaluation rules apply *only to expressions that
type-check*. This is the static-vs-dynamic-language line:
statically typed languages like OCaml refuse to run an ill-typed
expression, where dynamically typed languages (Python, JavaScript)
start running anyway and may discover the type mismatch only at
runtime.

:::slide

## Expressions

Every expression has:

- **Syntax**: how you write it.
- **Semantics**: what it means.
  - *Static* (type-checking): produces a type, or fails with an
    error.
  - *Dynamic* (evaluation): produces a value (or an exception, or
    diverges).
- Dynamic rules apply **only to expressions that type-check**.
  (Static vs. dynamic languages.)

:::

## Values

A *value* is an expression that does not need any further
evaluation. The literal `5` is already a value: there is nothing
left to compute. The expression `2 + 3` is *not* a value: it still
has work to do, namely the dynamic semantics of `+`, which reduces
it to `5`. Every successful evaluation in OCaml ends at a value.

Values form a *subset* of expressions: every value is an
expression, but not every expression is a value. Evaluation is the
process of taking a non-value expression and reducing it to one
inside that inner ring.

:::slide

## Values

- A **value** is an expression that does not need further
  evaluation.
- `5` is a value. `2 + 3` is not: it still has work to do.
- Evaluation reduces an expression to a value (or fails).

<figure class="diagram values-diagram">
  <img src="/assets/m02/figures/val-expr.svg"
       alt="Values are a subset of expressions"
       style="max-height: 360px;">
</figure>

:::

## Literals

The simplest expressions are the ones that are *already values*:
they need no evaluation at all. We call those *literals*. OCaml's
primitive literal kinds are `int`, `float`, `bool`, `char`,
`string`, and `unit`. This lecture spends the bulk of its time on
the four that dominate everyday code: integers, floating-point
numbers, booleans, and strings. `char` (a single byte, written
`'a'`) shows up briefly in the strings section, and `unit` (the
single value `()`, used as a placeholder when there is nothing
meaningful to return) was introduced in
[the hello-world lecture](M01-L04-hello-world.html#what-is-unit)
and returns in Module 3 alongside unit-taking functions. The
choice of "primitive" is the language
designer's: these are the kinds the compiler knows about
intrinsically, with dedicated syntax and built-in operators.
Every other value in the language, from a list of pairs to a
record of records, is ultimately built up out of literals like
these.

It is tempting to skip past this material as obvious; you have
written `int`s and `string`s in five other languages already. Resist
that urge. OCaml makes a number of deliberate choices in this corner
of the language that are different from what C, Python, or Java do,
and the reasons behind those choices reveal a lot about how the rest
of OCaml works. Why does `1 + 2.0` fail to compile? Why is there a
separate `^` for string concatenation when `+` was right there? Why
does `=` mean something different from `==`? Each of these has an
answer that we will use again, in much heavier form, when we look
at functions, modules, and the type system.

If you are watching the video, the slides are the spine; the prose
below is what you read once the video is over, the way you would
read a textbook chapter on the same material.

:::slide

## Primitive literal kinds

| Type | Example literal | What it represents |
| --- | --- | --- |
| `int` | `42`, `-7`, `0` | Whole number, signed, 63-bit on 64-bit |
| `float` | `3.14`, `2.0` | IEEE-754 double-precision |
| `bool` | `true`, `false` | Boolean |
| `char` | `'a'`, `'\n'` | Single byte |
| `string` | `"hello"`, `""` | Byte string |
| `unit` | `()` | The single placeholder value |

- Each literal is its own value.
- Compiler **infers** every literal's type.
- No `int x = 5;`. Just `let x = 5`.

:::

The first row of that table, `int`, deserves a longer look. The
others are mostly variations on what you already expect, but OCaml's
integers come with one small surprise that explains a lot of design
choices later in the language.

## Integers

OCaml's `int` is a *machine integer*: a fixed-width signed integer
that fits in a single register on whatever CPU you are running. On
the 64-bit machines that essentially every student has today, that
register is 64 bits wide. You might therefore expect OCaml's `int`
to give you the full 64-bit range, from `-2^63` up to `2^63 - 1`.
It does not. OCaml's `int` is 63 bits wide, with a range of about
`-4.6 × 10^18` to `4.6 × 10^18`.

Where did the missing bit go? The runtime stole it. OCaml needs a
way, at runtime, to tell an immediate integer apart from a pointer
to a heap-allocated object. The garbage collector, in particular,
has to walk every value the program is holding and decide whether
to follow it as a pointer or treat it as an inline scalar. The
trick OCaml uses is to set the low bit of every immediate integer
to `1`, and arrange the heap so that every pointer is even (its low
bit is `0`). One bit-test then suffices to classify any word in
memory. That stolen low bit costs us one bit of integer range, but
it makes the GC fast and predictable, and it is part of why OCaml
programs can run within a small constant factor of equivalent C
code.

You will not see this tagging in your code: it happens entirely at
the runtime level. The only place it surfaces for the programmer
is the slightly narrower `int` range. If you really need a true
64-bit integer, the standard library has a separate `Int64` module;
for arbitrary-precision integers, there is the
[`Zarith`](https://github.com/ocaml/Zarith) library. For the first
half of this course we will not need either.

OCaml lets you write integer literals in four bases. The default is
decimal, but a `0x` prefix denotes hexadecimal, `0o` denotes octal,
and `0b` denotes binary. The compiler reads all four and produces
the same `int` value.

:::slide

## Integer literals

```ocaml
let dec = 255
let hex = 0xff
let oct = 0o377
let bin = 0b11111111
```

- All four bindings: type `int`, value `255`.
- Base prefix is **syntactic only**: same number under the hood.

:::

:::slide

## Underscores for readability

```ocaml
let million = 1_000_000
let mask    = 0xff_ff_ff_ff
```

- `_` is purely visual; the compiler ignores it.
- Use it wherever a long literal benefits from grouping.

:::

The underscore in `1_000_000` is a small but worthwhile convention:
it is purely visual, the compiler discards it entirely, and it
makes large numeric constants enormously easier to read. The same
convention exists in Java 7+, Python 3.6+, and Rust. You can place
the underscores wherever you like; `1_0_0_0_0_0_0` is also a million,
just an unkind one to your reader. The most common groupings are by
three digits for decimal numbers and by bytes for hex masks.

The four integer operators that come built in are `+`, `-`, `*`,
`/`, and `mod`. The first three behave exactly as you expect. The
last two, `/` and `mod`, have one subtlety worth understanding now,
because it differs from Python (the language students most often
arrive in OCaml from).

:::slide

## Integer arithmetic

```ocaml
let _ = 2 + 3
let _ = 10 - 4
let _ = 6 * 7
let _ = 17 / 5
let _ = 17 mod 5
```

- `+`, `-`, `*` behave as expected.
- `/` does **truncating integer division**: `17 / 5 = 3` (remainder dropped).
- `mod` gives the remainder: `17 mod 5 = 2`.

:::

:::slide

## Negative integer division: toward zero

```ocaml
let _ = (-17) / 5
```

- Result: `int = -3` (truncates toward zero, not toward minus infinity).
- Python's integer `//` rounds toward minus infinity: `(-17) // 5` gives `-4`.

:::

The `/` operator on `int` is *truncating integer division*: it
divides exactly and then throws the fractional part away. So
`17 / 5` is `3`, with the `0.4` discarded. The companion `mod`
operator returns what was discarded, scaled to an integer: `17 mod 5`
is `2`, because `17 = 3 * 5 + 2`. The identity `a = (a / b) * b + (a mod b)`
holds for any positive `a` and `b`.

For negative operands, OCaml truncates *toward zero*, not toward
minus infinity. So `(-17) / 5` is `-3` in OCaml. Python uses `/`
for floating-point division (`(-17) / 5` is `-3.4`) and `//` for
integer floor division; `(-17) // 5` rounds toward minus infinity
and gives `-4`. There is no universal right answer here; both
languages picked a convention and stuck with it. The OCaml
convention matches C and Java; the Python convention is mathematically
cleaner for some applications. The practical advice is: if you find
yourself doing arithmetic on signed integers near zero, write the
answer out for a couple of inputs and check that you have the
convention you wanted.

Integer overflow in OCaml is silent. `max_int + 1` does not raise
an exception or produce a runtime error; it wraps around, and the
language *defines* that wrap-around as the result. This is a
deliberate choice for performance. C is different in a way worth
flagging: signed-integer overflow in C is *undefined behaviour*,
so the compiler may assume it never happens (a distinction a later
module returns to). If you are doing arithmetic where overflow
might happen and would matter, the discipline is: use a wider
type (`Int64`) or check explicitly.

The stakes of "check explicitly" can be absolute. On 4 June
1996, the maiden Ariane 5 rocket tore itself apart 37 seconds
after launch, taking roughly 370 million dollars of vehicle and
satellites with it. The guidance software, reused from Ariane 4,
converted a 64-bit float (the horizontal velocity) into a 16-bit
integer; on Ariane 5's faster trajectory the value no longer
fit, and the range check had been *deliberately omitted* for
performance, because analysis of the old rocket had shown the
overflow could never happen. The conversion trapped, both
redundant guidance units ran the same code and failed the same
way, and the rocket veered and broke up. Numeric conversions are
where two representations meet; the
[inquiry report](https://en.wikipedia.org/wiki/Ariane_flight_V88)
is a classic precisely because every ingredient was reasonable
on its own.

## Floating-point numbers

OCaml's `float` is exactly IEEE 754 double precision: 64 bits, with
1 sign bit, 11 exponent bits, and 52 fraction bits. This is the same
representation that C calls `double`, that JavaScript uses for *all*
numbers, and that almost every modern language uses for its default
floating-point type. The range is roughly `±10^308`, with about 15
to 17 significant decimal digits of precision.

There is one small but very firm syntactic rule: a `float` literal
must contain a decimal point. Without it, the compiler reads the
number as an `int`. So `3.` and `3.0` and `3.14` are all floats;
`3` is an integer. The trailing dot after `3.` is enough, even
without a digit after it.

:::slide

## Float literals

```ocaml
let pi    = 3.14159
let half  = 0.5
let e_neg = 2.71828e-1   (* scientific: 2.71828 x 10^-1 *)
let tau   = 6.283185
```

- All `float`.
- `e-1` is the exponent suffix.

:::

:::slide

## No decimal point: it's an `int`

```ocaml
let bad = 3
```

- `bad : int`, not `float`.
- For a float, write `3.0` or `3.` (trailing zero optional after the dot).

:::

Scientific notation works as it does in every other language:
`2.71828e-1` is `2.71828 × 10^(-1)`, which is `0.271828`. You can
write the exponent with a sign (`e-1`, `e+5`) or without (`e10`).
The rule is that *either* a decimal point *or* an exponent suffix
is enough to mark a literal as `float`. So `1.0`, `1.0e10`, and
`1e10` are all floats; only `1` is an `int`. In practice, prefer
the decimal point: it makes the code easier to read.

Now to the design choice that catches every new OCaml programmer at
least once: the arithmetic operators on `float` are *different
symbols* from the ones on `int`. Floating-point addition is `+.`,
not `+`. Subtraction is `-.`. Multiplication is `*.`. Division is
`/.`. The trailing dot is part of the operator name, just like the
underscore in `let_binding` would be part of an identifier name.

:::slide

## Float arithmetic uses different operators

```ocaml
let _ = 1.0 +. 2.5
let _ = 10.0 -. 3.0
let _ = 4.0 *. 2.5
let _ = 9.0 /. 4.0
```

- Float operators: `+.`, `-.`, `*.`, `/.`.
- The trailing `.` is **part of the operator name**.

:::

:::slide

## No implicit `int` / `float` promotion

Mixing types is a compile-time error:

```ocaml skip
let _ = 1 + 2.0
```

- Error: `The constant 2.0 has type float but an expression was expected of type int`.
- To add an `int` and a `float`, convert explicitly:

```ocaml
let _ = float_of_int 1 +. 2.0
```

:::

This is the design choice that, in my experience, catches the
greatest number of students. After ten minutes of writing OCaml,
someone will try to write `let area r = 3.14 * r * r` and the
compiler will refuse: `The constant 3.14 has type float but an
expression was expected of type int`. The fix is to write
`3.14 *. r *. r` instead.

Why? Why not let `+` do the obvious thing depending on its
operands, the way Python and Java and JavaScript do? The answer
has two parts, one practical and one principled.

The practical part is that *operator overloading is expensive*.
In C++, when the compiler sees `a + b`, it has to
search for an `operator+` that takes the types of `a` and `b`. If
several such operators are in scope, it has to apply overload
resolution rules to pick one. This makes both compilation slower
and error messages worse: a misplaced `+` can produce error
messages that talk about candidate overloads in libraries the
programmer has never heard of. Languages with simpler type systems,
like C and Java, get around this by *baking the overloads into the
compiler*: the compiler knows that `+` on two `int`s is one
instruction, on two `double`s is a different one, and on a `String`
and anything is yet another. That is a workable design, but it
means you cannot decide for yourself, in your own code, what `+`
means on a new type you have written. OCaml takes the opposite
position: every operator has *one* meaning, fixed in the language,
and that meaning is determined by the operator symbol alone, not
by the types of its operands.

The principled part is *reasoning*. When you read OCaml code and
see `a + b`, you know, without checking anything else, that both
`a` and `b` are integers, and that the result is an integer add.
When you see `a +. b`, you know both are floats. That is one less
thing to verify in your head as you read code. We will come back
to this principle several times in the course: OCaml repeatedly
chooses *more syntax, less ambiguity*, and the dividend shows up
when you have to read someone else's code six months later.

The cost of this choice is that mixing numeric types requires an
explicit conversion. The function `float_of_int` turns an `int`
into a `float`; `int_of_float` does the reverse, truncating. The
opposite-direction conversion is so common in numerical code that
the standard library also exposes them as `Float.of_int` and
`Float.to_int`, with friendlier names.

One more property of `float` that is worth flagging now, because
students rediscover it the hard way: floating-point arithmetic is
*approximate*. The number `0.1` cannot be represented exactly in
binary floating point; neither can `0.2`. So `0.1 +. 0.2` does
not give `0.3`; it gives `0.300000000000000044`. This is not
a bug in OCaml; it is a fundamental property of IEEE 754, and
the same anomaly appears in Python, Java, JavaScript, and
essentially every mainstream language:
[`0.30000000000000004.com`](https://0.30000000000000004.com/)
tabulates `0.1 + 0.2` language by language.
We saw the same example in
[the Module 1 tutorial's float-precision aside](M01-L05-tutorial-recap.html#a-float-precision-aside).

That `0.1` has no exact binary representation sounds like trivia until it
accumulates. On 25 February 1991, during the Gulf War, a Patriot air-defence
battery in Dhahran failed to intercept an incoming Scud missile; 28 soldiers
died in the strike. The Patriot counted time as an integer number of
tenth-seconds, and predicting the Scud's next position meant converting that
count to seconds by multiplying by `1/10`, which has no finite binary expansion.
The 1970s-era computer held the result in a 24-bit fixed-point register, not a
float, so the truncation was coarse, and the error grew in proportion to how
long the system had run. After Alpha Battery's roughly 100 hours of continuous
operation the clock was off by 0.34 seconds, which at Scud speed left the
tracking gate about 687 metres from the missile. The [GAO report](https://www.gao.gov/products/imtec-92-26) blamed this imprecise
24-bit conversion. A modern 64-bit float would have held the same drift below a
microsecond, but the principle is the same: floating-point arithmetic is
approximate, and you have to be aware of that when you use it.

This approximateness has a concrete consequence that ties back to
the `+` versus `+.` distinction. Because `int` arithmetic is exact,
`+`, `-`, and `*` stay associative and distributive: you may reorder
and regroup an expression with no `.` operators without changing its
value, and even the silent wrap-around from earlier preserves these
laws, since wrap-around is exact modular arithmetic. The float
operators `+.` and `*.` give up both laws, because each result is
rounded and the rounding depends on the grouping:

```ocaml
(* Integers: regrouping is safe. *)
let _ = (1 + 2) + 3    (* = 6 *)
let _ = 1 + (2 + 3)    (* = 6 *)

(* Floats: each step rounds, so regrouping changes the answer. *)
let _ = (0.1 +. 0.2) +. 0.3         (* = 0.600000000000000089 *)
let _ = 0.1 +. (0.2 +. 0.3)         (* = 0.6 *)

(* Distributivity breaks the same way. *)
let _ = 100. *. (0.1 +. 0.2)        (* = 30.0000000000000036 *)
let _ = 100. *. 0.1 +. 100. *. 0.2  (* = 30. *)
```

## Booleans

The `bool` type has exactly two values: `true` and `false`. There
is no concept of "truthy" values like Python's `0` or `""`; an `if`
or `&&` or `||` expects a `bool`, full stop. A `0` is an `int`, not
a `bool`, and the compiler will reject `if 0 then ...` outright. As
with the numeric operators, this is OCaml again preferring more
syntax over more ambiguity: when you read `if e then ...`, you know
`e` evaluates to one of two values, not to an arbitrarily-typed
value with one of seven possible truthiness rules.

The boolean operators are `&&` for conjunction, `||` for disjunction,
and `not` for negation. The familiar comparison operators `=`, `<>`,
`<`, `<=`, `>`, `>=` all return `bool`.

:::slide

## Booleans

```ocaml
let _ = true && false
let _ = true || false
let _ = not true
let _ = 3 < 5 && 5 < 10
let _ = "apple" = "apple"
let _ = "apple" <> "banana"
```

- `&&` and `||` **short-circuit** (as in C and Java).
- `=` is equality, `<>` is inequality.

:::

Both `&&` and `||` *short-circuit*, exactly as in C and Java:
`&&` evaluates its right argument only if the left was `true`, and
`||` evaluates its right only if the left was `false`. This lets
you safely write things like `x <> 0 && y / x > 1`: the division
is only attempted when `x` is nonzero. We will lean on this
behaviour later when we want to guard expensive computations.

The comparison operators (`=`, `<>`, `<`, `<=`, `>`, `>=`) all
return `bool`. We will look at them properly in the
[operators lecture](M02-L04-operators.html#comparison-and-equality),
where the *structural* vs *physical* equality distinction also
gets its own treatment. For now: use `=` for equality, the way you
would use `==` in C.

## Strings

Strings in OCaml are sequences of bytes, written between double
quotes. They are *immutable*: once you have built a string, you
cannot modify a byte of it without explicitly converting through
the related type `bytes`. Most code never needs to do that, and so
treats strings as values, like integers: you build new ones from
old ones rather than mutating them in place.

A "byte string" is exactly that, a sequence of 8-bit bytes. OCaml's
`string` does not know about Unicode code points, or about encoding
in general. If your string contains the bytes that encode "café" in
UTF-8, then `String.length` reports 5 (the four ASCII letters plus
the two bytes that encode the accented "é"), not 4. For
Unicode-aware work the standard library is not enough; you reach
for an external library like `uutf` or `uucp`. Most code that just
concatenates, slices, or searches byte content does not need any of
that, and is perfectly happy with the byte view.

:::slide

## String literals

```ocaml
let hello = "hello"
let empty = ""
let multi = "first line\nsecond line"
let quote = "she said \"hi\""
let path  = "C:\\Users\\kc"
```

- Escape sequences (same as C): `\n` newline, `\t` tab,
  `\\` backslash, `\"` quote, `\NNN` decimal byte, `\xHH` hex byte.

:::

:::slide

## String concatenation: `^`

```ocaml
let s = "first" ^ " " ^ "second"
```

- `^` is the concatenation operator (not `+`).
- Separate from `+` because strings and numbers are different
  operations; each operator has one fixed meaning.

:::

The escape sequences inside string literals are the same family
you have seen in C: `\n` for newline, `\t` for tab, `\\` for a
literal backslash, `\"` for a literal double quote. There are also
two ways to write an arbitrary byte: `\NNN`, where `NNN` is a
three-digit decimal number, or `\xHH`, where `HH` is two hex digits.
You will not need these often, but they are how you embed raw bytes
in a literal.

String concatenation uses the operator `^`, not `+`. The reason is
the same reason `+` does not work between `int` and `float`: in
OCaml, an operator has one meaning, fixed by the symbol. Numeric
addition is one operation; string concatenation is a different one;
they get different symbols. So `"foo" ^ "bar"` is `"foobar"`. If
you want to build up a string from many pieces, the standard library
has `String.concat`, which takes a separator and a list of pieces
and is much faster for many small parts.

:::slide

## String length and substrings

```ocaml
let _ = String.length "OCaml"
```

- Result: `int = 5`.
- `String` is the stdlib module for string functions.

:::fragment

```ocaml
let _ = String.sub "Functional programming" 0 10
```

- Result: `string = "Functional"`.
- `String.sub s start len` returns the substring of `s` of length
  `len` starting at position `start`.
- Indexing is **zero-based**.
- Out-of-bounds (`start + len > String.length s`) raises
  `Invalid_argument`.

:::

:::

`String.length` takes a string and returns the number of bytes in
it. `String.sub` takes a string, a starting index, and a length,
and returns the substring at that range. Indexing is zero-based,
as in essentially every modern language. The standard library has
many other string functions (`String.concat`, `String.trim`,
`String.split_on_char`, `String.uppercase_ascii`, `String.get` for
single-character access, ...); we will meet them as needed in
later modules.

Out-of-bounds access raises an exception, `Invalid_argument`. We
will see how to [handle exceptions](M07-L03-exceptions.html)
properly in Module 7; for now, just know that `String.sub s i n`
with `i + n` outside `0 .. length s` is a runtime error.

## Conversions between types

OCaml will not auto-convert between numeric types, between `bool`
and `int`, or between `char` and `string`. The standard library
provides explicit conversion functions wherever they make sense:

```ocaml
let _ = string_of_int 42      (* = "42" *)
let _ = float_of_int 7        (* = 7. *)
let _ = int_of_float 3.7      (* = 3, truncates toward zero *)
let _ = int_of_string "123"   (* = 123 *)
let _ = string_of_bool true   (* = "true" *)
```

These names follow a predictable pattern: `xxx_of_yyy` returns an
`xxx` given a `yyy`. The functions that parse from a string
(`int_of_string`, `float_of_string`, `bool_of_string`) raise an
exception if the string does not represent a value of that type.
`bool_of_string` is the strictest of the three: it accepts exactly
`"true"` and `"false"`, nothing else.

## Putting it together

Here is a function that uses three of the four primitive types we
have seen:

:::slide

## A larger expression

```ocaml
let password_strength len =
  if len < 8 then "weak"
  else if len < 12 then "ok"
  else if len < 16 then "good"
  else "strong"

let _ = password_strength 14  (* = "good" *)
```

- Function of type `int -> string`.
- Body is **one expression**: a chain of `if`/`then`/`else`.
- Full `if` lecture in Lecture 5.
- Literals (`8`, `12`, `"weak"`) combine into a working function.

:::

Notice three things. First, the function takes an `int` (the
password length) and returns a `string` (the label). The compiler
figured this out automatically from the function body, because
the comparisons are against `int` literals and the `then` and
`else` branches return `string` literals. We did not have to write
a single type annotation. Second, the body is a chain of nested
`if`-`then`-`else` expressions, and the whole chain is *one
expression*. This is the same point we made earlier about OCaml
being expression-based: even something that looks like a multi-way
branch is a value-producing expression you can pass to a function
or bind to a name. We give `if` its
[own dedicated lecture](M02-L05-if-expressions.html) later in
this module. Third, every
comparison is against the same type: `len < 8`, where `len` is
`int` and `8` is `int`, never mixing `int` and `float`.

A C programmer reading this might object that the `if`s could be
rewritten as a `switch`. In OCaml, the equivalent of `switch` is
[`match`](M05-L01-basic-patterns.html), which we will see in
Module 5 (it is the central tool of the language). But `match` is
overkill for a chain of *threshold comparisons* like this one; the
right tool here is a nested `if`, the same as in any other
language.

## Common pitfalls

A short collection of mistakes I see beginners make on every cohort
of this course. None are deep, but each costs about half an hour to
recover from if you make it for the first time mid-assignment.

**Pitfall 1: mixing `int` and `float`.** The error message
`The constant 2.0 has type float but an expression was expected of type int`
(or its mirror, when the offending literal is an `int`) is the most
common compile error in week 1. Look
at the surrounding code and figure out which side is supposed to
be a `float`. Insert a `float_of_int` (or `int_of_float`) as needed.
Resist the urge to "fix" this by sprinkling dots randomly; understand
which side wanted which type.

**Pitfall 2: using `==` for equality.** It looks like the Java
operator; it is not. Use `=`. The compiler will not warn you;
`==` is a valid operator with a perfectly valid (just unhelpful)
meaning, so your code compiles and runs and produces wrong answers.
This is a habit you have to drill out from day one.

**Pitfall 3: forgetting the decimal point.** `let pi = 3` does
not produce a `float`; it produces an `int` named `pi` with value
3. Then later, when you write `2.0 *. pi`, the compiler complains
about a type mismatch and you wonder why. Always write floating
constants with at least a trailing `.`: `let pi = 3.14`,
not `let pi = 3`. (Better still: use `Float.pi` from the standard
library.)

**Pitfall 4: assuming string-on-string `=` is expensive.** It is
linear in the length of the shorter string, the same as `strcmp`
in C, and the compiler is good about not doing redundant work.
You do not need to micro-optimise by comparing string lengths
first.

## A quick check

:::quiz mcq id=M02-L01-q2
What does this evaluate to?

```ocaml skip
let _ = 1 + 2.0
```

- [ ] `float = 3.0` (with an implicit cast)
- [ ] `int = 3` (the `2.0` is truncated)
- [x] Type error: `+` expects `int` on both sides; `2.0` is a `float`.
- [ ] Type error: `1` should have been `1.0`.

**Why:** OCaml never inserts implicit conversions between `int`
and `float`. The operator `+` takes two `int`s and returns an
`int`; the second operand `2.0` is a `float`, so the compiler
rejects the expression with "the constant 2.0 has type float but
an expression was expected of type int." Both the int-side and
the float-side framings are wrong: there is no preferred side, the
language simply refuses the call and asks you to insert a
`float_of_int` (or `int_of_float`) where you intended.
:::

:::quiz mcq id=M02-L01-q3
What does this evaluate to?

```ocaml skip
let _ = (-7) / 2
```

- [ ] `int = -4` (floor division)
- [x] `int = -3` (truncation toward zero)
- [ ] `float = -3.5`
- [ ] `exception Division_by_zero`

**Why:** OCaml's integer division `/` *truncates toward zero*,
not toward negative infinity. `(-7) / 2 = -3` (and `(-7) mod 2 =
-1`). Python 3 and many other languages floor instead, giving
`-4`; the convention is flipped relative to those languages. The
result is an `int` because both operands are `int` and OCaml does
not implicitly promote to `float`.
:::

(No code quiz here: function definitions arrive in
[Module 3](M03-L01-functions-as-values.html). The Activity
below stays at the "predict the type and value" level.)

## Activity

:::slide

## Activity

What is the type and value of:

- `3 / 2`
- `3.0 /. 2.0`

Predict before running.

:::

:::slide

## Activity discussion

What is the type and value of:

- `3 / 2`
  - `3 / 2` : `int = 1`. Integer division **truncates**.
- `3.0 /. 2.0`
  - `3.0 /. 2.0` : `float = 1.5`. Float division as expected.
- **Python 3 contrast**: there `/` is true division, `//` is floor.
- OCaml is the reverse: `/` on `int` truncates, **no implicit cast**.

:::

The activity is a single question with two parts. Before reading
on, try it: predict the type and value of `3 / 2` and `3.0 /. 2.0`.

The first, `3 / 2`, has type `int` and value `1`. Both operands
are `int`, so `/` is integer division. Integer division truncates,
so the answer is `1`, not `1.5`. Python 3 contrasts: there `/`
performs *true* division and would produce `1.5`, even on integer
operands; you would have to write `3 // 2` to get the truncated
answer. So if you arrive in OCaml from Python 3, the convention is
flipped relative to what you are used to. In Python *2*, by the
way, the convention is the same as OCaml's.

The second, `3.0 /. 2.0`, has type `float` and value `1.5`. Both
operands are `float`, the operator is the float-division operator,
and the answer is what you expect.

If you tried to write `3 /. 2`, OCaml would refuse: the operator
`/.` expects `float` on both sides. If you tried `3.0 / 2.0`, OCaml
would also refuse: the operator `/` expects `int`. There is no
operator that takes mixed types in OCaml.

## What's next

:::slide

## What's next

- Next: **`let` bindings**.
- Naming values, nested bindings, shadowing.
- The piece that makes a program more than a one-liner.

:::

Once you have literals, the immediate next question is: how do I
give them names? Repeatedly writing `3.14159` in code is not a
sustainable plan. The [next lecture](M02-L02-let-bindings.html)
covers `let` bindings, which let you name a value and reuse it.
They will also let us write local definitions inside an expression,
the first step toward structuring real programs.

## Reading

- **Real World OCaml**, *A Guided Tour* (numbers section):
  <https://dev.realworldocaml.org/guided-tour.html>
- **Cornell CS3110**, *Basic types and values*:
  <https://cs3110.github.io/textbook/chapters/basics/expressions.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
