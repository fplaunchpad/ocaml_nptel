---
title: "Mutable records and arrays"
lecture_no: 2
week: 7
duration_target_min: 22
concepts: [mutable record fields, arrays, in-place update, when to use mutation]
keywords: [OCaml, mutable, array, record, in-place, mutation]
activity_question: "Write a function [reverse_in_place : 'a array -> unit] that reverses an array in place (mutating its contents). Test that the original array has been modified."
think_about_this: "Arrays are O(1) indexed access; lists are O(n). When does the constant-time access matter enough to give up the functional immutability of lists?"
reading:
  - title: "Cornell CS3110, Arrays"
    url: https://cs3110.github.io/textbook/chapters/mut/arrays.html
---

# Mutable records and arrays


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Mutable records and arrays</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Beyond the single-cell [`ref`](M07-L01-references.html), OCaml has
two more mutable building blocks: *records with mutable fields*
and *fixed-size arrays*. The
[previous lecture](M07-L01-references.html) introduced `ref` and
the equational-reasoning tradeoff that comes with mutation. This
lecture introduces general mutable record fields; once we have
those, we will see that `ref` is just the one-field special case.
Then we spend most of our time on arrays: when they are the right
tool, how to allocate and access them, how they compare with
[the lists](M04-L04-recursive-types.html) we have been using all
course, and the loop syntax that lives alongside them.

The decision of when in-place mutation pays for the equational
reasoning you give up runs through both halves of the lecture.

:::slide

## This lecture: mutable records and arrays

- Beyond `ref`: two more mutable building blocks in OCaml.
- *Mutable record fields*: mark individual fields with `mutable`.
- *Arrays*: fixed-size, O(1) indexed, in-place update.
- How arrays compare with the lists we have used all course.
- The loop syntax (`for`, `while`) that lives alongside them.
- Running question: when does in-place mutation pay for the
  equational reasoning you give up?

:::

## Mutable record fields

You mark a [record](M04-L02-records.html) field `mutable` when you
want to update it in place after the record has been constructed.

```ocaml
type counter = { mutable n : int; name : string }

let c = { n = 0; name = "visits" }
let () = c.n <- c.n + 1
let () = c.n <- c.n + 1
let _ = c.n      (* = 2 *)
let _ = c.name   (* = "visits" *)
```

Only fields marked `mutable` can be updated: trying
to write `c.name <- "x"` would be a *compile-time error*. The `<-`
operator is the field-assignment operator. It takes a field-access
expression on the left and a new value on the right, and produces
`unit`.

:::slide

## Mutable record fields

You declare a field `mutable` when you want to update it in place:

```ocaml
type counter = { mutable n : int; name : string }

let c = { n = 0; name = "visits" }
let () = c.n <- c.n + 1
let () = c.n <- c.n + 1
let _ = c.n      (* = 2 *)
let _ = c.name   (* = "visits" *)
```

- Only fields marked `mutable` can be updated.
- The `name` field is immutable.
- Trying to write `c.name <- "x"` would be a compile error.
- `<-` is the field-assignment operator.

:::

Marking *just* the fields that change makes design intent visible
right at the type. A reader sees `mutable n : int` and knows the
counter's number changes; they see `name : string` (no `mutable`)
and know the label does not. The constraint is checked by the
compiler: any code that tries to assign to `name` is rejected.

```ocaml
type buffer = {
  capacity : int;            (* fixed at creation *)
  mutable size : int;        (* changes as we push *)
  mutable contents : string  (* changes as we push *)
}
```

In a record like this, the type declaration is part of the
documentation. The capacity is set once; the size and contents
update as the buffer fills.

:::slide

## Why some fields mutable and others not

- Marking just the fields that change makes **design intent
  visible**.
- A `counter` with `mutable n` but immutable `name` says: "the
  number changes; the label does not".
- Anyone reading the type can tell from the declaration.

```ocaml
type buffer = {
  capacity : int;        (* fixed at creation *)
  mutable size : int;    (* changes as we push *)
  mutable contents : string  (* changes as we push *)
}
```

- The type declaration documents what's allowed to change.

:::

## A `ref` is just a record with one mutable field

Now that you have seen mutable record fields, the implementation
of `ref` is no longer mysterious. The standard library defines
`'a ref` as a one-field record with that field marked `mutable`:

```text
type 'a ref = { mutable contents : 'a }
```

The operators `!` and `:=` are just shorthand for accessing and
updating that field:

- `!r` is `r.contents`.
- `r := x` is `r.contents <- x`.

So `ref` is not a magic builtin: it is exactly a record with one
mutable field, and the mutable-field machinery you just saw is
what `ref` uses internally.

For named mutable state, the record form is often more readable:
`c.n <- c.n + 1` reads like an imperative assignment. The `ref`
form, with `!` and `:=`, is more concise when you have a single
cell. Both compile to the same thing.

:::slide

## A `ref` is just a record with one mutable field

`'a ref` is literally:

```text
type 'a ref = { mutable contents : 'a }
```

- `!r` is `r.contents`.
- `r := x` is `r.contents <- x`.
- `ref` is **not a magic builtin**: a record with one mutable
  field.
- Named record: `c.n <- ...` reads like assignment.
- `ref`: `!` and `:=` are more concise for a single cell.

:::

## A worked example: a doubly-linked list

Mutable record fields earn their keep when a single update has to
be visible through several pointers. The canonical example is a
*doubly-linked list*: each node points to its successor *and* its
predecessor, so insertion and deletion at the middle of the list
takes O(1) once you have a handle on the node.

The shape:

```ocaml
type 'a node = {
  value : 'a;
  mutable next : 'a node option;
  mutable prev : 'a node option;
}

type 'a dllist = 'a node option ref
```

Two design choices worth noticing. The `next` and `prev` fields
are [`option`](M04-L04-recursive-types.html#the-option-type) so a
node at either end can record "no neighbour." A list is a `ref` of
the head node (also `option`, since the list might be empty); the
`ref` lets the head pointer itself change when we prepend a new
element. The `node` type combines both kinds of mutation we have
seen: mutable fields *inside* the node, and a `ref` for the
overall handle.

:::slide

## A doubly-linked list

Each node points to its successor *and* its predecessor:

```ocaml
type 'a node = {
  value : 'a;
  mutable next : 'a node option;
  mutable prev : 'a node option;
}

type 'a dllist = 'a node option ref
```

- `next` and `prev` are `option`: a node at either end records "no
  neighbour".
- The list is a `ref` of the head: the head pointer itself can
  change when we prepend.
- Combines mutable fields **inside** the node with a `ref` for the
  handle.

:::

The empty list is a fresh `ref` of `None`. `insert_first` adds a
new node at the front; because the list is doubly linked, the new
node has to be hooked up *and* the old head (if there was one)
has to learn that it has a new predecessor.

```ocaml
let create () : 'a dllist = ref None

let insert_first (t : 'a dllist) v =
  let n = { value = v; prev = None; next = !t } in
  (match !t with
   | Some old_head -> old_head.prev <- Some n
   | None -> ());
  t := Some n;
  n
```

The function mutates *two* places: `old_head.prev` (a mutable
field on the existing first node) and `t` itself (the ref holding
the head pointer). Both updates are needed; missing either leaves
the list in an inconsistent state.

Walking the list is a normal recursion over the `option` chain,
producing side effects on each value:

```ocaml
let iter (t : 'a dllist) f =
  let rec walk = function
    | None -> ()
    | Some node -> f node.value; walk node.next
  in
  walk !t
```

:::slide

## `create` and `insert_first`

```ocaml
let create () : 'a dllist = ref None

let insert_first (t : 'a dllist) v =
  let n = { value = v; prev = None; next = !t } in
  (match !t with
   | Some old_head -> old_head.prev <- Some n
   | None -> ());
  t := Some n;
  n
```

- `insert_first` mutates *two* places: the old head's `prev`, and
  the list's head ref.
- Miss either and the list is inconsistent.

:::

:::slide

## `iter` over the chain

```ocaml
let iter (t : 'a dllist) f =
  let rec walk = function
    | None -> ()
    | Some node -> f node.value; walk node.next
  in
  walk !t
```

- Plain recursion over the `option` chain.
- `f node.value` is the per-element effect.
- Backward iteration would need a tail handle in `dllist`; we
  kept the type minimal, so `iter` only walks `next`.

:::

A short demo, inserting 3 then 2 then 1 (so the list reads 1, 2, 3
head-to-tail):

```ocaml
let l = create ()
let _ = insert_first l 3
let _ = insert_first l 2
let _ = insert_first l 1
let () = iter l (fun x -> print_int x; print_string " ")
let () = print_newline ()
```

The `iter` line prints `1 2 3`. The same data lives in the chain
of nodes; `iter` walks it forwards from the head handle. We do
not keep a *tail* handle in `dllist`, so to walk backwards from
the tail we would first have to walk forward to find the tail
and then step `prev`. The reason we still bother with `prev` is
that once we have a node in hand (returned by a search, or the
current cursor of an iteration) we can splice it out or step
sideways in O(1).

Each `insert_first` line also prints the resulting node. Look at
the output for `insert_first l 2`:

```text
- : int node =
{value = 2; next = Some {value = 3; next = None;
                         prev = Some <cycle>}; prev = None}
```

The `<cycle>` is the toplevel's way of saying "this points back
somewhere we have already printed." Node 2's `next` is node 3,
and node 3's `prev` is node 2: a cycle in the value graph. The
pretty-printer follows the `next` link into node 3, then meets
the `prev` link back to node 2, and rather than infinitely
recursing it writes `<cycle>` and stops. Cyclic values are
exactly the kind of thing that immutable construction cannot
produce (the values do not exist yet to refer to each other);
the mutable fields are what let us tie the knot, and `<cycle>`
is the visible signature of a tied knot in the toplevel.

:::slide

## Demo

```ocaml
let l = create ()
let _ = insert_first l 3
let _ = insert_first l 2
let _ = insert_first l 1
let () = iter l (fun x -> print_int x; print_string " ")
let () = print_newline ()
```

Prints `1 2 3`.

- `insert_first` prepends, so the three inserts give head-to-tail
  order `1, 2, 3`.
- `dllist` only stores the *head*: no tail handle, no backward
  iteration from the end without first walking forward.
- The point of `prev` is local: once we have a node in hand, we
  can step backward or splice it out (update its neighbours'
  `next`/`prev`) in O(1).

:::

This is the smallest example that puts together everything we have
seen: a [recursive type](M04-L04-recursive-types.html), a record
with mutable fields, an [option](M04-L04-recursive-types.html#the-option-type)
to mark the ends of the chain, and a [`ref`](M07-L01-references.html)
to let the handle change. It is also a good place to feel why
mutation is the right tool here: every linked-list operation that
preserves links must update them in place, and threading new lists
through every call would be both painful and miss the point.

## Arrays

An *array* is a fixed-size, mutable sequence of values, all of the
same type. The literal syntax uses bar-brackets:

```ocaml
let a = [| 10; 20; 30; 40; 50 |]

let _ = a.(0)            (* = 10 *)
let _ = a.(2)            (* = 30 *)
let () = a.(2) <- 999
let _ = a                (* = [|10; 20; 999; 40; 50|] *)
```

A few syntactic things to note:

- Array literals are `[| e0; e1; ...; en |]`, with semicolons
  between elements. The bars distinguish them from lists, which
  use plain brackets.
- Indexing is `a.(i)`. The parentheses are mandatory; this is not
  the dot you use for records.
- Assignment is `a.(i) <- value`, the same `<-` operator we just
  saw on records.
- Indexing is zero-based.
- Out-of-bounds access raises the standard exception
  `Invalid_argument` (we cover exceptions in the
  [next lecture](M07-L03-exceptions.html)).

:::slide

## Arrays

A fixed-size, mutable sequence:

```ocaml
let a = [| 10; 20; 30; 40; 50 |]

let _ = a.(0)            (* = 10 *)
let _ = a.(2)            (* = 30 *)
let () = a.(2) <- 999
let _ = a                (* = [|10; 20; 999; 40; 50|] *)
```

- Array literals use `[| ... |]` with `;` separators.
- Indexing uses `a.(i)`.
- Assignment uses `a.(i) <- value`.
- Out-of-bounds access raises `Invalid_argument`.
- Arrays are *zero-indexed*, like lists.

:::

Why use array notation `a.(i)` instead of square brackets `a[i]`
like C, Java, or Python? Square brackets are already taken by list
syntax (`[1; 2; 3]`), and the language designers wanted indexing
to look syntactically distinct from list construction. The
parenthesised dot form was the result. The compiler treats
`a.(i)` and `a.(i) <- v` as primitive operations: there is no
function call overhead and they compile to direct array loads and
stores.

## Lists vs arrays

The choice between a list and an array is a recurring question.
The two have different cost profiles and different relationships
to immutability.

| | `'a list` | `'a array` |
| --- | --- | --- |
| Indexed access | O(n) | O(1) |
| Cons / prepend | O(1) | not direct |
| Append / extend | O(n) | not direct |
| Immutable | yes | no |
| Length fixed | no | yes |
| Sharing tails | yes | no |
| Equational reasoning | yes | no for mutated cells |

The standard trade-off is between O(1) random access (arrays) and
O(1) prepending plus immutability (lists). If your computation
walks the data front to back, building up a result as it goes, a
list is usually the more natural shape; we have seen this all
through the [pattern-matching](M05-L01-basic-patterns.html) and
[higher-order-functions](M06-L01-functions-revisited.html)
modules. If your computation
needs to *jump* to arbitrary positions, an array is the right tool.

:::slide

## Array vs list: a trade-off table

| | `'a list` | `'a array` |
| --- | --- | --- |
| Indexed access | O(n) | O(1) |
| Cons / prepend | O(1) | not direct |
| Append / extend | O(n) | not direct |
| Immutable | yes | no |
| Length fixed | no | yes |
| Sharing tails | yes | no |
| Equational reasoning | yes | no for mutated cells |

- **Arrays**: fast random access; **lists**: front-to-back + immutability.
- Dynamic size + indexed access: reach for `Dynarray` or `Buffer`.

:::

Neither structure is good for "dynamically growing with fast
indexed access." For that, OCaml 5.2 introduced `Dynarray`, a
resizable array akin to C++'s `std::vector` or Java's `ArrayList`;
for byte-string building, there is `Buffer`. We will not use
either in this course, but it is good to know what your options
are when you outgrow the trade-off above.

## Allocating arrays

You rarely write a large array as a literal. The standard library
gives you three workhorse constructors.

```ocaml
let _ = Array.make 5 0                  (* = [|0; 0; 0; 0; 0|] *)
let _ = Array.init 5 (fun i -> i * i)   (* = [|0; 1; 4; 9; 16|] *)
let _ = Array.of_list [10; 20; 30]      (* = [|10; 20; 30|] *)
```

`Array.make n x` allocates an array of length `n` with every
element initialised to `x`. `Array.init n f` allocates an array of
length `n` where element `i` is computed by calling `f i`.
`Array.of_list` converts an existing list into an array.

:::slide

## Building an array

```ocaml
let _ = Array.make 5 0                  (* = [|0; 0; 0; 0; 0|] *)
let _ = Array.init 5 (fun i -> i * i)   (* = [|0; 1; 4; 9; 16|] *)
let _ = Array.of_list [10; 20; 30]      (* = [|10; 20; 30|] *)
```

- `Array.make n x` creates an array of length `n` with every
  element `x`.
- `Array.init n f` creates an array where element `i` is `f i`.
- `Array.of_list xs` converts a list to an array.

:::

`Array.init` is the one to remember: it is the array equivalent
of writing a list comprehension or a generator. Given a length and
a function from index to value, it allocates the array and runs
the function on each index. You do *not* see the function called
in a particular order, but in practice it is `0, 1, ..., n-1`.

## Iterating arrays

The [`Array`](https://v2.ocaml.org/api/Array.html) module mirrors
the [higher-order functions we have seen on lists](M06-L01-functions-revisited.html).
`Array.iter` is the side-effecting walk;
[`Array.map`](M06-L02-map.html) returns a new array; there are also
[`fold_left`, `fold_right`](M06-L04-fold.html), `length`,
`to_list`, and the obvious shape-shifters.

```ocaml
let a = [|10; 20; 30|]

let () = Array.iter (fun x -> print_endline (string_of_int x)) a
```

This prints `10`, `20`, `30` on separate lines. `Array.iter`
returns `unit`; it is for *effect*, not for value.

You could get the same printing out of `Array.map`, since the
elements go through the callback either way:

```ocaml
let a = [|10; 20; 30|]
let b = Array.map (fun x -> print_endline (string_of_int x)) a
let _ = b   (* = [|(); (); ()|] *)
```

It type-checks and prints, but the result is an array of three
`()`s, allocated only to be thrown away. When the callback runs
for its effect, `iter` says so in its type; reserve `map` for
callbacks whose results you keep.

For a pure transformation that does not mutate the input, use
`Array.map`:

```ocaml
let a = [|10; 20; 30|]
let b = Array.map (fun x -> x * 2) a
let _ = b   (* = [|20; 40; 60|] *)
let _ = a   (* = [|10; 20; 30|]: untouched *)
```

`Array.map` allocates a new array and leaves the input
unchanged. To update the input in place, use `Array.iteri`, which
passes the index alongside the element, and write back through
`a.(i) <-`:

```ocaml
let a = [|10; 20; 30|]
let () = Array.iteri (fun i x -> a.(i) <- x * 2) a
let _ = a   (* = [|20; 40; 60|]: updated in place *)
```

The callback receives each index `i` with its element `x`; the
body stores the doubled value back into the same slot. No new
array is allocated. The loop syntax we are about to see does the
same job with an explicit index.

:::slide

## Iterating arrays: `Array.iter`

```ocaml
let a = [|10; 20; 30|]

let () = Array.iter (fun x -> print_endline (string_of_int x)) a
```

Prints 10, 20, 30 on separate lines.

- `Array.iter` is the **side-effecting walk**.
- The callback returns `unit`; the whole call returns `unit`.

:::

:::slide

## Pure transformation: `Array.map`

```ocaml
let a = [|10; 20; 30|]
let b = Array.map (fun x -> x * 2) a
let _ = b   (* = [|20; 40; 60|] *)
let _ = a   (* = [|10; 20; 30|]: untouched *)
```

- `Array.map` returns a *new* array; the input is untouched.
- Other useful functions: `Array.fold_left`, `Array.length`,
  `Array.to_list`, ...

:::

## OCaml's for and while loops

OCaml has imperative loops, and they live in the language
precisely to go with arrays and mutation. They are not the *only*
way to write iteration, and (as we have insisted all course) they
are not the default; but when you reach for an array, you usually
reach for a loop alongside it.

The two forms:

```text
for i = lo to hi do
  body
done

for i = hi downto lo do
  body
done

while condition do
  body
done
```

`for i = lo to hi do body done` runs `body` once for each `i` from
`lo` to `hi` *inclusive*. The variable `i` is in scope inside the
body. `for i = hi downto lo do body done` is the reverse. `while
condition do body done` runs the body repeatedly while the
condition is true. All three are *expressions* of type `unit`.

The body must itself be of type `unit`. A loop whose body returns
some other type triggers a warning, the same way a sequence does:
the value is being discarded.

## A typical use: counting characters

Here is the kind of code where arrays earn their keep. Suppose
you want to count how many times each character appears in a
string. You make an array of length 256, indexed by character
code, mutate it as you scan the string.

```ocaml
let count_chars s =
  let counts = Array.make 256 0 in
  for i = 0 to String.length s - 1 do
    let c = String.get s i in
    counts.(Char.code c) <- counts.(Char.code c) + 1
  done;
  counts

let _ =
  let c = count_chars "hello" in
  (c.(Char.code 'l'), c.(Char.code 'o'))  (* = (2, 1) *)
```

Two 'l's, one 'o'. The shape of
the algorithm is exactly what an imperative loop in C would do:
walk through the input, indexing by the current character into a
fixed-size table, incrementing the counter.

:::slide

## A typical use: counting

```ocaml
let count_chars s =
  let counts = Array.make 256 0 in
  for i = 0 to String.length s - 1 do
    let c = String.get s i in
    counts.(Char.code c) <- counts.(Char.code c) + 1
  done;
  counts

let c = count_chars "hello"
let _ = c.(Char.code 'l')  (* = 2 *)
let _ = c.(Char.code 'o')  (* = 1 *)
```

- Array **indexed by character code**, mutated in place.
- Same shape as an imperative loop in C.
- Mutation is right here: walk the input, update the counter table.

:::

Could you do this without mutation? Yes: walk the string with a
fold, building up a 256-tuple or a `Map`, returning a new structure
at each step. It would be much slower and much longer to read.
This is exactly the case where mutation is the right tool.

## When you do not want mutation

For most everyday list-shaped work, a [fold](M06-L04-fold.html) or
[map](M06-L02-map.html) is clearer than an array-and-loop.

```ocaml
let sum_lst xs = List.fold_left (+) 0 xs

let sum_arr a =
  let s = ref 0 in
  Array.iter (fun x -> s := !s + x) a;
  !s

let _ = sum_lst [1;2;3;4;5]    (* = 15 *)
let _ = sum_arr [|1;2;3;4;5|]  (* = 15 *)
```

The first version is one line and produces no
intermediate mutable state. The second version is three lines and
needs a `ref`. (You could also write the second with
`Array.fold_left (+) 0 a`, which is again one line.)

:::slide

## When you don't want mutation

For most everyday list-shaped work, a fold or map is clearer than
an array-and-loop:

```ocaml
let sum_lst xs = List.fold_left (+) 0 xs

let sum_arr a =
  let s = ref 0 in
  Array.iter (fun x -> s := !s + x) a;
  !s

let _ = sum_lst [1;2;3;4;5]    (* = 15 *)
let _ = sum_arr [|1;2;3;4;5|]  (* = 15 *)
```

- The fold version is **one line**.
- The array version is **three lines with a `ref`**.
- Reach for arrays only when you actually need the indexed-access
  or fixed-size properties.

:::

The discipline is the same as for `ref`: reach for arrays when
the algorithm wants random-access mutation. If your algorithm is
"walk the data and accumulate a result," a fold is clearer.

## A quick check

:::quiz mcq id=M07-L02-q3
What does the following expression evaluate to?

```ocaml
let a = [|1; 2; 3; 4; 5|] in
a.(2) <- 99;
a.(0) + a.(2) + a.(4)
```

- [ ] `9`
- [x] `105`
- [ ] `108`
- [ ] `Invalid_argument`

**Why:** the assignment changes `a.(2)` from `3` to `99`. The
sum is `1 + 99 + 5 = 105`.
:::

:::quiz mcq id=M07-L02-q2
What is the type of `Array.make 5 0.0`?

- [ ] `int array`
- [x] `float array`
- [ ] `int * float`
- [ ] `float`

**Why:** `Array.make` has type `int -> 'a -> 'a array`. The length
`5` is the first argument; the initial value `0.0` is the second.
The inferred type of `'a` is `float`, so the result is
`float array`.
:::

## Activity

:::slide

## Activity

Write `reverse_in_place : 'a array -> unit` that reverses an array
in place. After calling it, the array's contents are reversed.

:::

:::quiz code id=M07-L02-q1
Write `reverse_in_place` that reverses an array in place.

```ocaml
let reverse_in_place a =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let a = [|1; 2; 3; 4; 5|] in
  reverse_in_place a;
  check (a = [|5; 4; 3; 2; 1|]) "five elements";
  let b = [|1; 2; 3; 4|] in
  reverse_in_place b;
  check (b = [|4; 3; 2; 1|]) "four elements";
  let c = [||] in
  reverse_in_place c;
  check (c = [||]) "empty array";
  let d = [|42|] in
  reverse_in_place d;
  check (d = [|42|]) "singleton";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let reverse_in_place a =
  let n = Array.length a in
  for i = 0 to (n / 2) - 1 do
    let j = n - 1 - i in
    let tmp = a.(i) in
    a.(i) <- a.(j);
    a.(j) <- tmp
  done

let a = [|1; 2; 3; 4; 5|]
let () = reverse_in_place a
let _ = a   (* = [|5; 4; 3; 2; 1|] *)
```

- Returns `unit`; effect is to mutate `a`.
- **Two-pointer reverse:** swap `a.(i)` and `a.(n-1-i)`, halfway.
- `for ... to ... do ... done`: OCaml's imperative loop.

:::

:::

:::slide

## Destructive vs immutable

- The in-place version *loses* the original ordering of `a`.
- Immutable alternative: `Array.of_list (List.rev (Array.to_list a))`.
- Or simpler: keep the data as a list and use `List.rev` directly.

:::

A few things worth noticing in the solution. The loop runs to
`n / 2 - 1` rather than `n - 1`: each iteration swaps two
positions, so we only need to walk halfway through. For an array
of odd length, the middle element is its own mirror and stays in
place. The function returns `unit`; its observable effect is the
mutation. This is the standard signature pattern for in-place
operations: the function returns `unit` and the caller passes in
the structure to be modified.

If you want an immutable reverse instead, the right path is
usually `Array.of_list (List.rev (Array.to_list a))`, or simpler,
keep the data as a list in the first place.

## When the count isn't known: `while`

`for` is the right loop when you know the count of iterations in
advance, as in `reverse_in_place` above. `while` is the loop you
reach for when the iteration stops on a *runtime condition*: the
index where a search succeeds, the iteration where a fixpoint is
reached, the point in an input stream where the structure
changes. A small worked example, linear search:

```ocaml
let find_index p a =
  let n = Array.length a in
  let i = ref 0 in
  while !i < n && not (p a.(!i)) do
    incr i
  done;
  if !i < n then Some !i else None

let _ = find_index (fun x -> x < 0) [|1; 3; -5; 7|]  (* = Some 2 *)
let _ = find_index (fun x -> x < 0) [|1; 3;  5; 7|]  (* = None *)
```

Two things to notice. First, the loop variable
`i` is a `ref`, because the body needs to mutate it. (OCaml's
`for` gives you a fresh immutable binding each iteration; `while`
is where refs and loops fit together.) Second, the loop condition
uses `&&` for short-circuit: when `!i = n`, the second clause
`not (p a.(!i))` is *not evaluated*, so we never index past the
end of the array. Stop conditions like that are exactly what
`while` is for.

The same shape works for any "until found / until stable / until
out of input" pattern: a few refs for the state the loop is
threading, a `while` whose condition is the negation of the
termination criterion, and a final read of the refs to extract
the result.

:::slide

## `while`: when you stop on a condition, not a count

```ocaml
let find_index p a =
  let n = Array.length a in
  let i = ref 0 in
  while !i < n && not (p a.(!i)) do
    incr i
  done;
  if !i < n then Some !i else None

let _ = find_index (fun x -> x < 0) [|1; 3; -5; 7|] (* = Some 2 *)
```

- Loop variable is a **`ref`**: the body increments it.
- Condition uses `&&` short-circuit so we never index past the
  end.
- `for` when the count is known; `while` when it is not.

:::

## Closing: default to immutable

The mutation toolkit (refs, mutable fields, arrays) is in the
language because some algorithms genuinely want it: random-access
table updates, doubly-linked structures, in-place reverses, callbacks
that push state into the world. But everything we have built so far,
all the way through the
[higher-order-functions module](M06-L01-functions-revisited.html),
did without it. There is a reason to keep that as the default.

Immutable data has three concrete payoffs. First, you do not have
to think about [aliasing](M07-L01-references.html#aliasing-two-names-for-one-cell):
two names for the same value behave identically whether they share
a heap object or not, because the heap object cannot change.
Second, the implementation is free to share structure cheaply: a
new list `x :: xs` shares all of `xs` with the original, no copy
needed. Third, immutable data is a perfect fit for *concurrency*:
two threads (or two domains, or two distant cores) can read the
same value at once without locks, because there is nothing to
race over. We will return to that point when we discuss
[data races](M10-L03-data-races-are-ub.html).

The recommendation, then, is the same one OCaml itself follows:
use immutable data structures by default, and reach for mutation
when performance, expressivity, or interop genuinely requires it.
The skill is recognising which of those three things is actually
asking, versus which of them just feels like the imperative habit
from another language.

:::slide

## Default to immutable; mutate when it pays

What you give up when you mutate:

- [Equational reasoning](M01-L02-why-fp.html#equational-reasoning)
  on code that touches the cell.
- "Safe to alias" guarantees: every caller now matters.
- Lock-free concurrent reads: two readers may race.

What you get:

- O(1) random-access updates (arrays, hash tables).
- Doubly-linked / cyclic / shared mutable structures.
- Interop with callback-style code.

Rule of thumb: **immutable until profiled or pinned by the
algorithm**.

:::

## What's next

The [next lecture](M07-L03-exceptions.html) covers *exceptions*,
the third member of the imperative trio (alongside refs and arrays).
Exceptions let you signal "something went wrong" without threading
an [option or result](M04-L04-recursive-types.html) through every
layer of code. After that,
Lectures [4](M07-L04-streams-and-laziness.html) and
[5](M07-L05-memoization.html) cover *streams and laziness* and
*memoization* (a pair of techniques that build on refs and
exceptions). Lectures [6](M07-L06-module-basics.html) through
[8](M07-L08-functors.html) then turn to *modules* and the way
OCaml organizes code at scale.

:::slide

## What's next

Lecture 3: **exceptions**.

- The other major form of "side effect" in OCaml.
- They let you signal "something went wrong" without threading an
  option / result through every layer of code.

:::

## Reading

- **Cornell CS3110**, *Arrays*:
  <https://cs3110.github.io/textbook/chapters/mut/arrays.html>
- **Cornell CS3110**, *Mutable fields*:
  <https://cs3110.github.io/textbook/chapters/mut/mutable_fields.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
