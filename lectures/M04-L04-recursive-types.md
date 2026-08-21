---
title: "Recursive types: lists, trees, expressions"
lecture_no: 4
week: 4
duration_target_min: 25
concepts: [recursive types, list, tree, ADT, expression trees, structural induction]
keywords: [OCaml, recursive types, list, tree, ADT, expression]
activity_question: "Extend the [expr] type with a [Sub] constructor (two sub-expressions, like [Add] and [Mul]) and construct a value representing [(7 - 3) - 2]."
think_about_this: "Structural equality [=] compares [int list] values and [int tree] values alike, with no comparison code written by you for either type. What about the way variants are built lets one polymorphic operator walk both structures?"
reading:
  - title: "Cornell CS3110, Lists"
    url: https://cs3110.github.io/textbook/chapters/data/lists.html
  - title: "Cornell CS3110, Trees"
    url: https://cs3110.github.io/textbook/chapters/data/trees.html
---

# Recursive types


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Recursive types: lists, trees, expressions</h2>
<p class="title-slide-label">Module 4 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

A variant becomes much more interesting when one of its constructors
carries a value of *the same type* being defined. That single
self-reference is what makes it possible to describe data of
*unbounded size* with a *fixed* type declaration: lists of any
length, trees of any depth, arithmetic expressions of any
complexity. This lecture covers the canonical recursive shapes,
how OCaml encodes them, and how to walk them with recursive
functions.

We have already met recursion at the *function* level
([the recursion lecture](M03-L02-recursion.html)). This lecture
connects it
with recursion at the *type* level. The two go together: a
recursive type asks for a recursive function to process it, and
the structural shape of the recursion mirrors the shape of the
type. Once you see the connection, writing functions on recursive
data becomes almost mechanical.

[Module 5](M05-L01-basic-patterns.html) will lean heavily on
this: pattern matching on recursive variants is the everyday tool
for processing structured data.
[Module 6](M06-L02-map.html) generalises with higher-order
combinators like `map` and [`fold`](M06-L04-fold.html). The
foundation, the *types themselves*, is what we introduce now.

:::slide

## This lecture: recursive types

- A variant constructor can carry a value of *the same type*.
- That self-reference describes data of *unbounded size* with a
  *fixed* type declaration: lists, trees, expressions.
- Connects recursion at the function level (M03) with recursion
  at the type level.
- A recursive type calls for a recursive function with the same
  shape: the code mirrors the data.
- Foundation for pattern matching (M05) and `map` / `fold` (M06).

:::

## A first recursive variant: a list of integers

Start with a list of *integers*. Conceptually, a list is either
empty, or has a head element and a *smaller list* of the same
kind. As a variant:

```ocaml
type intlist =
  | INil
  | ICons of int * intlist
```

`INil` is the empty list. `ICons` carries an `int` (the head) and
another `intlist` (the tail). The interesting bit is that the type
`intlist` appears *inside its own definition*; that is the
"recursive variant" property, and it is what lets one type
declaration describe lists of any length:

```ocaml
let ints = ICons (1, ICons (2, ICons (3, INil)))
```

The names `Nil` and `Cons` (with various prefixes / spellings)
come from Lisp, which used them in the 1950s for exactly this
shape.

:::slide

## A first recursive variant: a list of integers

```ocaml
type intlist =
  | INil
  | ICons of int * intlist

let ints = ICons (1, ICons (2, ICons (3, INil)))
```

- `INil`: empty list.
- `ICons`: head `int` plus a *tail* `intlist`.
- `intlist` appears inside its own definition: **recursive
  variant**.
- One declaration; any length of integer list.

:::

## A list of strings

Suppose we now want a list of *strings*. The shape is the same;
only the element type changes:

```ocaml
type stringlist =
  | SNil
  | SCons of string * stringlist

let strs = SCons ("hello", SCons ("world", SNil))
```

The duplication is starting to feel mechanical. If we also want
`pointlist`, `shapelist`, `userlist`, every type would have its
own copy of the same two-case shape. OCaml has a way to write the
shape *once*, with the element type as a parameter.

:::slide

## A list of strings

```ocaml
type stringlist =
  | SNil
  | SCons of string * stringlist

let strs = SCons ("hello", SCons ("world", SNil))
```

- Same shape as `intlist`; only the element type changed.
- Imagine writing `pointlist`, `shapelist`, `userlist`, ...
- We want **one declaration**, parameterised by the element type.

:::

## Parameterised variants

The trick is to leave the element type as a parameter on the left
of the `=`, using OCaml's *type-variable* syntax: a single quote
followed by an identifier.

```ocaml
type 'a lst =
  | Nil
  | Cons of 'a * 'a lst

let ints = Cons (1, Cons (2, Cons (3, Nil)))
let strs = Cons ("hello", Cons ("world", Nil))
```

One declaration. The same `Nil` and `Cons` work for integers,
strings, points, shapes, whatever. The compiler infers the type
of each value:

- `ints : int lst`
- `strs : string lst`

The element type is fixed *per value*, not per declaration. There
is no way to mix integers and strings inside the same list:
`Cons (1, Cons ("oops", Nil))` would be a type error. Each `'a`
inside a single value is the *same* type.

:::slide

## Parameterised variants

```ocaml
type 'a lst =
  | Nil
  | Cons of 'a * 'a lst

let ints = Cons (1, Cons (2, Nil))
let strs = Cons ("hello", Cons ("world", Nil))
```

- One declaration; any element type.
- `ints : int lst`, `strs : string lst`.
- Inside a single value, every `'a` is the **same** type.

:::

## `'a` is a type variable

The `'a` in `'a lst` is OCaml's syntax for a *type variable*. The
naming convention:

- A regular **variable** is a name standing for an unknown
  *value*. (We have been writing `x`, `n`, `s` for these.)
- A **type variable** is a name standing for an unknown *type*.

OCaml writes type variables with a single quote followed by an
identifier: `'a`, `'b`, `'key`, `'value`. The convention is to
use `'a` and `'b` most of the time, pronounced "alpha" and "beta"
(or just "quote a" and "quote b"). Other languages have the same
idea under different syntax:

- Java: `List<T>`.
- C++: `std::vector<T>`.
- Rust: `Vec<T>`.

OCaml's `'a` is to types what `let x = ...` is to values: a name
standing in for "any one"; the actual choice is made at each use
site.

:::slide

## `'a` is a type variable

- **Variable**: name standing for an unknown value (`x`, `n`).
- **Type variable**: name standing for an unknown type (`'a`,
  `'b`).
- OCaml syntax: single quote, then identifier.
  Pronounced "alpha", "beta", or "quote a", "quote b".
- Same idea: Java `List<T>`, C++ `std::vector<T>`, Rust `Vec<T>`.

:::

## Polymorphism

A definition that contains type variables is *polymorphic*. The
word decomposes: *poly* = many, *morph* = shape. A polymorphic
definition has many shapes; a single declaration covers them all.

- `'a lst` is a polymorphic data type. One declaration, many
  instantiations: `int lst`, `string lst`, `shape lst`, ...
- In `'a lst`, the `lst` part is called a *type constructor*: it
  takes a type (like `int`) and constructs a type (`int lst`).
- This is the same idea as Java generics and C++ template
  instantiation, where one definition is reused at many element
  types.

We will see polymorphic *functions* throughout the rest of the
course. The simplest example is the identity function:

```ocaml
let id x = x
```

The toplevel reports `val id : 'a -> 'a`. One definition; works
at every choice of `'a`.

:::slide

## Polymorphism

- A definition with type variables is **polymorphic**.
  - *poly* = many, *morph* = shape.
- `'a lst` is a polymorphic data type:
  `int lst`, `string lst`, `shape lst`, ...
- `lst` is a **type constructor**: takes a type, gives a type.
- Same idea as Java generics, C++ templates, Rust generics.

:::

:::slide

## A polymorphic function: `id`

```ocaml
let id x = x
```

- Toplevel: `val id : 'a -> 'a`.
- One definition; works at every choice of `'a`.
- Same shape as `'a lst`: type variable in the signature, many
  instantiations from one declaration.

:::

## OCaml's built-in lists are just variants

The standard library defines `list` as a parameterised recursive
variant of exactly the shape we just built:

```text
type 'a list =
  | []
  | (::) of 'a * 'a list
```

`[]` and `::` are constructors, just like our `Nil` and `Cons`.
In fact `[]` is informally called *nil* and `::` is informally
called *cons* (the names come from Lisp), and you will see
`Nil` and `Cons` used as constructor names in OCaml code that
defines its own list-like type. The standard library just uses
`[]` and `::` because of a small amount of *syntactic sugar*:

- The constructors are written as `[]` and `::` instead of
  alphabetic identifiers. (Most variant constructors must start
  with a capital letter; `[]` and `::` are special-cased.)
- `::` is an infix operator: `1 :: rest` rather than `:: (1, rest)`.
- The bracket literal `[1; 2; 3]` desugars to
  `1 :: 2 :: 3 :: []`.

Strip the sugar and `list` is a normal parameterised variant.

:::slide

## OCaml's built-in lists are just variants

```text
type 'a list =
  | []
  | (::) of 'a * 'a list
```

- `[]` and `::` are constructors.
- Informally called *nil* and *cons* (from Lisp); you will see
  `Nil` and `Cons` used as constructor names in OCaml code.
- `::` is infix; `[1; 2; 3]` desugars to `1 :: 2 :: 3 :: []`.
- Strip the sugar and it is a normal parameterised variant.

:::

A value of type `'a list` is one of two shapes:

- `[]`: the empty list.
- `x :: rest`: an element `x` (of type `'a`) prepended to another
  `'a list` named `rest`.

The recursion is in the second constructor: the cons cell carries
a tail, which is itself a list, which can itself be empty or
another cons cell, and so on. The single self-reference is how
lists of arbitrary length fit in a type declaration of two cases.

## Null: the billion-dollar mistake

Most mainstream languages have a special value, `null` in
Java/Go/C, `None` in Python (a single global value, not a
variant constructor), `nil` in Ruby, `undefined` in JavaScript,
that means "no value here." This works, but it has a quiet
structural problem: the *type* of a reference does not tell you
whether `null` is a legitimate inhabitant. In Java:

```text
String name = lookup("alice");
System.out.println(name.length());
```

Compiles fine. Runs fine if `lookup` returns a real string.
Crashes with a `NullPointerException` if `lookup` returned
`null` and the programmer forgot to check. The type system
offered no help.

[Tony Hoare](https://en.wikipedia.org/wiki/Tony_Hoare), who
introduced null references in 1965 in his ALGOL W design,
later called this his *billion-dollar mistake*:

> I call it my billion-dollar mistake. It was the invention of
> the null reference in 1965. At that time, I was designing the
> first comprehensive type system for references in an
> object-oriented language. My goal was to ensure that all use
> of references should be absolutely safe, with checking
> performed automatically by the compiler. But I couldn't
> resist the temptation to put in a null reference, simply
> because it was so easy to implement. This has led to
> innumerable errors, vulnerabilities, and system crashes,
> which have probably caused a billion dollars of pain and
> damage in the last forty years.
>
> Sir Tony Hoare,
> *[Null References: The Billion Dollar Mistake](https://www.infoq.com/presentations/Null-References-The-Billion-Dollar-Mistake-Tony-Hoare/)*
> (QCon 2009)

The problem is not that "no value" needs a representation; that
is a real and common situation. The problem is that the
representation should be *visible in the type*, so the compiler
can force the caller to handle it.

:::slide

## Null: the billion-dollar mistake

```text
String name = lookup("alice");
System.out.println(name.length());
```

- Compiles. Crashes at runtime if `lookup` returned `null`.
- Every reference might secretly be null; every reader has to
  remember to check.

> I call it my billion-dollar mistake. ... innumerable errors,
> vulnerabilities, and system crashes ... probably caused a
> billion dollars of pain and damage in the last forty years.
>
> Sir Tony Hoare, who introduced `null` in 1965.

- OCaml's fix: no implicit null. "No value" is its **own type**.

:::

## The `option` type

OCaml's answer to "maybe a value, maybe not" is a built-in
parameterised variant:

```ocaml
type 'a option =
  | None
  | Some of 'a
```

Two constructors:

- `None`: there is no value here.
- `Some x`: there is a value, and that value is `x` (of type
  `'a`).

The mental model is a *box*. An `'a option` is a box that either
*contains* one value of type `'a` (the `Some x` case), or is
*empty* (the `None` case). To use the value, you have to open
the box and check which case you have. The type system makes
that check mandatory; the compiler refuses to let you treat the
box's contents as a plain `'a` without first inspecting which
case the box is in.

Constructing values is exactly what you would guess:

```ocaml
let x = None
let y = Some 10
let z = Some "hello"
```

The toplevel reports the types: `x : 'a option` (a `None` could
be a box of *any* element type; the type stays polymorphic until
context fixes it), `y : int option`, `z : string option`. As with
`'a list`, the parameter is fixed *per value*, not per type
declaration.

A function whose return type involves `option` is *honest* about
maybe-failing. Compare two signatures:

```text
val lookup : string -> string         (* never fails, always returns a string *)
val lookup : string -> string option  (* might return None *)
```

The second signature tells the caller, in the type, that the
result might be absent, and the caller cannot get at the inner
string without first handling the `None` case. The `null`-style
signature on the first line is silent about that possibility,
and the failure surfaces as a runtime crash instead of a
compile-time obligation.

:::slide

## The `option` type

```ocaml
type 'a option =
  | None
  | Some of 'a
```

- A built-in **parameterised variant**.
- Mental model: a **box** that is either *empty* (`None`) or
  *contains a value* (`Some x`).

```ocaml
let x = None
let y = Some 10
let z = Some "hello"
```

- Types: `int option`, `string option`, ...

:::

:::slide

## `option` in function signatures

Compare:

```text
val lookup : string -> string         (* never fails *)
val lookup : string -> string option  (* might return None *)
```

- The second signature **tells the caller** the result may be
  absent.
- Caller cannot get at the inner string without first handling
  `None`.
- The type forces the check; the compiler enforces it.

:::

## When to use `option`

Anywhere a domain has a "may be absent" state that is *part of
the model*, not an exceptional failure. The classic example is a
record field that is sometimes meaningful and sometimes not. A
student's exam mark:

```ocaml
type student = {
  name : string;
  roll_no : string;
  marks : int;
}
```

What `marks` value do you put when the student has not yet
written the exam? `0` is wrong: a student who took the exam and
scored zero is also stored as `0`, and there is no way for code
later to tell the two cases apart. `-1` is a sentinel; sentinels
collide with real values eventually. The honest answer is "no
value yet," and the type that says so is `int option`:

```ocaml
type student = {
  name : string;
  roll_no : string;
  marks : int option;
}

let alice = { name = "Alice"; roll_no = "CS24"; marks = Some 87 }
let bob   = { name = "Bob";   roll_no = "CS25"; marks = None }
```

`alice`'s exam mark is `Some 87`; `bob` has not taken the exam.
The type tells later code to handle both cases. There is no
sentinel value that means anything other than what its
constructor says.

This is the slogan you will hear in functional-programming
circles: *make illegal states unrepresentable*. With `marks :
int`, every `int` is a legal field value, so "took the exam"
versus "not yet taken" has to live in a sentinel that the type
system cannot see. With `marks : int option`, there are exactly
two ways to construct the field (`Some n` and `None`), and they
correspond to exactly the two states the domain has. The illegal
configurations (a sentinel `-1`, a magic `0`) are no longer
expressible. We will lean on this principle again in
[Module 7](M07-L07-signatures.html#why-hide-internals) when we
discuss API design.

A rule of thumb for when `option` is the right model: reach for
it when the *consumer* of the data faces genuine uncertainty
about whether a value is there (a mark not yet entered, a field
the source did not supply), not as a stand-in for a legitimate
domain value. If "absent" is itself a meaningful value of the
domain (a score of zero, an empty string the user actually
typed), give it an honest representation of its own; `None`
should mean "nothing here," never "a particular something."

:::slide

## When to use `option`: the problem

```ocaml
type student = {
  name : string;
  roll_no : string;
  marks : int;
}
```

- What goes in `marks` when the student has not taken the exam?
- `0`: collides with "scored zero."
- `-1`: a brittle sentinel; out-of-range values are accidents
  waiting to happen.

:::

:::slide

## When to use `option`: the fix

```ocaml
type student = {
  name : string;
  roll_no : string;
  marks : int option;
}

let alice = { name = "Alice"; roll_no = "CS24"; marks = Some 87 }
let bob   = { name = "Bob";   roll_no = "CS25"; marks = None }
```

- `Some 87`: took the exam, scored 87.
- `None`: not taken yet.
- The type forces every reader to handle both cases.
- The slogan: *make illegal states unrepresentable*. No
  sentinel `-1`, no magic `0`.
- Rule of thumb: `option` models *consumer uncertainty*
  ("may not be there"), never a legitimate domain value.

:::

## The `result` type

Sometimes `None` is not informative enough; the caller wants to
know *why* a function failed. The standard library provides a
two-parameter variant for that:

```ocaml
type ('a, 'e) result =
  | Ok of 'a
  | Error of 'e
```

A `result` value is either `Ok v` (success, carrying a value of
type `'a`) or `Error e` (failure, carrying a value of type `'e`).
The error payload is typically a string with a human-readable
message, but it can be any type: a structured error variant, an
exception, a status code.

```ocaml
let r1 : (int, string) result = Ok 42
let r2 : (int, string) result = Error "not an int"
```

The choice between `option` and `result` is about what the
caller needs. If the only sensible response to failure is "use a
default" or "give up," `option` is enough. If the caller might
distinguish among kinds of failure ("user gave bad input" vs.
"the disk is full" vs. "network timed out"), `result` lets you
carry that information through. The `result` type also threads
nicely through chained computations; we will see that with the
`let*` sugar in [the result-monad lecture](M08-L02-laws-list-result.html).

How to *use* an `option` or `result` (the `match` on `None` vs.
`Some`, or `Ok` vs. `Error`) is the subject of
[Module 5](M05-L01-basic-patterns.html). For now: know they
exist, know they replace `null` and ad-hoc error codes,
construct values of them, and read the types of functions that
return them.

:::slide

## The `result` type

```ocaml
type ('a, 'e) result =
  | Ok of 'a
  | Error of 'e
```

- Like `option`, but the failure case **carries a value**.
- Two type parameters: `'a` for the success, `'e` for the error.

```ocaml
let r1 : (int, string) result = Ok 42
let r2 : (int, string) result = Error "not an int"
```

- Use `option` when "absent" is enough.
- Use `result` when the caller wants to know **why**.

:::

## Lists in practice

Because cons prepends an element to an existing list, building a
new list by adding a head is cheap:

```ocaml
let xs = [10; 20; 30]
let ys = 0 :: xs
let _ = ys  (* = [0; 10; 20; 30] *)
```

`ys` is `[0; 10; 20; 30]`. The new value *shares* its tail with
`xs`: no copying happens. Lists are immutable, so this sharing is
safe. Now rebind `xs` to something completely different:

```ocaml
let xs = [99; 99; 99]
let _ = ys  (* = [0; 10; 20; 30], unchanged *)
```

`ys` is still `[0; 10; 20; 30]`. The earlier `let ys = 0 :: xs`
captured the *value* `xs` was bound to at that moment (the list
`[10; 20; 30]`), not the *name* `xs`. Rebinding `xs` later does
not change what `ys` points at. This is the same shadowing-is-not-mutation
point from
[the let-bindings lecture](M02-L02-let-bindings.html#why-shadowing-differs-from-mutation-closures-see-the-old-value),
applied to lists.

:::slide

## Lists in practice: cons is cheap

```ocaml
let xs = [10; 20; 30]
let ys = 0 :: xs
let _ = ys  (* = [0; 10; 20; 30] *)
```

- `ys` shares its tail with `xs` (no copy).
- Prepending is `O(1)`; appending to the end is `O(n)`.

:::

:::slide

## Lists in practice: `ys` captures the value

Now rebind `xs`:

```ocaml
let xs = [99; 99; 99]
let _ = ys  (* = [0; 10; 20; 30], unchanged *)
```

- `ys` captured the **value** at binding time, not the name `xs`.
- Same shadowing-is-not-mutation point from the let-bindings
  lecture.

:::

The "sharing tails" property is important. Prepending is `O(1)`:
allocate one cons cell, point its tail at the existing list, done.
Appending to the *end* is `O(n)` because you have to walk to the
end first to find the empty list that needs replacing. This is why
OCaml programmers think of lists *head-first*: you grow them by
prepending, you walk them by stripping off the head.

If you find yourself constantly appending to the end of a list,
you probably want a different data structure (an array, a Queue,
or a reversed list that you reverse once at the end).

## A binary tree

The next-simplest recursive variant is a binary tree:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
```

Two constructors: `Leaf` (the empty tree) and `Node` (a left
subtree, a value, and a right subtree). The recursive references
appear *twice* in `Node`, which is why trees can branch.

A concrete tree:

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree

let example =
  Node (
    Node (Leaf, 1, Leaf),
    2,
    Node (Leaf, 3, Node (Leaf, 4, Leaf)))
```

Drawing this tree:

```
        2
       / \
      1   3
           \
            4
```

The four `Leaf` constructors are the empty-subtree placeholders at
the bottom. They make the tree's shape explicit: every node has
exactly two children, even if one (or both) of them is empty.

:::slide

## A binary tree: the type

```ocaml
type 'a tree =
  | Leaf
  | Node of 'a tree * 'a * 'a tree
```

- `Leaf`: empty. `Node`: left, value, right.
- Like a list, but **two** recursive references inside `Node`.
- `'a tree` works for any element type, just like `'a list`.

:::

:::slide

## A binary tree: an example

```ocaml
type 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
let example =
  Node (
    Node (Leaf, 1, Leaf),
    2,
    Node (Leaf, 3, Node (Leaf, 4, Leaf)))
```

```text
    2
   / \
  1   3
       \
        4
```

:::

A list is, in a sense, a *unary* tree: each cons cell has a value
and *one* successor (the tail). A binary tree has each node with
*two* successors. You can generalise further: ternary trees, $n$-ary
trees, even trees with an unbounded number of children (called
*rose trees*, which we will see in a moment).

## Mutual recursion at the type level

Two types can be mutually recursive (each referring to the other).
The keyword is `and`, just like for
[mutual recursion of functions](M03-L05-local-and-mutual.html#mutual-recursion-two-functions-calling-each-other).
A small example: a "rose tree" or "n-ary tree," where each node
has a value and an arbitrary number of children:

```ocaml
type 'a forest = 'a rose_tree list
and  'a rose_tree = Rose of 'a * 'a forest
```

A rose tree carries a value and a *forest* of children; a forest
is a list of rose trees. Each definition refers to the other; the
`and` ties them together into one declaration.

:::slide

## Mutual recursion at the type level

Two types can refer to each other:

```ocaml
type 'a forest = 'a rose_tree list
and  'a rose_tree = Rose of 'a * 'a forest
```

- `rose_tree`: value and a *forest* of children.
- `forest`: list of rose trees.
- `and` ties them together.
- Models a node-labelled tree with **any number** of children.

:::

The same `and` keyword serves two purposes in OCaml: mutual
recursion of `let` bindings and mutual recursion of `type`
declarations. The intuition is the same in both cases: the names
introduced together are all in scope for each other.

## Modelling arithmetic expressions

A recursive variant can model entire mini-languages. The classic
example is arithmetic expressions: a *number*, or an *addition*
of two sub-expressions, or a *multiplication* of two
sub-expressions:

```ocaml
type expr =
  | Num of int
  | Add of expr * expr
  | Mul of expr * expr

let e = Add (Num 3, Mul (Num 4, Num 5))
```

The value `e` represents the arithmetic expression `3 + (4 *
5)`. The `Add` and `Mul` constructors are recursive: their
payloads are themselves `expr` values, which can be any shape
allowed by the type. With three constructors we can describe
expressions of any depth.

This same recipe (variants for the kinds of node, recursion for
the nesting) is how interpreters, parsers, type checkers, JSON
representations, regex ASTs, configuration languages, and network
protocol decoders are all modelled in OCaml. Once we have pattern
matching, evaluating one of these shapes is straightforward
(`Module 5` has the tools; the
[Module 5 tutorial](M05-L06-tutorial.html) walks an `expr`
evaluator end-to-end).

:::slide

## Modelling arithmetic expressions

```ocaml
type expr =
  | Num of int
  | Add of expr * expr
  | Mul of expr * expr

let e = Add (Num 3, Mul (Num 4, Num 5))
```

- `e` represents `3 + (4 * 5)`.
- `Add` and `Mul` are recursive: payloads are themselves `expr`.
- Same recipe: JSON, regex, configs, network protocols.
- Walking and evaluating: M05 pattern matching.

:::

## Where this is going

We now have variants for *kinds*, recursion for *nesting*, and
type variables for *polymorphism*. The missing piece is how to
*walk* one of these structures: take an `'a list`, an `'a tree`,
or an `expr` apart and compute something with it. That step is
*pattern matching*, and it gets a whole module of its own:

- [Module 5](M05-L01-basic-patterns.html) introduces pattern
  matching properly: literals, variables, wildcards, nested
  patterns, guards, and exhaustiveness.
- Once we have it, structural recursion (function shape mirrors
  type shape, base case for terminal constructors, recursive
  case for recursive ones) becomes the natural way to write
  every function on a recursive variant.
- [Module 6](M06-L02-map.html) generalises that pattern with
  higher-order combinators (`map`, `filter`, `fold`).

For Module 4, we are done with the *shapes*. Module 5 picks up
the *walks*.

## A short check

:::quiz mcq id=M04-L04-q2
Given:

```ocaml
type expr =
  | Num of int
  | Add of expr * expr
  | Mul of expr * expr
```

Which of these are **valid** values of type `expr`?

- [x] `Num 0`
- [x] `Add (Num 1, Num 2)`
- [x] `Mul (Add (Num 1, Num 2), Num 3)`
- [ ] `Add (Num 1, Mul (Num 2, Num 3), Num 4)`

**Why:** `Num` takes an `int` payload; `Add` and `Mul` take
payloads that are themselves `expr`s. So `Add` accepts two
`expr`s, not two `int`s directly. `Add (Num 1, Num 2)` is
well-typed; the fourth option incorrectly gives `Add` three
arguments. The recursive nesting (`Mul` of
`Add` of `Num`s) is exactly what makes this a *recursive* variant.
:::

:::quiz mcq id=M04-L04-q3
What type does the toplevel report for `None`?

- [ ] `unit`
- [ ] `None`
- [x] `'a option`
- [ ] `int option`

**Why:** `None` carries no payload, so its element type is
unconstrained at the point of definition. The toplevel reports
`'a option` (a polymorphic type variable), exactly like `[]`
reports `'a list`. The element type gets fixed once the value
is *used* in a context that demands a particular type (e.g.
assigning it to a `marks : int option` field forces the `'a`
to be `int`).
:::

:::quiz code id=M04-L04-q4
Write `safe_sqrt : float -> float option` that returns
`Some (sqrt x)` for non-negative `x`, and `None` when `x` is
negative. This is a *construction-only* exercise: build an
`option` value with `if`/`then`/`else`; you don't need pattern
matching yet (that's M05).

```ocaml
let safe_sqrt x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (safe_sqrt 4.0   = Some 2.0) "4";
  check (safe_sqrt 0.0   = Some 0.0) "0";
  check (safe_sqrt 9.0   = Some 3.0) "9";
  check (safe_sqrt (-1.0) = None)    "negative";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let safe_sqrt x =
  if x < 0.0 then None else Some (sqrt x)
```

`sqrt` (from the standard library) has type `float -> float`,
but it returns `nan` (not-a-number) on a negative input rather
than signalling an error. Wrapping it as `float option` is
*honest*: the type tells the caller that negatives are not
handled, and OCaml will force them to look at the `None` case
when they consume the result (we'll see how in M05).

:::

## Activity

:::slide

## Activity

Extend the `expr` type below with a `Sub` constructor that
represents subtraction (two sub-expressions, like `Add` and
`Mul`). Then construct a value representing `(7 - 3) - 2`.

```text
type expr =
  | Num of int
  | Add of expr * expr
  | Mul of expr * expr
  (* add Sub here *)
```

:::

:::solution

:::slide

## Activity solution

```ocaml
type expr =
  | Num of int
  | Add of expr * expr
  | Mul of expr * expr
  | Sub of expr * expr

let e = Sub (Sub (Num 7, Num 3), Num 2)
```

- One new constructor, same recursive payload shape.
- The value nests `Sub` inside `Sub`: `(7 - 3) - 2`.
- Walking and evaluating this comes in M05.

:::

:::

## What's next

:::slide

## What's next

Two **tutorials** that tie tuples, records, variants, recursive
types, `option`, and `result` together on worked examples:

- Lecture 5: a tiny **AST** for OCaml itself.
- Lecture 6: a tiny **file system**.

:::

We now have everything Module 4 had to offer: tuples, records,
variants, recursive variants, polymorphism, `option`, and
`result`. The next two lectures are tutorials that tie these
pieces together on worked examples: the
[AST tutorial](M04-L05-tutorial.html) models a tiny abstract
syntax tree for OCaml itself, and the
[file system tutorial](M04-L06-tutorial-fs.html) reapplies the
same toolkit to a different domain. Walking these data shapes
(the step we have been deferring since variants arrived)
starts in [Module 5](M05-L01-basic-patterns.html), where pattern
matching gets its own treatment.

## Reading

- **Cornell CS3110**, *Lists*:
  <https://cs3110.github.io/textbook/chapters/data/lists.html>
- **Cornell CS3110**, *Trees*:
  <https://cs3110.github.io/textbook/chapters/data/trees.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
