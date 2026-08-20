---
title: "Module basics"
lecture_no: 6
week: 7
duration_target_min: 22
concepts: [modules, struct, namespacing, opening, naming hygiene]
keywords: [OCaml, module, struct, open, namespace]
activity_question: "Define a module [Stack] that maintains an integer stack with [push : int -> unit], [pop : unit -> int option], and [peek : unit -> int option]. Use a ref inside the module."
think_about_this: "A module groups definitions and a *namespace* under a name. What other languages give you both, and how does OCaml's module system differ from them?"
reading:
  - title: "Cornell CS3110, Modules"
    url: https://cs3110.github.io/textbook/chapters/modules/modules.html
---

# Module basics


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Module basics</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 6</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

So far every piece of OCaml we have written has lived at the top
level: a string of `let`s, `type`s, and `let rec`s, each defined
in a shared global namespace. That worked for the kinds of
examples this course has covered: a single file, a few dozen
definitions, every name visible everywhere. It would stop working
the instant we tried to write a real program.

Real programs need *structure*. They have hundreds of definitions
spread across dozens of files. Names collide: every module wants
to define `length`, every module wants to define `to_string`,
every module wants to define `map`. Implementations have internal
helpers that no caller should depend on. Two libraries written by
different teams need to coexist without clashing.

OCaml's answer to all of this is the *module system*. A module is
a named collection of definitions (values, types,
[exceptions](M07-L03-exceptions.html), even sub-modules) that you
can refer to as a unit. The standard library you have been using
all course is a tree of modules:
[`List`](M04-L04-recursive-types.html), `String`, `Array`,
[`Option`](M04-L04-recursive-types.html), `Map`, and so on. A
real OCaml project is a tree of *your* modules using and being used
by them. This lecture introduces the syntax. The
[signatures lecture](M07-L07-signatures.html) covers the
type-level description of a module that lets you hide internals.
The [functors lecture](M07-L08-functors.html) covers modules
parameterized by other modules. The
[module tutorial](M07-L09-tutorial.html) closes the module.

:::slide

## This lecture: module basics

- Everything so far has lived at the top level: one shared
  global namespace.
- Real programs need *structure*: hundreds of definitions,
  many files, name collisions everywhere.
- OCaml's answer: the *module system*.
- A module is a named collection of definitions (values, types,
  exceptions, sub-modules) referred to as a unit.
- The standard library is a tree of modules (`List`, `String`,
  `Array`, `Option`, `Map`, ...).
- **This lecture**: the syntax. Signatures, functors, and the
  tutorial come next.

:::

## Inline modules

The simplest way to define a module is right at the toplevel,
with `module Name = struct ... end`.

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
  let goodbye name = "goodbye, " ^ name
end

let _ = Greet.hello "world"     (* = "hello, world" *)
let _ = Greet.goodbye "world"   (* = "goodbye, world" *)
```

The shape is consistent throughout the language: `module Name =
struct ... end` is to modules what `let name = ...` is to values.
You bind a *name* (`Greet`) to a *value* (the structure between
`struct` and `end`). Inside the structure, you write top-level
definitions exactly as you would in a `.ml` file. Outside, you
refer to those definitions with the dot notation `Greet.hello`,
`Greet.goodbye`.

:::slide

## Inline modules

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
  let goodbye name = "goodbye, " ^ name
end

let _ = Greet.hello "world"     (* = "hello, world" *)
let _ = Greet.goodbye "world"   (* = "goodbye, world" *)
```

- A module is `module Name = struct ... end`.
- Inside the struct, you write top-level definitions just like in
  a `.ml` file.
- Outside, you access them with `Name.value`.

:::

A module name must start with an uppercase letter. The convention
is `CamelCase` (or `Snake_case` with the first letter capitalised,
as in `Pretty_printer`). This is unlike value names, which start
with lowercase. The capitalisation distinction is enforced by the
syntax: `Greet.hello` is unambiguous because the compiler knows
`Greet` is a module reference (uppercase) and `hello` is a value
inside it (lowercase).

## Every .ml file is a module

Inside a real OCaml project, you do not usually write `module Foo
= struct ... end` to make a module called `Foo`. You write a file
called `foo.ml`. The compiler automatically wraps the file's
contents in a structure and exposes it as the module `Foo`. Other
files reference its contents as `Foo.x`, `Foo.f`, and so on.

This is how the standard library is structured: there is a
`list.ml` in the OCaml source tree that exposes the `List` module,
a `string.ml` for `String`, an `array.ml` for `Array`. Your
project will look the same: you have a `parser.ml`, a
`pretty_printer.ml`, a `cache.ml`, each becoming `Parser`,
`Pretty_printer`, `Cache` to the rest of the program.

:::slide

## Each `.ml` file is a module

- Code in `foo.ml` is automatically wrapped in
  `module Foo = struct ... end`.
- Other files reference its contents as `Foo.x`, `Foo.f`, etc.
- The standard library is organized this way: `list.ml` exposes
  the `List` module, `string.ml` exposes `String`, etc.
- For now we use inline modules (`module M = struct ... end`) in
  the toplevel cells to keep examples self-contained.

:::

For this lecture, because we are writing examples that run in a
single toplevel cell, we use the inline `module M = struct ...
end` form. In your projects, you will write the contents directly
in a `.ml` file and the file system will do the wrapping for you.

## Modules contain types too

A module is not just a namespace for values. It can hold *types*,
*[exceptions](M07-L03-exceptions.html)*, and *sub-modules* as well.

```ocaml
module Color = struct
  type t = Red | Green | Blue
  let to_string = function
    | Red -> "red"
    | Green -> "green"
    | Blue -> "blue"
end

let c : Color.t = Color.Red
let _ = Color.to_string c   (* = "red" *)
```

Notice the dot notation extends
uniformly: `Color.t` is the *type* defined inside `Color`,
`Color.Red` is one of its constructors, `Color.to_string` is the
function. From outside, you always go through the module name.

:::slide

## Modules contain types too

```ocaml
module Color = struct
  type t = Red | Green | Blue
  let to_string = function
    | Red -> "red"
    | Green -> "green"
    | Blue -> "blue"
end

let c : Color.t = Color.Red
let _ = Color.to_string c   (* = "red" *)
```

- The `Color` module exposes a type `t` and a function
  `to_string`.
- From outside: `Color.t` for the type, `Color.Red` for the
  constructor.
- **Convention**: a module mainly about a type names that type `t`
  (so it's `Color.t`, not `Color.color`).

:::

There is a strong convention in OCaml for modules that are *about*
one principal type: name that type `t`. So `Color.t`, not
`Color.color`; `Set.t`, not `Set.set`; `Map.t`, not `Map.map`.
The thinking is that the module name already says what kind of
thing it is, and the type name does not need to repeat it. The
result is the cleaner-reading `Color.t` style you see throughout
the standard library: `String.t`, `List.t`, `Bytes.t`.

## open brings names into scope

If you find yourself writing `Greet.hello` and `Greet.goodbye`
repeatedly in a block of code, you can *open* the module to drop
the prefix.

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
  let goodbye name = "goodbye, " ^ name
end

let _ =
  let open Greet in
  hello "alice" ^ "; " ^ goodbye "alice"
  (* = "hello, alice; goodbye, alice" *)
```

The `let open M in expr` form opens `M` *only* inside `expr`.
Outside that expression, you still need the `Greet.` prefix. This
is called the *local open*, and it is the form to reach for: it
keeps the scope of the open visible to the reader. Anyone reading
the code sees right where the open begins and ends.

:::slide

## `open` brings names into scope

If you use `Greet.hello` and `Greet.goodbye` repeatedly, you can
*open* the module to drop the prefix:

```ocaml
module Greet = struct
  let hello name = "hello, " ^ name
  let goodbye name = "goodbye, " ^ name
end

let _ =
  let open Greet in
  hello "alice" ^ "; " ^ goodbye "alice"   (* = "hello, alice; goodbye, alice" *)
```

- `let open M in expr` opens `M` inside `expr` only.
- Outside, `Greet` is still required as a prefix.
- This is the **local open**.
- Preferred over the global `open M` because it makes the scope of
  the open visible.

:::

The other open form is `open M` at the top level of a file or
module, which brings every name from `M` into scope for the rest
of the file. For small modules with little chance of name
collision, this is fine. For large modules like `List` or
`String`, opening globally is risky: too many short names get
pulled in, and a reader of the code can no longer tell at a
glance whether `map` means `List.map` or `String.map` or
something else entirely. The local open avoids that question by
limiting the scope.

:::slide

## When *not* to `open`

- Global `open M` brings every name from `M` into the rest of the
  file.
- For small modules, fine.
- For big ones (`open List`, `open Stdlib`), it can hide where a
  name comes from.
- **Middle ground**: `M.(...)` (local open in parentheses) or
  `M.[...]` (the list form) opens `M` only inside the brackets:

```ocaml
let _ = String.(length "x" + length "yy")   (* = 3 *)
let _ = List.[1; 2; 3]                      (* = [1; 2; 3] *)
```

- The first writes `length` twice with no `String.` prefix and
  no `open` leaking out of the parentheses.
- The second is unnecessary here (lists are top-level) but shows
  the syntax.

:::

There is a middle form, `M.(expr)`, which opens `M` in just the
parenthesised expression. It is even shorter than a local open
when you have a tight cluster of references:

```ocaml
let _ = List.(map (fun x -> x * 2) [1; 2; 3])   (* = [2; 4; 6] *)
```

Use whichever feels clearest at the call site.

## Hiding internals: the natural limitation

Inside a module you can define helper functions and values that
you do not intend to be used from outside.

```ocaml
module Counter = struct
  let n = ref 0
  let next () = incr n; !n
  let reset () = n := 0
end

let _ = Counter.next ()   (* = 1 *)
let _ = Counter.next ()   (* = 2 *)
let _ = !Counter.n        (* = 2 *)
```

Here is the catch: without an interface, *every* definition in
the module is visible to the outside world. The `n` ref is meant
to be private state, used only by `next` and `reset`. But callers
can read it with `!Counter.n` and even *write* to it with
`Counter.n := -100`. The encapsulation is purely conventional.

:::slide

## Hiding internals

- Helpers inside a module can be marked as not for outside use.
- **Without an interface**, every definition is visible.
- **With an interface** (next lecture), you control what escapes.

```ocaml
module Counter = struct
  let n = ref 0
  let next () = incr n; !n
  let reset () = n := 0
end

let _ = Counter.next ()   (* = 1 *)
let _ = !Counter.n        (* = 1; leaks: external code pokes at n *)
```

- The `n` ref is visible from outside; the next lecture hides it
  with a module signature.

:::

This is the major motivation for the
[next lecture](M07-L07-signatures.html). The fix is to constrain
the module with a *signature*: a type-level description that lists
exactly which names escape, with which types. Anything not in the
signature is invisible from the outside. We hold off on the details
until the [signatures lecture](M07-L07-signatures.html).

## Modules can nest

Modules can contain sub-modules:

```ocaml
module Geometry = struct
  module Point = struct
    type t = { x : float; y : float }
    let origin = { x = 0.0; y = 0.0 }
    let make x y = { x; y }
  end

  module Vector = struct
    type t = { dx : float; dy : float }
    let zero = { dx = 0.0; dy = 0.0 }
  end
end

let p = Geometry.Point.make 3.0 4.0
let _ = p.x   (* = 3. *)
```

The dot notation extends to any depth for
*module* paths: `Geometry.Point.t`, `Geometry.Point.make`, and so
on. The field access on the last line is just `p.x`, not
`p.Geometry.Point.x`: OCaml already knows `p : Geometry.Point.t`,
so it resolves the label `x` from that type (type-directed
disambiguation). You need the path to *reach* the module's
values, not to read a field off a value whose type is known.

:::slide

## Modules can nest

```ocaml
module Geometry = struct
  module Point = struct
    type t = { x : float; y : float }
    let make x y = { x; y }
  end

  module Vector = struct
    type t = { dx : float; dy : float }
  end
end

let p = Geometry.Point.make 3.0 4.0
let _ = p.x   (* = 3.0 *)
```

- Sub-modules organize a tree of related concepts.
- Module access goes through the full path; the field read is just
  `p.x` (the type of `p` fixes which record `x` belongs to).

:::

:::slide

## In real projects, each file is a module

- Each `.ml` file is *one* module: `point.ml` defines a module
  `Point` (the filename, capitalised).
- These are **top-level** modules. A `geometry/` directory does
  *not*, on its own, give you `Geometry.Point`: the core language
  has no notion of directories.
- Nesting like `Geometry.Point` comes from either explicit
  `module Point = struct ... end` (as above) or a build system
  wrapping a library under a namespace.

:::

In a real project, each `.ml` file is automatically a module
named after the file: `point.ml` defines `Point`, `vector.ml`
defines `Vector`. These are *top-level* modules, so you write
`Point.t` and `Vector.t`, not `Geometry.Point.t`. The core OCaml
module system knows nothing about directories: putting the files
in a `geometry/` directory does *not* by itself create a
`Geometry` module wrapping them.

Getting a `Geometry.Point` namespace at project scale is the job
of the build system. Dune, for instance, can *wrap* a library so
its files become submodules of a single module named after the
library (a library `geometry` exposes `Geometry.Point`,
`Geometry.Vector`). That is a build-time convenience layered on
top of the language, not part of the module system itself. The
inline `module Point = struct ... end` nesting above is how you
build the tree *within* a single file.

## Modules are not first-class

OCaml modules live at a *different level* from values. You cannot
pass a module as an argument to a regular function. You cannot
store a module in a list. You cannot return one from an `if`.
This is what people mean when they say OCaml has *two* type
systems: the value-level type system you have been using all
course, and a separate module-level type system on top.

There is an extension called *first-class modules* that does let
you package a module as a value (`(module M : T)`) and unpack it
on the other end (`(val v : T)`). It is occasionally useful, but
not for everyday code. For the standard module toolkit this
lecture introduces, modules live at compile time and are used
statically. The "function-like" thing that takes a module and
returns a module is called a *functor*, and we cover it in the
[functors lecture](M07-L08-functors.html).

:::slide

## Modules are values, sort of

- Not first-class by default; cannot pass them like ints.
- *First-class modules* are an extension; ignored this week.
- Modules live at **compile time**, used statically.
- A function from modules to modules is a **functor** (a later
  lecture).

:::

## A quick check

:::quiz mcq id=M07-L06-q3
Given this module:

```ocaml
module M = struct
  type t = int
  let zero = 0
  let succ x = x + 1
end
```

What is the value of `M.succ M.zero`?

- [ ] `0`
- [x] `1`
- [ ] `M.succ`
- [ ] error

**Why:** `M.zero` is `0`. `M.succ` is the function `fun x -> x +
1`. Applied to `0`, it returns `1`. The dot notation works for
both values and types: `M.t` is the type, `M.zero` is the value.
:::

:::quiz mcq id=M07-L06-q2
Why does the convention `type t` (not `type color`, `type stack`,
etc.) exist?

- [ ] To save typing.
- [ ] Because OCaml requires it.
- [x] Because the module name already says what the type is about,
  so the type name does not need to repeat it.
- [ ] To match Haskell.

**Why:** `Color.t` is cleaner than `Color.color`: the module name
provides the context, and the short `t` avoids stutter. The
convention is widespread in the standard library (`List.t`,
`String.t`, `Bytes.t`) and idiomatic in third-party code.
:::

## Activity

:::slide

## Activity

Define a module `Stack` with a mutable integer stack: `push : int
-> unit`, `pop : unit -> int option`, `peek : unit -> int option`.

:::

:::quiz code id=M07-L06-q1
Define a `Stack` module holding integer state.

```ocaml
module Stack = struct
  (* Define the private state and the push, pop, and peek operations. *)
end
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  Stack.push 1;
  Stack.push 2;
  Stack.push 3;
  check (Stack.peek () = Some 3) "peek after three pushes";
  check (Stack.pop () = Some 3) "pop returns 3";
  check (Stack.pop () = Some 2) "pop returns 2";
  check (Stack.peek () = Some 1) "peek sees 1";
  check (Stack.pop () = Some 1) "pop returns 1";
  check (Stack.pop () = None) "pop on empty";
  check (Stack.peek () = None) "peek on empty";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution: the module

```ocaml
module Stack = struct
  let s = ref []
  let push x = s := x :: !s
  let pop () =
    match !s with
    | [] -> None
    | x :: rest -> s := rest; Some x
  let peek () =
    match !s with
    | [] -> None
    | x :: _ -> Some x
end
```

- Private state `s`, a `ref` of a list, lives inside the module.
- `push` / `pop` / `peek` all mutate or read the same cell.

:::

:::slide

## Activity solution: using it

```ocaml
let () = Stack.push 1
let () = Stack.push 2
let () = Stack.push 3
let _ = Stack.peek ()    (* = Some 3 *)
let _ = Stack.pop ()     (* = Some 3 *)
let _ = Stack.pop ()     (* = Some 2 *)
```

- Push 1, 2, 3; `peek` reads the top (`Some 3`) without removing.
- `pop` returns and removes: `Some 3`, then `Some 2`.
- There's *one* stack, shared by every caller: the simplest design.
- For multiple independent stacks: create *values*, not modules;
  - make the stack a type passed to the operations, or have a
    `make ()` return a fresh one.

:::

:::

A few things to notice. The state is a [`ref`](M07-L01-references.html)
of an `int list`, held by the module itself. Every caller of
`Stack.push` mutates the same list; there is exactly one stack in
the program. If you wanted multiple independent stacks, you would
either (a) make the stack a *type* with operations that take and
return stacks (the functional style we will see in the
[module tutorial](M07-L09-tutorial.html)), or (b) provide a constructor
`Stack.make ()` that returns a fresh ref each time.

The other thing to notice: the `s` ref is visible to outside
code, just like the `n` ref in the `Counter` example earlier.
Someone could write `Stack.s := []` from outside and break the
abstraction. Hiding `s` is the job of a signature, which is the
[next lecture](M07-L07-signatures.html).

## What's next

The [next lecture](M07-L07-signatures.html) introduces *signatures*,
the type-level description of a module. A signature lists which
names escape and at what type; everything else is hidden. Once you
constrain a module by a signature, the internal `ref`s and helper
functions become invisible to the outside world, and you can change
them later without breaking any caller. This is OCaml's
encapsulation story.

:::slide

## What's next

Lecture 7: **module signatures**.

- A signature (`sig ... end` or a `.mli` file) is a type-level
  description of a module.
- It specifies which names escape, with which types.
- The basis of OCaml's encapsulation story.

:::

## Reading

- **Cornell CS3110**, *Modules*:
  <https://cs3110.github.io/textbook/chapters/modules/modules.html>
- **Real World OCaml**, *Files, Modules, and Programs*:
  <https://dev.realworldocaml.org/files-modules-and-programs.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
