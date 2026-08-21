---
title: "Functors"
lecture_no: 8
week: 7
duration_target_min: 24
concepts: [functors, parameterized modules, Map.Make, generic data structures]
keywords: [OCaml, functor, Map.Make, Set.Make, parameterized modules]
activity_question: "Write your own functor [Bag (E : ORDERED)] that builds a multiset (a set that remembers how many times each element was added): [add] increments an element's count, [count] returns it. Instantiate it for [int] and check the counts."
think_about_this: "A functor is 'a module that takes a module as an argument'. Why is this strictly more powerful than just parameterizing over a *type*?"
reading:
  - title: "Cornell CS3110, Functors"
    url: https://cs3110.github.io/textbook/chapters/modules/functors.html
---

# Functors


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Functors</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 8</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

We have been writing [functions](M03-L01-functions-as-values.html)
that take values and return values all course. Modules, the
[last](M07-L06-module-basics.html) [two](M07-L07-signatures.html)
lectures introduced, are collections of values, types, and helpers
grouped under a name. This lecture introduces the natural next step:
*functions from modules to modules*. In OCaml these are called
*functors*, and they are how the language expresses generic data
structures and algorithms.

The name comes from [category theory](https://en.wikipedia.org/wiki/Functor);
in OCaml the practical meaning is narrower: a functor takes one or
more modules and produces a new module. We will keep saying
"function" for one informally, even though strictly speaking OCaml
functors live at the module level, not the value level: you cannot
store one in a list or return one from an `if`. They are
parameterised modules, with module-level parameters substituting for
value-level ones.

The standard library uses functors everywhere. `Map.Make`,
`Set.Make`, and `Hashtbl.Make` are all functors. When you want a
map keyed by strings, you write `module M = Map.Make(String)`; the
result is a full map module specialised for string keys. This
lecture explains how that works and shows you how to write your
own.

:::slide

## This lecture: functors

- Functions take values. Modules collect values.
- Natural next step: *functions from modules to modules*.
- In OCaml these are called *functors*.
- Borrowed from category theory; here the practical meaning is
  narrower: input one or more modules, output a new module.
- Live at the module level (not values): cannot be stored in
  lists or returned from `if`.
- The standard library uses them everywhere: `Map.Make`,
  `Set.Make`, `Hashtbl.Make`.
- Plan: why we need them, the `Map.Make` pattern, writing your
  own.

:::

## Why we need them

Most of the parameterisation we have done so far has been
*parametric polymorphism*: a function or type that works for any
element type without knowing anything about it.
[`List.map`](M06-L02-map.html)`: ('a -> 'b) -> 'a list -> 'b list`
is parametric in `'a` and `'b`; it treats elements as opaque tokens
and never looks inside them.

But many data structures cannot get away with that. A binary
search tree of `'a` needs to *compare* values of `'a` to decide
which side of a node to put them on. A hash table needs to *hash*
keys and compare them for equality. A sorted set needs an
ordering. Parametric polymorphism alone does not give you a
comparison function or a hash function: those would have to come
from somewhere.

Take `Map` specifically, since it is the example we use below. A
map answers `find k`: is there a binding for the key `k`, and
what value does it carry? To make that fast, the standard library
keeps the bindings in a *balanced binary search tree ordered by
key*. Looking up `k` walks down from the root, and at each node it
*compares* `k` with that node's key to decide whether to go left,
go right, or stop because it found it. That is O(log n)
comparisons rather than scanning all n bindings one by one. But
comparing two keys needs a `compare` function on the key type, and
parametric polymorphism cannot supply one: a polymorphic map would
treat its keys as opaque tokens and never look inside them. The
comparison has to be handed in from outside. That is precisely
what the argument module to `Map.Make` provides.

:::slide

## Why we need them

- `List.map` is **parametric polymorphism**: works for any `'a`.
- Sets/maps/hashtables need more: `compare`, `hash`, equality.
- Parametric polymorphism alone cannot supply those.
- **Functors** take a module providing the missing operations.
- Output: a data structure specialised to that module's type.

:::

:::slide

## Why does a *map* need `compare`?

A `Map` keeps its keys in a **sorted balanced tree**, so `find` is
O(log n), not a linear scan. Each step compares the search key
with the node's key to decide left, right, or stop:

```text
              2 -> "two"
             /          \
     1 -> "one"        3 -> "three"

find 3:  compare 3 2 > 0  ->  go right  ->  found
find 1:  compare 1 2 < 0  ->  go left   ->  found
```

- No ordering means no tree: you would scan *every* binding, O(n).
- Parametric polymorphism can't compare two `'a`s (it never looks
  inside them), so `compare` must be **supplied** by the argument
  module.

:::

Here is where functors come in. A functor takes as input a module
providing the required operations (`compare`, `hash`, whatever)
and produces a new module: the data structure specialised to that
input. The input module is the *parameter*; the output module is
the *instantiation*. You apply the functor by passing it an
argument module, exactly like calling a function.

## The pattern: Map.Make

The standard library's `Map` module is internally structured
around a functor called `Make`. Here is the everyday use:

```ocaml
module Int_map = Map.Make(struct
  type t = int
  let compare = Int.compare
end)

let m =
  Int_map.empty
  |> Int_map.add 1 "one"
  |> Int_map.add 2 "two"
  |> Int_map.add 3 "three"

let _ = Int_map.find 2 m        (* = "two" *)
let _ = Int_map.find_opt 999 m  (* = None *)
```

A few things to read out of that code. `Map.Make` is the functor.
Its *argument* is the inline module `struct type t = int; let
compare = Int.compare end`. The argument module provides the
key type and a comparison function on that type. `Map.Make`
returns a full map module specialised to that key type: `empty`,
`add`, `find`, `find_opt`, `mem`, and all the other standard map
operations. We bind the result to the name `Int_map`.

:::slide

## The pattern: `Map.Make`

```ocaml
module Int_map = Map.Make(struct
  type t = int
  let compare = Int.compare
end)

let m =
  Int_map.empty
  |> Int_map.add 1 "one"
  |> Int_map.add 2 "two"
  |> Int_map.add 3 "three"

let _ = Int_map.find 2 m        (* = "two" *)
let _ = Int_map.find_opt 999 m  (* = None *)
```

- `Map.Make` is a **functor**.
- Its argument is a module providing a type `t` and a `compare`
  function.
- It returns a module specialised to that type: keys are `int`,
  values can be any type.

:::

The values of the map are still polymorphic. `Int_map.t` is
parameterised: an `int -> string` map and an `int -> bool` map
are different types, but both come from the same `Int_map`
module. The *key* type is fixed by the functor application; the
*value* type is parametric.

## Strings as keys

The standard `String` module already provides what `Map.Make`
needs: a type `t` (which happens to be `string`) and a
`String.compare` function. So we can pass it directly:

```ocaml
module String_map = Map.Make(String)

let m =
  String_map.empty
  |> String_map.add "alice" 30
  |> String_map.add "bob" 25
  |> String_map.add "carol" 28

let _ = String_map.find_opt "alice" m   (* = Some 30 *)
let _ = String_map.find_opt "dave" m     (* = None *)
```

`String` has the right shape because the standard library is
designed for it: `String.t = string` and `String.compare` has the
required type `string -> string -> int`. The standard `Int`,
`Char`, and `Bytes` modules all satisfy the same interface; you
can use them as the argument to `Map.Make` directly.

:::slide

## The same with strings

```ocaml
module String_map = Map.Make(String)

let m =
  String_map.empty
  |> String_map.add "alice" 30
  |> String_map.add "bob" 25
  |> String_map.add "carol" 28

let _ = String_map.find_opt "alice" m   (* = Some 30 *)
let _ = String_map.find_opt "dave" m     (* = None *)
```

- `String` already has the right shape: a type `t` aliased to
  `string` and a `String.compare`.
- We pass it directly.
- `Map.Make` specialises to give us a string-keyed map.

:::

## What does the functor look like inside?

Conceptually, `Map.Make` is defined something like this:

```text
module Make (Key : sig
  type t
  val compare : t -> t -> int
end) = struct
  type key = Key.t
  type 'a t = ...  (* balanced tree implementation *)
  let empty = ...
  let add k v m = ...
  let find k m = ...
  let find_opt k m = ...
end
```

(`Make` lives inside the standard library's `Map` module, so you
write `Map.Make`.) `Make` takes a parameter `Key` of an inline
signature: any module
with a type `t` and a `compare : t -> t -> int`. Inside `Make`,
the type `Key.t` and the function `Key.compare` are available;
the body of the functor implements the map (with a balanced
binary search tree, for the standard library's `Map`), referring
to `Key.compare` for ordering comparisons.

:::slide

## What does the functor look like inside?

Conceptually:

```text
module Make (Key : sig
  type t
  val compare : t -> t -> int
end) = struct
  type key = Key.t
  type 'a t = ...  (* balanced tree implementation *)
  let empty = ...
  let add k v m = ...
  let find k m = ...
end
```

`Make` is a functor (it lives in `Map`, hence `Map.Make`): takes a
module with `(type t, compare)` and
returns a full map module. The stdlib's `Map.Make` is a few hundred
lines of balanced-binary-search-tree code; the *interface* is this
same shape.

:::

The actual implementation in the OCaml standard library is a few
hundred lines of balanced-binary-search-tree code. But the
*interface* is the shape above. The functor decides "I need a key
type and a comparison on it"; the user supplies those; the
functor returns a full map.

## Writing your own functor

Here is a toy `Set` functor, building on the `ORDERED` signature
we wrote at the
[end of the previous lecture](M07-L07-signatures.html#module-type-aliasing).

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module SetLite (E : ORDERED) = struct
  type elt = E.t
  type t = elt list  (* ascending, no duplicates *)

  let empty = []

  let rec mem x = function
    | [] -> false
    | y :: rest ->
        let c = E.compare x y in
        c = 0 || (c > 0 && mem x rest)

  let rec add x = function
    | [] -> [x]
    | y :: rest as ys ->
        let c = E.compare x y in
        if c = 0 then ys
        else if c < 0 then x :: ys
        else y :: add x rest
end

module Int_set = SetLite (struct
  type t = int
  let compare = Int.compare
end)

let s =
  Int_set.empty
  |> Int_set.add 8
  |> Int_set.add 2
  |> Int_set.add 5
let _ = Int_set.mem 5 s    (* = true *)
let _ = Int_set.mem 99 s   (* = false *)
```

A working sorted-list set in about twenty lines, parameterized
over any ordered type. The list is kept in ascending order
(smallest first), which is what lets `add` stop at the right
insertion point and `mem` give up as soon as it passes where `x`
would be.

:::slide

## Writing your own functor: the declaration

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module SetLite (E : ORDERED) = struct
  type elt = E.t
  type t = elt list  (* ascending, no duplicates *)
  let empty = []
  let rec mem x = function
    | [] -> false
    | y :: rest ->
        let c = E.compare x y in
        c = 0 || (c > 0 && mem x rest)
  let rec add x = function
    | [] -> [x]
    | y :: rest as ys ->
        let c = E.compare x y in
        if c = 0 then ys
        else if c < 0 then x :: ys
        else y :: add x rest
end
```

:::

:::slide

## Applying the functor

```ocaml
module Int_set = SetLite (struct
  type t = int
  let compare = Int.compare
end)

let s =
  Int_set.empty
  |> Int_set.add 8
  |> Int_set.add 2
  |> Int_set.add 5
let _ = Int_set.mem 5 s    (* = true *)
let _ = Int_set.mem 99 s   (* = false *)
```

- Apply with `SetLite (M)` where `M` satisfies `ORDERED`.
- `SetLite (String)` would give you a string set the same way.

:::

Notice the syntax: `module SetLite (E : ORDERED) = struct ...
end` declares a functor `SetLite`. The parameter `E` has signature
`ORDERED`; the parentheses around `(E : ORDERED)` are required. The
body of the functor is a structure, like any other module. Inside,
we reference `E.t` (the element type, abstract here) and
`E.compare` (the comparison function). The functor returns a
module with `elt`, `t`, `empty`, `mem`, `add`.

To apply the functor, write `SetLite (M)` where `M` is some
module satisfying `ORDERED`. We use an inline module to make
`Int_set`. The same trick works for any ordered type:
`SetLite (String)` would give us a string set,
`SetLite (Int_ord)` likewise if we had defined an `Int_ord`
module. One caveat if you do define such a module: sealing it as
`module Int_ord : ORDERED = ...` hides `t`, so the resulting
set's element type would be abstract and you could never build
an element to insert. Real code keeps `t` usable with a
signature *constraint*, `ORDERED with type t = int`, which the
practice problems cover.

This is the pattern. Define a signature describing what your data
structure needs from the element type (`compare`, or `hash`, or
`equal` + `hash`, or `zero` + `+`); write a functor parameterized
by a module of that signature; instantiate the functor for each
concrete element type you want.

## Functors versus Java generics

A natural question: how does this compare to `List<E>` in Java or
`Vec<T>` in [Rust](https://www.rust-lang.org/)?

In Java, the standard library's `TreeSet<E>` requires `E` to
implement the `Comparable<E>` interface. That is the constraint
on the element type. The user writes `TreeSet<String>` and the
compiler checks that `String` implements `Comparable`. The same
information OCaml carries in a *module* (a type `t` and a
`compare` function), Java carries in an *interface* and a class
that implements it.

The two approaches are roughly equivalent in expressiveness for
the data-structure use case. The OCaml approach scales more
cleanly when you want to combine *multiple* constraints (an
ordered, hashable type with a default value, say): you just
expand the signature. It is also more flexible because a single
type can satisfy multiple module signatures in different ways
(provide two different orderings on the same type by writing two
modules). The Java approach is more familiar to programmers
arriving from C++ or C#, where generics are the everyday
mechanism.

:::slide

## Functors are how `Set` and `Map` stay generic

- No plain `'a Set.t` in the stdlib.
- `Set.Make` *constructs* a set type for any ordered type.
- The orderedness is the **constraint**, supplied as a module.
- **Java parallel**: `TreeSet<E>` requires `Comparable<E>`.
- Same idea; an interface instead of a module type.

:::

## Including a functor's output

A common pattern: you want a `Map`-like module that has *all* the
operations of a standard `Map`, *plus* a few of your own. The
`include` keyword from the previous lecture combines with functor
application to make this easy.

```ocaml
module Int_map = struct
  include Map.Make(Int)
  let pp pp_value fmt m =
    iter (fun k v -> Format.fprintf fmt "%d -> %a; " k pp_value v) m
end
```

`include Map.Make(Int)` runs the functor, gets back a full
int-keyed map module, and copies all its definitions into the
enclosing structure. The `let pp ...` then adds a printer on top.
The resulting `Int_map` is "everything `Map.Make(Int)` would have
given you, plus our `pp`."

:::slide

## Including a functor's output

Want a functor's output *plus* your own helpers? `include` the
result:

```ocaml
module Int_map = struct
  include Map.Make(Int)
  let pp pp_value fmt m =
    iter (fun k v -> Format.fprintf fmt "%d -> %a; " k pp_value v) m
end
```

- `include Map.Make(Int)` brings in every map operation; `pp` adds
  a printer on top.
- The result is the **standard int-map plus our extension**.
- (Uses `Format`; not detailed here.)

:::

This pattern is *the* way to extend a standard library data
structure with project-specific helpers. You see it constantly in
real OCaml codebases.

## A quick check

:::quiz mcq id=M07-L08-q3
Why is the standard library's `Set` module a functor (`Set.Make`)
rather than a plain `Set` type parameterized by `'a`?

- [ ] To save memory.
- [ ] Because OCaml does not support polymorphic types.
- [x] A set needs an ordering for its elements.
- [ ] To make the API more complicated.

**Why:** a balanced binary search tree, the standard
implementation of `Set`, needs to compare elements to keep itself
sorted. A polymorphic `'a Set.t` would have no way to know how to
compare two `'a`s. The functor takes the comparison as part of its
argument module, fixing the element type and the ordering in one
go.
:::

:::quiz mcq id=M07-L08-q2
What is the result of this snippet? (`Map.Make(String)` orders
its keys with `String.compare`, the usual lexicographic
ordering.)

```ocaml
module M = Map.Make(String)
let m = M.empty |> M.add "b" 2 |> M.add "a" 1
let _ = M.find "a" m
```

- [ ] `2`
- [x] `1`
- [ ] `Not_found`
- [ ] error

**Why:** the map associates `"a"` with `1` and `"b"` with `2`.
`M.find "a" m` returns the value bound to `"a"`, which is `1`.
The order of `add` calls does not matter for which value `"a"`
is bound to: `add` is a *functional* update (returns a new map),
and the most recent binding for a key wins.
:::

## Activity

:::slide

## Activity

We wrote `SetLite (E : ORDERED)`, a functor that builds a *set*
(membership only). Write `Bag (E : ORDERED)` instead: a *multiset*
that remembers how many times each element was added. `add x`
increments `x`'s count; `count x` returns it (`0` if never added).

:::

:::quiz code id=M07-L08-q1
Define the `Bag` functor, including `add` and `count`. Use an
association list pairing each distinct element with its current count.

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

(* Define the Bag functor here. *)
```

```ocaml skip
module Int_bag = Bag (struct type t = int let compare = Int.compare end)

let check b m = if not b then failwith m
let () =
  let b =
    Int_bag.empty
    |> Int_bag.add 2
    |> Int_bag.add 5
    |> Int_bag.add 2
  in
  check (Int_bag.count 2 b = 2) "two 2s";
  check (Int_bag.count 5 b = 1) "one 5";
  check (Int_bag.count 99 b = 0) "absent element";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution: the functor

Reusing the same `ORDERED` signature from `SetLite`:

```ocaml
module Bag (E : ORDERED) = struct
  type elt = E.t
  type t = (elt * int) list
  let empty = []
  let rec add x = function
    | [] -> [(x, 1)]
    | (y, c) :: rest ->
        if E.compare x y = 0 then (y, c + 1) :: rest
        else (y, c) :: add x rest
  let rec count x = function
    | [] -> 0
    | (y, c) :: rest -> if E.compare x y = 0 then c else count x rest
end
```

- `add` bumps an existing element's count or starts it at `1`;
  `count` returns `0` when the element is absent.

:::

:::slide

## Activity solution: using it

```ocaml
module Int_bag = Bag (struct type t = int let compare = Int.compare end)

let b =
  Int_bag.empty
  |> Int_bag.add 2
  |> Int_bag.add 5
  |> Int_bag.add 2
let _ = Int_bag.count 2 b    (* = 2 *)
let _ = Int_bag.count 99 b   (* = 0 *)
```

- Instantiate the functor once for `int`; the result is a full
  multiset module.
- The same `Bag` functor would build a string multiset from
  `(struct type t = string let compare = String.compare end)`.

:::

:::

The point of the activity is that one functor argument
(`ORDERED`) supports many data structures: the same `compare` we
used for a set drives a multiset, a map, a priority queue, and so
on. Writing `Bag` as a functor (rather than fixing `elt = int`)
means it works for strings, dates, or any type you can order,
exactly like `SetLite`.

For comparison, the standard library's `Map.Make` we saw earlier
chains its inserts with the [`|>` operator](M06-L05-pipelines.html),
and each `add` returns a *new* map sharing structure with the old
one (persistent balanced trees, O(log n) per insert). The
association-list `Bag` here is simpler but O(n); swapping in a
balanced-tree representation later would not change its interface,
which is the whole point of [sealing a module behind a
signature](M07-L07-signatures.html).

## What's next

The [module tutorial](M07-L09-tutorial.html) is next.
We build a small *functional queue* using the classic two-stack
trick: keep two lists, one for the front and one for the back in
reverse order; push onto the back and pop from the front, refilling
the front from the (reversed) back when it runs out. We package the
queue as a module with a signature hiding the representation, then
turn it into a functor parameterised by the element type. It is a
worked example that touches every piece of machinery from this
module.

:::slide

## What's next

The next lecture is the **tutorial** for Module 7.

- Build a small "functional queue" using two stacks.
- Package it as a module with an interface.
- Parameterize it as a functor.

:::

## Reading

- **Cornell CS3110**, *Functors*:
  <https://cs3110.github.io/textbook/chapters/modules/functors.html>
- **Real World OCaml**, *Functors*:
  <https://dev.realworldocaml.org/functors.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
