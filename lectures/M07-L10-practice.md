---
title: "Practice: mutability, modules, and streams"
lecture_no: 10
week: 7
duration_target_min: 0
concepts: [practice problems, references, mutable records, arrays, modules, functors, streams]
keywords: [OCaml, practice, assignment, ref, mutable, array, module, functor, stream]
think_about_this: "These problems mix the three threads of this module: in-place mutation, packaging code behind signatures and functors, and infinite data built lazily. The module/functor problems are the hard ones; budget most of your time there."
reading:
  - title: "OCaml manual, The module system"
    url: https://v2.ocaml.org/manual/moduleexamples.html
---

# Practice: mutability, modules, and streams

This is a *Practice* chapter, not a Tutorial. There are no slides
and there is no video; it is a worksheet. The
[Tutorial](M07-L09-tutorial.html) walked through a queue functor
on screen. Here you solve the problems yourself, directly in the
browser. Each problem has an editable cell seeded with
`failwith "not implemented"` (or a stub module) and a test cell
that prints `all tests passed` when your solution is correct. A
reference solution sits below each problem behind a collapsed
*Reference solution* panel: try the problem first, then reveal the
solution to compare.

The worksheet has three parts, one per thread of the module:

- **Part 1: mutability** (Problems 1 to 7). References, mutable
  record fields, and in-place array update, from the
  [references lecture](M07-L01-references.html) and
  [arrays lecture](M07-L02-arrays-and-mutation.html).
- **Part 2: modules and functors** (Problems 8 to 13). Packaging
  code behind a [signature](M07-L07-signatures.html), and writing
  [functors](M07-L08-functors.html) that build modules from
  modules. Several problems tie Parts 1 and 2 together: functors
  whose result type is *mutable*.
- **Part 3: streams** (Problems 14 to 19). Infinite data built
  from thunks, from the
  [streams lecture](M07-L04-streams-and-laziness.html).

Difficulty rises roughly as you go. The functor problems in Part 2
are the meatiest; if you get stuck, skip ahead to the streams and
come back.

## Part 1: mutability

## Problem 1: `sum_ref`

Write a function

```text
sum_ref : int list -> int
```

that sums a list using a single mutable accumulator and
[`List.iter`](https://v2.ocaml.org/api/List.html#VALiter), *not*
recursion and *not* `List.fold_left`. The point is to practise the
ref idiom: allocate a cell, mutate it in a loop, read it out at the
end.

:::quiz code id=M07-L10-q1
Implement `sum_ref` with a `ref` and `List.iter`.

```ocaml
let sum_ref xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sum_ref [1; 2; 3; 4] = 10) "small";
  check (sum_ref [] = 0) "empty";
  check (sum_ref [5] = 5) "singleton";
  check (sum_ref [-1; 1; -1; 1] = 0) "cancels";
  check (sum_ref (List.init 100 (fun i -> i + 1)) = 5050) "1..100";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let sum_ref xs =
  let acc = ref 0 in
  List.iter (fun x -> acc := !acc + x) xs;
  !acc
```

Allocate `acc` once, mutate it with `:=` for each element, and
dereference with `!` at the end. This is the imperative shape of a
fold: the accumulator lives in a cell rather than being threaded
through recursive calls.

:::

## Problem 2: `rotate_left`

Write a function

```text
rotate_left : 'a array -> unit
```

that rotates an array one position to the left, *in place*: the
element at index 0 moves to the end, everything else shifts down
one. For example, `[|1; 2; 3; 4|]` becomes `[|2; 3; 4; 1|]`. Arrays
of length 0 or 1 are unchanged. The function returns `unit`; its
effect is the mutation.

:::quiz code id=M07-L10-q2
Implement `rotate_left`.

```ocaml
let rotate_left a =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let a = [|1; 2; 3; 4|] in
  rotate_left a;
  check (a = [|2; 3; 4; 1|]) "four elements";
  let b = [|7|] in
  rotate_left b;
  check (b = [|7|]) "singleton unchanged";
  let c = [||] in
  rotate_left c;
  check (c = [||]) "empty unchanged";
  let d = [|1; 2|] in
  rotate_left d;
  check (d = [|2; 1|]) "pair";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let rotate_left a =
  let n = Array.length a in
  if n > 1 then begin
    let first = a.(0) in
    for i = 0 to n - 2 do
      a.(i) <- a.(i + 1)
    done;
    a.(n - 1) <- first
  end
```

Save the first element, shift every later element down one with a
`for` loop and `a.(i) <- ...`, then drop the saved element into the
last slot. The `n > 1` guard skips the work for empty and
singleton arrays (where rotation is a no-op). This is the kind of
index-juggling in-place mutation that arrays are *for*.

:::

## Problem 3: a mutable bank account

Using the record type

```text
type account = { mutable balance : int }
```

write two functions:

```text
deposit  : account -> int -> unit
withdraw : account -> int -> bool
```

`deposit acc n` adds `n` to the balance. `withdraw acc n` subtracts
`n` *only if* the account has at least `n`; it returns `true` if the
withdrawal happened and `false` (leaving the balance untouched) if
there were insufficient funds.

:::quiz code id=M07-L10-q3
Implement `deposit` and `withdraw`.

```ocaml
type account = { mutable balance : int }

let deposit acc n =
  failwith "not implemented"

let withdraw acc n =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let a = { balance = 0 } in
  deposit a 100;
  check (a.balance = 100) "deposit";
  check (withdraw a 30 = true) "withdraw ok returns true";
  check (a.balance = 70) "balance after withdraw";
  check (withdraw a 1000 = false) "overdraw returns false";
  check (a.balance = 70) "balance unchanged on overdraw";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let deposit acc n = acc.balance <- acc.balance + n

let withdraw acc n =
  if n <= acc.balance then begin
    acc.balance <- acc.balance - n;
    true
  end else
    false
```

`deposit` is a one-line field update with `<-`. `withdraw` guards
the update on sufficient funds: when the guard holds it mutates and
returns `true`; otherwise it leaves the field alone and returns
`false`. Returning a `bool` lets the caller tell whether the
withdrawal succeeded, which a `unit`-returning version could not.

:::

## Problem 4: `gensym`

Write a *fresh-name generator*

```text
gensym : unit -> string
```

so that successive calls return `"x0"`, `"x1"`, `"x2"`, and so on:
each call produces a name that has never been produced before. This
is the trick a compiler uses to invent temporary variable names.
The counter must be *private*: a caller can call `gensym` but cannot
see or reset the count.

:::quiz code id=M07-L10-q4
Implement `gensym`. Capture a `ref` counter in a closure (the
private-state-in-a-closure pattern from the
[references lecture](M07-L01-references.html)).

```ocaml
let gensym = fun () ->
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let a = gensym () in
  let b = gensym () in
  let c = gensym () in
  check (a = "x0") "first";
  check (b = "x1") "second";
  check (c = "x2") "third";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let gensym =
  let counter = ref 0 in
  fun () ->
    let n = !counter in
    incr counter;
    "x" ^ string_of_int n
```

`gensym` is a *value*, not a function-with-arguments: evaluating
`let gensym = let counter = ref 0 in fun () -> ...` allocates the
counter cell *once* and returns a closure over it. Every call
reads the current count, bumps the cell, and formats the name. The
counter is unreachable from outside the closure, so it cannot be
tampered with. (Note the test binds the three results with `let`
before comparing: OCaml does not promise left-to-right evaluation
inside a single list or tuple, so forcing the order matters when
the calls have a side effect.)

:::

## Problem 5: `prefix_sums_in_place`

Write a function

```text
prefix_sums_in_place : int array -> unit
```

that replaces each element with the sum of all elements up to and
including it, *in place*, in a single left-to-right pass. For
example, `[|1; 2; 3; 4|]` becomes `[|1; 3; 6; 10|]`. The empty array
and singleton arrays are unchanged.

:::quiz code id=M07-L10-q5
Implement `prefix_sums_in_place`.

```ocaml
let prefix_sums_in_place a =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let a = [|1; 2; 3; 4|] in
  prefix_sums_in_place a;
  check (a = [|1; 3; 6; 10|]) "1 2 3 4";
  let b = [||] in
  prefix_sums_in_place b;
  check (b = [||]) "empty";
  let c = [|5|] in
  prefix_sums_in_place c;
  check (c = [|5|]) "singleton";
  let d = [|1; 1; 1; 1|] in
  prefix_sums_in_place d;
  check (d = [|1; 2; 3; 4|]) "ones";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prefix_sums_in_place a =
  for i = 1 to Array.length a - 1 do
    a.(i) <- a.(i) + a.(i - 1)
  done
```

Starting at index 1, add the (already-updated) previous cell into
the current one. Because we sweep left-to-right, by the time we
reach index `i` the cell at `i - 1` already holds the prefix sum up
to `i - 1`, so one addition extends it. Index 0 is already its own
prefix sum, so the loop starts at 1; empty and singleton arrays do
zero iterations.

:::

## Problem 6: a growable array

A fixed-size array cannot grow. A *growable* array (OCaml's
`Buffer` for ints, or Java's `ArrayList`, or Rust's `Vec`) wraps a
backing array plus a length, and *doubles* the backing array when
it fills up. Using the record type

```text
type t = { mutable data : int array; mutable len : int }
```

implement:

```text
create : unit -> t
length : t -> int
get    : t -> int -> int
push   : t -> int -> unit
```

`create ()` starts empty (with some small backing capacity).
`push t x` appends `x`, growing the backing array if it is full.
`get t i` returns the `i`th pushed element; `length t` the number
of elements pushed.

:::quiz code id=M07-L10-q6
Implement the growable array. Grow by allocating a new array of
double the capacity and copying the elements over.

```ocaml
type t = { mutable data : int array; mutable len : int }

let create () =
  failwith "not implemented"

let length t =
  failwith "not implemented"

let get t i =
  failwith "not implemented"

let push t x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let t = create () in
  check (length t = 0) "starts empty";
  for i = 1 to 10 do push t i done;
  check (length t = 10) "ten pushed";
  check (get t 0 = 1) "first";
  check (get t 9 = 10) "last";
  check (Array.length t.data >= 10) "backing array grew";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type t = { mutable data : int array; mutable len : int }

let create () = { data = Array.make 4 0; len = 0 }
let length t = t.len
let get t i = t.data.(i)

let push t x =
  if t.len >= Array.length t.data then begin
    let bigger = Array.make (2 * Array.length t.data) 0 in
    for i = 0 to t.len - 1 do
      bigger.(i) <- t.data.(i)
    done;
    t.data <- bigger
  end;
  t.data.(t.len) <- x;
  t.len <- t.len + 1
```

`create` allocates a small backing array (`0` is a filler for the
unused slots) and a length of 0. `push` first checks whether the
backing array is full; if so it allocates one twice as large,
copies the live elements over, and swaps it in by mutating
`t.data`. Then it writes the new element at index `t.len` and bumps
`t.len`. Amortised over many pushes, the doubling makes each push
O(1) on average even though an individual grow is O(n). `length`
and `get` read the record and the backing array. The capacity
(`Array.length t.data`) and the logical length (`t.len`) are
deliberately different numbers: that gap is the whole point of a
growable array.

:::

## Problem 7: a sliding-window maximum

Implement a fixed-size *window* that remembers the last `k` values
pushed into it and can report their maximum. Using

```text
type window = { buf : int array; mutable count : int; size : int }
```

implement:

```text
make_window : int -> window
add         : window -> int -> unit
current_max : window -> int
```

`make_window k` makes a window of capacity `k`. `add w x` records
`x` (overwriting the oldest value once more than `k` have been
added). `current_max w` returns the largest of the values currently
in the window (the last `min count k` added).

:::quiz code id=M07-L10-q7
Implement the window with a *ring buffer*: an array of size `k`
indexed by `count mod k`, so the oldest value is overwritten
automatically.

```ocaml
type window = { buf : int array; mutable count : int; size : int }

let make_window k =
  failwith "not implemented"

let add w x =
  failwith "not implemented"

let current_max w =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let w = make_window 3 in
  add w 1;
  check (current_max w = 1) "after 1";
  add w 3;
  add w 2;
  check (current_max w = 3) "window 1,3,2";
  add w 5;
  check (current_max w = 5) "window 3,2,5";
  add w 0;
  add w 0;
  check (current_max w = 5) "window 5,0,0";
  add w 1;
  check (current_max w = 1) "window 0,0,1";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
type window = { buf : int array; mutable count : int; size : int }

let make_window k = { buf = Array.make k min_int; count = 0; size = k }

let add w x =
  w.buf.(w.count mod w.size) <- x;
  w.count <- w.count + 1

let current_max w =
  let n = min w.count w.size in
  let m = ref min_int in
  for i = 0 to n - 1 do
    if w.buf.(i) > !m then m := w.buf.(i)
  done;
  !m
```

The ring buffer stores values at index `count mod size`, so once
the window is full each new value overwrites the oldest. After the
window fills, all `size` slots hold exactly the last `size` values
(in some rotated order, which does not matter for a maximum).
`current_max` scans the `min count size` live slots with a mutable
running maximum. `min_int` is the identity for `max`, used both as
the filler and the seed. This is the imperative dual of folding
`max` over a list, with the list living in a fixed-size array.

:::

## Part 2: modules and functors

These problems are the heart of the worksheet. The signatures and
the functor problems (`Showable`, the doubly-linked-list node and
list, the functional heap) are drawn from the *CS3100*
mutability-and-modules and monads assignments; the set and
dictionary functors are the classic `Set.Make` / `Map.Make` shape.

## Problem 8: `Showable` modules

Given the signature

```text
module type Showable = sig
  type t
  val string_of_t : t -> string
end
```

implement two modules, `IntShowable` and `FloatShowable`, that
satisfy it. Use the standard library's `string_of_int` and
`string_of_float` for the `string_of_t` functions.

:::quiz code id=M07-L10-q8
Implement `IntShowable` and `FloatShowable`.

```ocaml
module type Showable = sig
  type t
  val string_of_t : t -> string
end

(* Implement IntShowable and FloatShowable below. *)
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (IntShowable.string_of_t 10 = "10") "int 10";
  check (IntShowable.string_of_t (-3) = "-3") "int -3";
  check (FloatShowable.string_of_t 0.0 = "0.") "float 0.0";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module IntShowable : Showable with type t = int = struct
  type t = int
  let string_of_t = string_of_int
end

module FloatShowable : Showable with type t = float = struct
  type t = float
  let string_of_t = string_of_float
end
```

Each module fixes `t` to a concrete type and supplies the printer.
The `with type t = int` in the ascription is the key detail: a bare
`: Showable` would make `t` *abstract*, so the test
`IntShowable.string_of_t 10` would not type-check (10 is an `int`,
not the opaque `IntShowable.t`). The `with type` constraint exposes
the equation `t = int` to the outside while still checking the
module against the signature.

:::

## Problem 9: a doubly-linked-list node functor

This problem combines Part 1 (mutable fields) with Part 2 (functors).
A doubly-linked-list *node* holds a value and mutable links to its
neighbours. Implement the functor

```text
module MakeNode : functor (C : Showable) -> NODE with type content = C.t
```

for the signature

```text
module type NODE = sig
  type t
  type content
  val create        : content -> t
  val get_content   : t -> content
  val get_next      : t -> t option
  val get_prev      : t -> t option
  val set_next      : t -> t option -> unit
  val set_prev      : t -> t option -> unit
end
```

`create c` makes a fresh node holding `c` with no neighbours. The
`get_*` accessors read the fields; the `set_*` operations mutate the
`next` / `prev` links in place. The neighbours are `t option` so a
node at either end can record "no neighbour."

:::quiz code id=M07-L10-q9
Implement the functor `MakeNode`.

```ocaml
module type Showable = sig
  type t
  val string_of_t : t -> string
end

module IntShowable : Showable with type t = int = struct
  type t = int
  let string_of_t = string_of_int
end

module type NODE = sig
  type t
  type content
  val create      : content -> t
  val get_content : t -> content
  val get_next    : t -> t option
  val get_prev    : t -> t option
  val set_next    : t -> t option -> unit
  val set_prev    : t -> t option -> unit
end

(* Define the MakeNode functor here. Its result must satisfy NODE and
   expose the equation content = C.t so the tests can pass ints to it. *)
```

```ocaml skip
let check b m = if not b then failwith m
module IntNode = MakeNode (IntShowable)
let () =
  let open IntNode in
  let a = create 1 and b = create 2 and c = create 3 in
  check (get_content a = 1) "content";
  check (get_next a = None) "fresh node has no next";
  set_next a (Some b); set_prev b (Some a);
  set_next b (Some c); set_prev c (Some b);
  check (match get_next a with Some n -> get_content n = 2 | None -> false)
        "a -> b";
  check (match get_prev c with Some n -> get_content n = 2 | None -> false)
        "c <- b";
  set_next a (Some c);
  check (match get_next a with Some n -> get_content n = 3 | None -> false)
        "relink a -> c";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module MakeNode (C : Showable) : NODE with type content = C.t = struct
  type content = C.t
  type t = {
    value : content;
    mutable next : t option;
    mutable prev : t option;
  }
  let create v = { value = v; next = None; prev = None }
  let get_content n = n.value
  let get_next n = n.next
  let get_prev n = n.prev
  let set_next n m = n.next <- m
  let set_prev n m = n.prev <- m
end
```

The node is a record with one immutable field (`value`) and two
`mutable` fields (`next`, `prev`), exactly the doubly-linked-list
node from the [arrays lecture](M07-L02-arrays-and-mutation.html), now packaged
inside a functor. The functor is parameterised by `C : Showable`,
so `content` is `C.t`; the `with type content = C.t` ascription
exposes that equation so the test can call `create 1` with a plain
`int`. The `set_*` operations are field assignments (`<-`) returning
`unit`. Note the type `t` is recursive: a node's neighbours are
themselves nodes.

:::

## Problem 10: a doubly-linked-list functor

Build the list itself *on top of* the node from Problem 9: a functor

```text
module MakeList : functor (N : NODE) -> DLL with type content = N.content
```

for the signature

```text
module type DLL = sig
  type t
  type content
  val create       : unit -> t
  val is_empty     : t -> bool
  val insert_first : t -> content -> unit
  val to_list      : t -> content list
end
```

A list holds a mutable reference to its head node. `create ()` makes
an empty list. `insert_first l c` makes a new node for `c`, links it
in front of the current head (updating the old head's `prev`), and
makes it the new head. `to_list l` walks the chain via `get_next`
and returns the contents head-to-tail. (The starter cell already
provides a working `MakeNode` for you to build on.)

:::quiz code id=M07-L10-q10
Implement the functor `MakeList`.

```ocaml
module type Showable = sig
  type t
  val string_of_t : t -> string
end
module IntShowable : Showable with type t = int = struct
  type t = int
  let string_of_t = string_of_int
end
module type NODE = sig
  type t
  type content
  val create      : content -> t
  val get_content : t -> content
  val get_next    : t -> t option
  val get_prev    : t -> t option
  val set_next    : t -> t option -> unit
  val set_prev    : t -> t option -> unit
end
(* A working node functor (the Problem 9 answer) is provided. *)
module MakeNode (C : Showable) : NODE with type content = C.t = struct
  type content = C.t
  type t = { value : content; mutable next : t option; mutable prev : t option }
  let create v = { value = v; next = None; prev = None }
  let get_content n = n.value
  let get_next n = n.next
  let get_prev n = n.prev
  let set_next n m = n.next <- m
  let set_prev n m = n.prev <- m
end
module IntNode = MakeNode (IntShowable)

module type DLL = sig
  type t
  type content
  val create       : unit -> t
  val is_empty     : t -> bool
  val insert_first : t -> content -> unit
  val to_list      : t -> content list
end

module MakeList (N : NODE) : DLL with type content = N.content = struct
  (* Implement the list here. *)
  type content = N.content
  type t = unit  (* replace this *)
  let create () = failwith "not implemented"
  let is_empty _ = failwith "not implemented"
  let insert_first _ _ = failwith "not implemented"
  let to_list _ = failwith "not implemented"
end
```

```ocaml skip
let check b m = if not b then failwith m
module IntList = MakeList (IntNode)
let () =
  let open IntList in
  let l = create () in
  check (is_empty l) "create is empty";
  insert_first l 1;
  insert_first l 2;
  insert_first l 3;
  check (not (is_empty l)) "not empty after inserts";
  check (to_list l = [3; 2; 1]) "insert_first prepends";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module MakeList (N : NODE) : DLL with type content = N.content = struct
  type content = N.content
  type t = { mutable head : N.t option }
  let create () = { head = None }
  let is_empty l = l.head = None
  let insert_first l c =
    let n = N.create c in
    (match l.head with
     | None -> ()
     | Some h -> N.set_next n (Some h); N.set_prev h (Some n));
    l.head <- Some n
  let to_list l =
    let rec go = function
      | None -> []
      | Some n -> N.get_content n :: go (N.get_next n)
    in
    go l.head
end
```

The list is a record with a single `mutable head` field. The
functor only ever touches nodes through `N`'s operations, so it
works for *any* node module: it is a functor over a functor's
output. `insert_first` allocates a node, and if the list was
non-empty wires the two-way link between the new node and the old
head before repointing `head`. `to_list` walks `get_next` from the
head. Note `is_empty` compares `l.head = None`: that is safe even
though nodes are cyclic (a node's `prev`/`next` can point back at
it), because `Some _ = None` is decided by the constructors without
ever descending into the node.

:::

## Problem 11: set algebra over an ordering

The [functors lecture](M07-L08-functors.html) built a
`Set.Make`-style functor whose output could only answer
*membership* questions: `empty`, `add`, `mem`. A real set module
also provides the set *algebra*: intersection, difference,
subset. Extend the same sorted-list design with those. Given

```text
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end
```

implement

```text
module MakeSet : functor (O : ORDERED) -> SET with type elt = O.t
```

for

```text
module type SET = sig
  type elt
  type t
  val empty   : t
  val add     : elt -> t -> t
  val mem     : elt -> t -> bool
  val inter   : t -> t -> t      (* elements in both *)
  val diff    : t -> t -> t      (* in the first, not the second *)
  val subset  : t -> t -> bool   (* first contained in second? *)
  val to_list : t -> elt list    (* ascending, no duplicates *)
end
```

The representation is a *sorted list with no duplicates*, and the
starter already implements the membership part (`empty`, `add`,
`mem`, `to_list`). Your job is `inter`, `diff`, and `subset`.
*Both* arguments satisfy the sorted invariant, so each operation
can be a single synchronized walk down the two lists, comparing
heads and advancing the smaller side (the merge pattern), rather
than a nested loop that calls `mem` once per element.

:::quiz code id=M07-L10-q11
Implement `inter`, `diff`, and `subset` in the functor `MakeSet`.

```ocaml
module type ORDERED = sig
  type t
  val compare : t -> t -> int
end

module type SET = sig
  type elt
  type t
  val empty   : t
  val add     : elt -> t -> t
  val mem     : elt -> t -> bool
  val inter   : t -> t -> t
  val diff    : t -> t -> t
  val subset  : t -> t -> bool
  val to_list : t -> elt list
end

module MakeSet (O : ORDERED) : SET with type elt = O.t = struct
  type elt = O.t
  type t = elt list  (* sorted ascending, no duplicates *)

  let empty = []

  let rec mem x = function
    | [] -> false
    | y :: ys ->
        let c = O.compare x y in
        if c = 0 then true
        else if c < 0 then false
        else mem x ys

  let rec add x = function
    | [] -> [x]
    | (y :: ys) as l ->
        let c = O.compare x y in
        if c = 0 then l
        else if c < 0 then x :: l
        else y :: add x ys

  let to_list s = s

  (* Implement these with a synchronized walk on both lists. *)
  let inter _ _ = failwith "not implemented"
  let diff _ _ = failwith "not implemented"
  let subset _ _ = failwith "not implemented"
end
```

```ocaml skip
let check b m = if not b then failwith m
module IntOrd = struct type t = int let compare = Stdlib.compare end
module IntSet = MakeSet (IntOrd)
let () =
  let open IntSet in
  let of_list xs = List.fold_left (fun s x -> add x s) empty xs in
  let evens = of_list [2; 4; 6] in
  let small = of_list [5; 3; 1; 4; 2] in
  check (to_list (inter small evens) = [2; 4]) "inter";
  check (to_list (inter small empty) = []) "inter empty";
  check (to_list (diff small evens) = [1; 3; 5]) "diff";
  check (to_list (diff evens small) = [6]) "diff, other order";
  check (subset (of_list [4; 2]) evens) "subset holds";
  check (not (subset evens small)) "subset fails";
  check (subset empty small) "empty is a subset";
  print_endline "ordinary-order tests passed"

(* Reversing the supplied ordering catches implementations that use
   polymorphic < or <= instead of O.compare. *)
module RevIntOrd = struct
  type t = int
  let compare a b = Stdlib.compare b a
end
module RevIntSet = MakeSet (RevIntOrd)
let () =
  let open RevIntSet in
  let of_list xs = List.fold_left (fun s x -> add x s) empty xs in
  let a = of_list [1; 2; 4] and b = of_list [2; 3; 4] in
  check (to_list a = [4; 2; 1]) "respects reverse ordering";
  check (to_list (inter a b) = [4; 2]) "reverse-order inter";
  check (to_list (diff a b) = [1]) "reverse-order diff";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module MakeSet (O : ORDERED) : SET with type elt = O.t = struct
  type elt = O.t
  type t = elt list  (* sorted ascending, no duplicates *)

  let empty = []

  let rec mem x = function
    | [] -> false
    | y :: ys ->
        let c = O.compare x y in
        if c = 0 then true
        else if c < 0 then false
        else mem x ys

  let rec add x = function
    | [] -> [x]
    | (y :: ys) as l ->
        let c = O.compare x y in
        if c = 0 then l
        else if c < 0 then x :: l
        else y :: add x ys

  let to_list s = s

  let rec inter s1 s2 = match s1, s2 with
    | [], _ | _, [] -> []
    | x :: xs, y :: ys ->
        let c = O.compare x y in
        if c = 0 then x :: inter xs ys
        else if c < 0 then inter xs s2   (* x not in s2; drop it *)
        else inter s1 ys                 (* y not in s1; drop it *)

  let rec diff s1 s2 = match s1, s2 with
    | [], _ -> []
    | _, [] -> s1
    | x :: xs, y :: ys ->
        let c = O.compare x y in
        if c = 0 then diff xs ys         (* x is in s2; drop it *)
        else if c < 0 then x :: diff xs s2
        else diff s1 ys

  let rec subset s1 s2 = match s1, s2 with
    | [], _ -> true
    | _, [] -> false
    | x :: xs, y :: ys ->
        let c = O.compare x y in
        if c = 0 then subset xs ys
        else if c < 0 then false         (* x can't appear in s2 *)
        else subset s1 ys
end
```

All three walk the two lists in lockstep. At each step, compare
the heads: equal heads mean a shared element (keep it for
`inter`, drop it for `diff`, keep checking for `subset`); a
smaller head on one side cannot appear on the other side at all,
because both lists are sorted. Each operation is therefore
O(|s1| + |s2|), the same shape as the merge step of merge sort.
The naive alternative, calling `mem` on `s2` once per element of
`s1`, is O(|s1| * |s2|): the sorted invariant is what buys the
speedup. `subset` can answer `false` the moment an element of
`s1` proves smaller than every remaining element of `s2`.

:::

## Problem 12: a dictionary functor over a key

A companion to the set: a small `Map.Make`-style dictionary,
parameterised by a key module that knows how to test keys for
equality. Given

```text
module type KEY = sig
  type t
  val equal : t -> t -> bool
end
```

implement

```text
module MakeDict : functor (K : KEY) -> DICT with type key = K.t
```

for

```text
module type DICT = sig
  type key
  type 'v t
  val empty  : 'v t
  val add    : key -> 'v -> 'v t -> 'v t
  val find   : key -> 'v t -> 'v option
  val remove : key -> 'v t -> 'v t
end
```

`add k v d` returns a dictionary mapping `k` to `v` and agreeing
with `d` elsewhere (a later `add` on the same key wins). `find`
returns `Some v` or `None`; `remove` drops a key. Note the value
type `'v` stays polymorphic: only the key type is fixed by the
functor.

:::quiz code id=M07-L10-q12
Implement the functor `MakeDict`.

```ocaml
module type KEY = sig
  type t
  val equal : t -> t -> bool
end

module type DICT = sig
  type key
  type 'v t
  val empty  : 'v t
  val add    : key -> 'v -> 'v t -> 'v t
  val find   : key -> 'v t -> 'v option
  val remove : key -> 'v t -> 'v t
end

module MakeDict (K : KEY) : DICT with type key = K.t = struct
  (* Implement the dictionary here. *)
  type key = K.t
  type 'v t = (key * 'v) list
  let empty = []
  let add _ _ _ = failwith "not implemented"
  let find _ _ = failwith "not implemented"
  let remove _ _ = failwith "not implemented"
end
```

```ocaml skip
let check b m = if not b then failwith m
module StrKey = struct type t = string let equal = String.equal end
module StrDict = MakeDict (StrKey)
let () =
  let open StrDict in
  let d = add "a" 3 (add "b" 2 (add "a" 1 empty)) in
  check (find "a" d = Some 3) "latest add wins";
  check (find "b" d = Some 2) "other key";
  check (find "c" d = None) "missing key";
  check (find "a" (remove "a" d) = None) "after remove";
  print_endline "string-key tests passed"

(* Equality need not be OCaml's (=). This also checks that adding an
   equivalent key replaces the old binding instead of retaining a
   duplicate that can reappear after remove. *)
module CiKey = struct
  type t = string
  let equal a b =
    String.equal (String.lowercase_ascii a) (String.lowercase_ascii b)
end
module CiDict = MakeDict (CiKey)
let () =
  let open CiDict in
  let d = add "a" 1 empty |> add "A" 2 in
  check (find "a" d = Some 2) "equivalent key replaced";
  check (find "A" (remove "a" d) = None) "remove leaves no duplicate";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module MakeDict (K : KEY) : DICT with type key = K.t = struct
  type key = K.t
  type 'v t = (key * 'v) list

  let empty = []

  let remove k d = List.filter (fun (k', _) -> not (K.equal k k')) d
  let add k v d = (k, v) :: remove k d

  let rec find k = function
    | [] -> None
    | (k', v) :: rest -> if K.equal k k' then Some v else find k rest
end
```

The dictionary is an association list with no duplicate keys.
`remove` filters out any pair with a matching key; `add` removes
the old binding (if any) and conses the new one on the front, so
the invariant "at most one pair per key" holds and the latest `add`
wins. `find` walks until it hits the key. The value type `'v` is a
parameter on `t`, so one `MakeDict(StrKey)` serves string-keyed
dictionaries of *any* value type. (`Map.Make` does the same with a
balanced tree instead of a list, for O(log n) operations.)

:::

## Problem 13: a functional heap

Not every "store" needs mutation. A *functional heap* is an
immutable key-value map that returns a *new* map on every update,
representing the store as a plain value. Implement the module
`FHeap` satisfying

```text
module type FHEAP = sig
  type ('k, 'v) t
  val empty : ('k, 'v) t
  val set   : ('k, 'v) t -> 'k -> 'v -> ('k, 'v) t
  val get   : ('k, 'v) t -> 'k -> 'v option
end
```

`empty` is the heap with no bindings. `set h k v` returns a heap
that maps `k` to `v` and agrees with `h` everywhere else. `get h k`
returns `Some v` if `k` is bound, `None` otherwise. A later `set`
on a key shadows an earlier one.

:::quiz code id=M07-L10-q13
Implement `FHeap`. (An association list is the simplest backing
store; you may use `List.assoc_opt`.)

```ocaml
module type FHEAP = sig
  type ('k, 'v) t
  val empty : ('k, 'v) t
  val set   : ('k, 'v) t -> 'k -> 'v -> ('k, 'v) t
  val get   : ('k, 'v) t -> 'k -> 'v option
end

module FHeap : FHEAP = struct
  (* Replace these stub bodies with a real implementation. *)
  type ('k, 'v) t = ('k * 'v) list
  let empty = []
  let set _h _k _v = []
  let get _h _k = None
end
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let open FHeap in
  check (get empty 0 = None) "empty has nothing";
  let h = set (set empty 0 "a") 1 "b" in
  check (get h 0 = Some "a") "key 0";
  check (get h 1 = Some "b") "key 1";
  check (get h 9 = None) "missing key";
  let h2 = set h 1 "c" in
  check (get h2 1 = Some "c") "shadowed key";
  check (get h 1 = Some "b") "original heap unchanged";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
module FHeap : FHEAP = struct
  type ('k, 'v) t = ('k * 'v) list
  let empty = []
  let set h k v = (k, v) :: h
  let get h k = List.assoc_opt k h
end
```

The heap is an association list. `set` conses a new pair onto the
front (it does *not* remove the old binding); `get` uses
`List.assoc_opt`, which returns the *first* match, so the most
recent `set` wins. Because `set` builds a new list and never
mutates, the old heap keeps its bindings: the test's
"original heap unchanged" check passes. The representation type
`('k, 'v) t` is abstract behind the signature, so callers cannot
depend on it being a list. (CS3100's version uses a function
`'k -> 'v option` as the store instead; either works.)

:::

## Part 3: streams

These problems use the thunk-based stream type from the
[streams lecture](M07-L04-streams-and-laziness.html). Each problem's cell
seeds the type and the helpers it needs (`hd`, `tl`, `take`, and
sometimes `from` / `map_s`); you write the new function.

## Problem 14: `interleave`

Write a function

```text
interleave : 'a stream -> 'a stream -> 'a stream
```

that alternates between two streams: the first element of `s1`,
then the first of `s2`, then the second of `s1`, and so on. For
example, interleaving `0, 1, 2, ...` with `100, 101, 102, ...`
gives `0, 100, 1, 101, 2, 102, ...`.

:::quiz code id=M07-L10-q14
Implement `interleave`.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)
let rec from n = Cons (n, fun () -> from (n + 1))

let rec interleave s1 s2 =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 6 (interleave (from 0) (from 100))
         = [0; 100; 1; 101; 2; 102]) "two counters";
  check (take 4 (interleave (from 0) (from 0)) = [0; 0; 1; 1])
        "same stream twice";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let rec interleave s1 s2 =
  Cons (hd s1, fun () -> interleave s2 (tl s1))
```

Emit the head of `s1` now, and defer the rest: the tail thunk
interleaves `s2` with the *tail* of `s1`, with the two streams
*swapped*. Swapping the arguments on each step is what makes the
output alternate. Because the tail is a thunk, only as much of each
stream as `take` demands is ever forced.

:::

## Problem 15: `cycle`

Write a function

```text
cycle : 'a list -> 'a stream
```

that turns a non-empty list into the infinite stream that repeats
it forever. For example, `cycle [1; 2; 3]` is the stream
`1, 2, 3, 1, 2, 3, 1, ...`. On the empty list, raise
`Invalid_argument` (there is nothing to cycle).

:::quiz code id=M07-L10-q15
Implement `cycle`.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)

let cycle lst =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 7 (cycle [1; 2; 3]) = [1; 2; 3; 1; 2; 3; 1])
        "three-cycle";
  check (take 4 (cycle [9]) = [9; 9; 9; 9]) "singleton cycle";
  check ((try let _ = cycle [] in false with Invalid_argument _ -> true))
        "empty raises";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let cycle lst =
  if lst = [] then invalid_arg "cycle: empty list";
  let rec go = function
    | [] -> go lst
    | x :: xs -> Cons (x, fun () -> go xs)
  in
  go lst
```

The inner `go` walks the list, emitting one element per stream
node; when it runs off the end (`[]`) it starts over from the
original `lst`. The restart sits inside the tail thunk, so the
stream is genuinely infinite but uses finite memory: there is one
`go lst` closure, re-entered each time round. The empty-list guard
runs *before* building any stream, so `cycle []` fails immediately
rather than diverging.

:::

## Problem 16: merge, and the Hamming numbers

Write a function

```text
merge : int stream -> int stream -> int stream
```

that merges two *sorted, strictly increasing* streams into one
sorted stream, *dropping duplicates* (a value in both streams
appears once). With `merge` in hand, a famous stream falls out: the
**Hamming numbers** (or 5-smooth numbers), the increasing sequence
of positive integers whose only prime factors are 2, 3, and 5:
`1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 16, ...`. The test below builds
that stream as

```text
let rec hamming =
  Cons (1, fun () ->
    merge (map_s (fun x -> x * 2) hamming)
      (merge (map_s (fun x -> x * 3) hamming)
         (map_s (fun x -> x * 5) hamming)))
```

a stream defined in terms of itself: every Hamming number times 2,
3, or 5 is another Hamming number, merged back together.

:::quiz code id=M07-L10-q16
Implement `merge` (deduplicating). The test wires it into the
self-referential `hamming` stream.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)
let rec map_s f s = Cons (f (hd s), fun () -> map_s f (tl s))

let rec merge s1 s2 =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let rec hamming =
  Cons (1, fun () ->
    merge (map_s (fun x -> x * 2) hamming)
      (merge (map_s (fun x -> x * 3) hamming)
         (map_s (fun x -> x * 5) hamming)))
let () =
  check (take 12 hamming = [1; 2; 3; 4; 5; 6; 8; 9; 10; 12; 15; 16])
        "hamming numbers";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let rec merge s1 s2 =
  let h1 = hd s1 and h2 = hd s2 in
  if h1 < h2 then Cons (h1, fun () -> merge (tl s1) s2)
  else if h2 < h1 then Cons (h2, fun () -> merge s1 (tl s2))
  else Cons (h1, fun () -> merge (tl s1) (tl s2))
```

Compare the two heads. Emit the smaller and advance only that
stream; when the heads are *equal*, emit one copy and advance
*both* (this is the deduplication). The result stays sorted because
each step emits the global minimum of the two fronts. In `hamming`,
the three scaled copies (`2x`, `3x`, `5x`) are each sorted, and
merging them deduplicates values reachable two ways (for example
`6 = 2 * 3 = 3 * 2`). The self-reference is safe because every use
of `hamming` sits inside a tail thunk, so the stream is only forced
one node at a time, by which point earlier nodes already exist.

:::

## Problem 17: `iterate`

Write the *unfold* combinator

```text
iterate : ('a -> 'a) -> 'a -> 'a stream
```

so that `iterate f x` is the stream `x, f x, f (f x), f (f (f x)),
...`. For example, `iterate (fun n -> n * 2) 1` is the powers of
two `1, 2, 4, 8, 16, ...`, and `iterate (fun n -> n + 1) 0` is the
naturals.

:::quiz code id=M07-L10-q17
Implement `iterate`.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)

let rec iterate f x =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 5 (iterate (fun n -> n * 2) 1) = [1; 2; 4; 8; 16])
        "powers of two";
  check (take 4 (iterate (fun n -> n + 3) 0) = [0; 3; 6; 9])
        "step by three";
  check (take 1 (iterate (fun n -> n + 1) 42) = [42]) "just the seed";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let rec iterate f x =
  Cons (x, fun () -> iterate f (f x))
```

The current value `x` is the head; the tail is `iterate f` applied
to `f x`, deferred behind a thunk. Each forced node advances the
seed by one application of `f`. `iterate` is the most general
one-step stream generator: `from n` is `iterate (fun k -> k + 1)
n`, and many of the streams in this lecture are special cases of
it.

:::

## Problem 18: `partial_sums`

Write a function

```text
partial_sums : int stream -> int stream
```

that turns a stream into its stream of running totals: the `n`th
output is the sum of the first `n + 1` inputs. For example, the
partial sums of `1, 2, 3, 4, ...` are `1, 3, 6, 10, ...`. This is a
*scan*: like a fold, but it emits every intermediate accumulator
instead of only the final one (and on an infinite stream there is
no final one).

:::quiz code id=M07-L10-q18
Implement `partial_sums`.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)
let rec from n = Cons (n, fun () -> from (n + 1))

let partial_sums s =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 5 (partial_sums (from 1)) = [1; 3; 6; 10; 15])
        "sums of 1..";
  check (take 4 (partial_sums (from 0)) = [0; 1; 3; 6])
        "sums of 0..";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let partial_sums s =
  let rec go acc s =
    let acc = acc + hd s in
    Cons (acc, fun () -> go acc (tl s))
  in
  go 0 s
```

The helper `go` carries the running total `acc`. At each node it
adds the current head to `acc`, emits the new total, and defers the
rest with the updated `acc` captured in the thunk. Unlike a fold,
which would loop forever on an infinite stream and never return,
the scan produces one total per node on demand. The seed `0` makes
the first output equal to the first input.

:::

## Problem 19: enumerating all pairs

A stream visits its elements one after another, so it can only
enumerate a *sequence*. Can it enumerate a *grid*: every pair
`(i, j)` of non-negative integers, each appearing at some finite
position? Yes, by walking the diagonals. Write

```text
nat_pairs : (int * int) stream
```

that enumerates the pairs in order of increasing `i + j`, and within
each diagonal by increasing `i`: `(0,0)`, then `(0,1), (1,0)`, then
`(0,2), (1,1), (2,0)`, and so on. Every pair appears at a finite
index, which is what makes `int * int` (a "two-dimensional"
infinity) streamable at all.

:::quiz code id=M07-L10-q19
Implement `nat_pairs`. A helper that walks one diagonal (fixed sum
`s`, increasing `i`) and rolls over to the next diagonal is the
clean way.

```ocaml
type 'a stream = Cons of 'a * (unit -> 'a stream)
let hd (Cons (x, _)) = x
let tl (Cons (_, t)) = t ()
let rec take n s = if n = 0 then [] else hd s :: take (n - 1) (tl s)

let nat_pairs =
  Cons ((0, 0), fun () -> failwith "not implemented")
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (take 6 nat_pairs
         = [(0,0); (0,1); (1,0); (0,2); (1,1); (2,0)])
        "first six, diagonal order";
  check (List.mem (3, 4) (take 100 nat_pairs))
        "every pair appears at a finite index";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let nat_pairs =
  let rec diag s i =
    if i > s then diag (s + 1) 0    (* finished diagonal s; start s+1 *)
    else Cons ((i, s - i), fun () -> diag s (i + 1))
  in
  diag 0 0
```

`diag s i` produces the points on the diagonal `i + j = s`, walking
`i` from 0 up to `s` (so `j = s - i` runs from `s` down to 0). When
`i` exceeds `s` the diagonal is done and we roll over to `diag (s +
1) 0`. Starting at `diag 0 0` enumerates diagonals `0, 1, 2, ...` in
turn. Because each diagonal is finite, every pair `(i, j)` is
reached after the finitely many points on the earlier diagonals:
this is Cantor's diagonal enumeration of pairs, the argument that
the rationals are countable, expressed as a stream.

:::

## What you should be able to do now

By the end of these nineteen problems you should be comfortable with:

- The reference idiom (`sum_ref`, `gensym`'s private counter), in-place
  array work with a `for` loop (`rotate_left`, `prefix_sums_in_place`),
  and mutable records (`deposit`/`withdraw`, the growable array, the
  ring-buffer window).
- The amortised-doubling trick behind every growable array, and the
  ring-buffer trick behind a fixed-size sliding window.
- Writing a module to satisfy a signature, and why `with type t =
  ...` matters when a caller needs the concrete type (`Showable`).
- Writing *functors* that build modules from modules: one whose
  result is a *mutable* node (`MakeNode`), one built on top of
  another functor (`MakeList`), and the `Set.Make` / `Map.Make`
  shape parameterised by a comparison or equality (`MakeSet`,
  `MakeDict`).
- Hiding a representation behind an abstract type, and the
  difference between a functional store that returns new values
  (`FHeap`) and a mutable one that updates in place.
- Building and consuming infinite streams: alternating
  (`interleave`), repeating (`cycle`), merging and self-reference
  (`merge` / Hamming), unfolding (`iterate`), scanning
  (`partial_sums`), and diagonalising a grid (`nat_pairs`).

The [next module](M08-L01-option-monad.html) goes further with two more
advanced ideas: *monads* (a uniform way to sequence computations
that carry context, including the kind of functional-heap state you
built in Problem 13) and *generalised algebraic data types* (GADTs).

## Sources

Part 2's signature-and-functor problems (`Showable`, the
`MakeNode` / `MakeList` doubly-linked list, and the functional heap
`FHeap`) are drawn from the mutability-and-modules and monads
assignments of the instructor's *CS3100: Paradigms of Programming*
course at IIT Madras, with prose, signatures, test harnesses, and
reference solutions rewritten for this NPTEL course. The set and
dictionary functors (`MakeSet`, `MakeDict`) follow the standard
`Set.Make` / `Map.Make` shape. Part 1 (references, arrays, mutable
records) and Part 3 (streams) are new here, exercising this
module's lectures directly.
