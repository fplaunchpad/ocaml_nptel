---
title: "Practice: monads and GADTs"
lecture_no: 8
week: 8
duration_target_min: 0
concepts: [practice problems, state monad, functional references, universal types, length-indexed lists, type-level arithmetic, typed interpreter, type witness, constant folding]
keywords: [OCaml, practice, assignment, monad, state, ref, GADT, length-indexed, plus, mult, min, witness, simplify]
think_about_this: "These are the stretch end of Module 8: a state monad that simulates mutable references, and length-indexed lists whose operations carry type-level proofs. Everything is pure; the types do the bookkeeping."
reading:
  - title: "Real World OCaml, GADTs"
    url: https://dev.realworldocaml.org/gadts.html
---

# Practice for Module 8: monads and GADTs

These are stretch problems, harder than the lectures and book-only
(there are no slides). Part 1 uses the
[state monad](M08-L03-state-monad.html) to *simulate mutable
references* without any real mutation; Part 2 pushes
[length-indexed lists](M08-L05-gadts-use-cases.html) to operations
that carry the [type-level proofs](M08-L05-gadts-use-cases.html#aside-type-level-arithmetic)
from the use-cases lecture's aside; Part 3 returns to the
[tutorial's](M08-L07-tutorial.html) typed interpreter, combining
witnesses with the evaluator. Attempt them once the module's
lectures are comfortable.

Each problem is a fill-in-the-blank cell with a `Check` button; the
reference solution sits in a collapsed block below it. The problems
share a few definitions, gathered in the *Background* section, so
run the page top to bottom (or use `Run all`) before checking a
problem.

## Background

### A functional heap

A *functional heap* is an immutable key-value store: every update
returns a new heap. You built one in the
[Module 7 practice](M07-L10-practice.html); here it is again, with
the store as a function `'k -> 'v option`.

```ocaml
module type FHEAP = sig
  type ('k, 'v) t
  val empty_heap : ('k, 'v) t
  val set : ('k, 'v) t -> 'k -> 'v -> ('k, 'v) t
  val get : ('k, 'v) t -> 'k -> 'v option
end

module FHeap : FHEAP = struct
  type ('k, 'v) t = 'k -> 'v option
  let empty_heap = fun _ -> None
  let set h k v = fun k' -> if k' = k then Some v else h k'
  let get h k = h k
end
```

### The monad interface

The same `MONAD` shape as the lectures, with `let*` as a member so
that opening a monad module brings the syntax into scope.

```ocaml
module type MONAD = sig
  type 'a t
  val return : 'a -> 'a t
  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
end
```

### A universal type

To store values of *different* types in one heap, we need a single
type they can all be packed into. A *universal type* provides a
`pack`/`unpack` pair per use site: `pack` injects a value, `unpack`
recovers it (returning `None` if the universal value was packed by a
*different* packer). The implementation below is given; its details
do not matter, only its interface.

```ocaml
module Univ : sig
  type t
  type 'a packer = { pack : 'a -> t; unpack : t -> 'a option }
  val mk : unit -> 'a packer
end = struct
  type t = exn
  type 'a packer = { pack : 'a -> t; unpack : t -> 'a option }
  let mk : type a. unit -> a packer = fun () ->
    let module M = struct exception E of a end in
    { pack = (fun x -> M.E x);
      unpack = (function M.E x -> Some x | _ -> None) }
end
```

Each call to `Univ.mk ()` returns a fresh packer; a value packed by
one packer unpacks to `None` through any other.

### Type-level numbers and proofs

Part 2 reuses the Peano numerals, length-indexed vector, and the
`plus` / `mult` / `min` proof types from the
[type-level-arithmetic aside](M08-L05-gadts-use-cases.html#aside-type-level-arithmetic).
They are repeated here so the cells compile.

```ocaml
type z = Z
type 'n s = S of 'n

type ('a, _) vec =
  | Nil  : ('a, z) vec
  | Cons : 'a * ('a, 'n) vec -> ('a, 'n s) vec

type (_, _, _) plus =
  | PlusZero : (z, 'n, 'n) plus
  | PlusSucc : ('m, 'n, 'o) plus -> ('m s, 'n, 'o s) plus

type (_, _, _) mult =
  | MultZero : (z, 'n, z) mult
  | MultSucc : ('n, 'p, 'o) plus * ('m, 'n, 'p) mult -> ('m s, 'n, 'o) mult

type (_, _, _) min =
  | MinZero1 : (z, 'n, z) min
  | MinZero2 : ('m, z, z) min
  | MinSucc  : ('m, 'n, 'o) min -> ('m s, 'n s, 'o s) min
```

## Part 1: monads

### Problem 1: `Ref_monad`

Implement a monad that simulates OCaml-style references holding one
fixed value type. The state threaded by the monad is a *counter*
(for handing out fresh reference cells) paired with a functional
heap. A `ref` is just the integer index of its cell.

:::quiz code id=M08-L08-q1
Fill in the six members so the tests pass. `mk_ref` allocates a
fresh cell (bump the counter); `!` reads; `:=` writes; `run_state`
runs a computation from an empty heap and a zero counter.

```ocaml
module type REF_MONAD = sig
  type value
  type ref
  include MONAD
  val mk_ref : value -> ref t
  val ( ! ) : ref -> value t
  val ( := ) : ref -> value -> unit t
  val run_state : 'a t -> 'a
end

module Ref_monad (V : sig type t end) : REF_MONAD with type value = V.t =
struct
  type value = V.t
  type ref = int
  type 'a t = int * (int, value) FHeap.t -> int * (int, value) FHeap.t * 'a
  let return _ = failwith "not implemented"
  let ( let* ) _ _ = failwith "not implemented"
  let mk_ref _ = failwith "not implemented"
  let ( ! ) _ = failwith "not implemented"
  let ( := ) _ _ = failwith "not implemented"
  let run_state _ = failwith "not implemented"
end
```

```ocaml skip
let () =
  let module R = Ref_monad (struct type t = int end) in
  let open R in
  let prog =
    let* i = mk_ref 10 in
    let* iv = !i in
    let* () = i := iv + 1 in
    let* j = mk_ref 100 in
    let* jv = !j in
    return (iv, jv, ())
  in
  let (a, b, _) = run_state prog in
  if a <> 10 || b <> 100 then failwith "wrong";
  let prog2 = let* i = mk_ref 10 in let* () = i := 42 in !i in
  if run_state prog2 <> 42 then failwith "update";
  let independent =
    let* i = mk_ref 10 in
    let* j = mk_ref 100 in
    let* iv = !i in
    let* jv = !j in
    let* () = i := 11 in
    let* jv2 = !j in
    let* () = j := 101 in
    let* iv2 = !i in
    return (iv, jv, jv2, iv2)
  in
  if run_state independent <> (10, 100, 100, 11) then
    failwith "allocated references must be independent";
  if run_state independent <> (10, 100, 100, 11) then
    failwith "each run starts with fresh state";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
module Ref_monad (V : sig type t end) : REF_MONAD with type value = V.t =
struct
  type value = V.t
  type ref = int
  type 'a t = int * (int, value) FHeap.t -> int * (int, value) FHeap.t * 'a
  let return x = fun (c, h) -> (c, h, x)
  let ( let* ) m f = fun s -> let (c, h, a) = m s in (f a) (c, h)
  let mk_ref v = fun (c, h) -> (c + 1, FHeap.set h c v, c)
  let ( ! ) r = fun (c, h) -> (c, h, Option.get (FHeap.get h r))
  let ( := ) r v = fun (c, h) -> (c, FHeap.set h r v, ())
  let run_state m = let (_, _, a) = m (0, FHeap.empty_heap) in a
end
```

`'a t` is a state-transforming function over `(counter, heap)`,
exactly the [state monad](M08-L03-state-monad.html) with a richer
state. `return` leaves the state alone. `let*` threads the state
from one step into the next. `mk_ref` allocates at the current
counter and bumps it (the `gensym` idea, giving *generative*
references). `!` and `:=` read and write the heap at a cell's index.

:::

### Problem 2: `Poly_ref_monad`

Now lift the restriction that all cells hold the same type. The heap
stores `Univ.t`, and each reference carries its own packer, so a
cell of any type can be packed in and unpacked out.

:::quiz code id=M08-L08-q2
Fill in the members. `mk_ref` makes a fresh packer (`Univ.mk ()`),
packs the value, and stores it; `!` unpacks; `:=` repacks.

```ocaml
module type POLY_REF_MONAD = sig
  type 'a ref
  include MONAD
  val mk_ref : 'a -> 'a ref t
  val ( ! ) : 'a ref -> 'a t
  val ( := ) : 'a ref -> 'a -> unit t
  val run_state : 'a t -> 'a
end

module Poly_ref_monad : POLY_REF_MONAD = struct
  type 'a ref = int * 'a Univ.packer
  type 'a t = int * (int, Univ.t) FHeap.t -> int * (int, Univ.t) FHeap.t * 'a
  let return _ = failwith "not implemented"
  let ( let* ) _ _ = failwith "not implemented"
  let mk_ref _ = failwith "not implemented"
  let ( ! ) _ = failwith "not implemented"
  let ( := ) _ _ = failwith "not implemented"
  let run_state _ = failwith "not implemented"
end
```

```ocaml skip
let () =
  let open Poly_ref_monad in
  let prog =
    let* i = mk_ref 10 in
    let* s = mk_ref "x" in
    let* iv = !i in
    let* () = i := iv + 1 in
    let* sv = !s in
    let* iv2 = !i in
    return (sv, iv2)
  in
  if run_state prog <> ("x", 11) then failwith "wrong";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
module Poly_ref_monad : POLY_REF_MONAD = struct
  type 'a ref = int * 'a Univ.packer
  type 'a t = int * (int, Univ.t) FHeap.t -> int * (int, Univ.t) FHeap.t * 'a
  let return x = fun (c, h) -> (c, h, x)
  let ( let* ) m f = fun s -> let (c, h, a) = m s in (f a) (c, h)
  let mk_ref v = fun (c, h) ->
    let p = Univ.mk () in (c + 1, FHeap.set h c (p.Univ.pack v), (c, p))
  let ( ! ) (i, p) = fun (c, h) ->
    (c, h, Option.get (p.Univ.unpack (Option.get (FHeap.get h i))))
  let ( := ) (i, p) v = fun (c, h) -> (c, FHeap.set h i (p.Univ.pack v), ())
  let run_state m = let (_, _, a) = m (0, FHeap.empty_heap) in a
end
```

The only change from `Ref_monad` is that the reference carries a
packer alongside its index, and the heap stores `Univ.t`. `mk_ref`
mints a fresh packer; `!` and `:=` use it to move the value in and
out of the universal type. Because each cell's packer is its own,
the `unpack` always matches the `pack` that stored the value.

:::

## Part 2: GADTs

These problems extend the length-indexed `vec`. Recall that
`('a, 'n) vec` is a list of `'a`s whose length `'n` is a Peano
numeral, and that `plus` / `mult` / `min` are proofs about those
numerals.

### Problem 3: `cross_v_l`

Pairing a single value with every element of a vector does not
change its length.

:::quiz code id=M08-L08-q3
Implement `cross_v_l : 'a -> ('b, n) vec -> ('a * 'b, n) vec`, which
pairs `v` with each element.

```ocaml
let cross_v_l : type n. 'a -> ('b, n) vec -> ('a * 'b, n) vec =
  fun _ _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let r = cross_v_l 1 (Cons ("a", Cons ("b", Nil))) in
  if r <> Cons ((1, "a"), Cons ((1, "b"), Nil)) then failwith "wrong";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec cross_v_l : type n. 'a -> ('b, n) vec -> ('a * 'b, n) vec =
  fun v l -> match l with
  | Nil -> Nil
  | Cons (x, xs) -> Cons ((v, x), cross_v_l v xs)
```

Each `Cons` becomes a `Cons`, so the length index `n` is preserved.

:::

### Problem 4: `append`

Appending two vectors gives one whose length is the *sum*. Since
OCaml's types cannot add, `append` takes a `plus` proof that
`m + n = o` and returns an `('a, o) vec`.

:::quiz code id=M08-L08-q4
Implement `append`. The proof and the first vector shrink in
lock-step.

```ocaml
let append : type m n o.
  (m, n, o) plus -> ('a, m) vec -> ('a, n) vec -> ('a, o) vec =
  fun _ _ _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let p : (z s s, z s s s, z s s s s s) plus = PlusSucc (PlusSucc PlusZero) in
  let r = append p (Cons (1, Cons (2, Nil)))
                   (Cons (3, Cons (4, Cons (5, Nil)))) in
  if r <> Cons (1, Cons (2, Cons (3, Cons (4, Cons (5, Nil))))) then
    failwith "wrong";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec append : type m n o.
  (m, n, o) plus -> ('a, m) vec -> ('a, n) vec -> ('a, o) vec =
  fun p l1 l2 -> match p, l1 with
  | PlusZero, Nil             -> l2
  | PlusSucc p', Cons (x, xs) -> Cons (x, append p' xs l2)
```

`PlusZero` says `l1` is empty, so the answer is `l2`. `PlusSucc p'`
strips one `Cons` from `l1` and one `PlusSucc` from the proof,
keeping the length arithmetic aligned. The `(PlusZero, Cons ...)`
and `(PlusSucc _, Nil)` cases are impossible and the compiler knows
it, so two cases are exhaustive.

:::

### Problem 5: `cross`

The cross product of a length-`m` vector with a length-`n` vector
has length `m * n`. It uses `cross_v_l` and `append`, and takes a
`mult` proof.

:::quiz code id=M08-L08-q5
Implement `cross`. (Hint: for `Cons (x, xs)`, pair `x` with all of
`l2` via `cross_v_l`, then `append` that to the recursive
`cross`. The `mult` proof carries a `plus` proof for that append.)

```ocaml
let cross : type m n o.
  (m, n, o) mult -> ('a, m) vec -> ('b, n) vec -> ('a * 'b, o) vec =
  fun _ _ _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let p : (z s, z s s, z s s) mult = MultSucc (PlusSucc (PlusSucc PlusZero), MultZero) in
  let r = cross p (Cons ("a", Nil)) (Cons (1, Cons (2, Nil))) in
  if r <> Cons (("a", 1), Cons (("a", 2), Nil)) then failwith "wrong";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec cross : type m n o.
  (m, n, o) mult -> ('a, m) vec -> ('b, n) vec -> ('a * 'b, o) vec =
  fun p l1 l2 -> match p, l1 with
  | MultZero, Nil -> Nil
  | MultSucc (pl, pm), Cons (x, xs) ->
      append pl (cross_v_l x l2) (cross pm xs l2)
```

`MultZero` (`0 * n = 0`) gives the empty result. `MultSucc (pl, pm)`
unpacks the proof that `(m+1) * n = o` into `pm : m * n = p` and
`pl : n + p = o`; the body builds `cross_v_l x l2` (length `n`) and
`cross pm xs l2` (length `p`), then `append pl` joins them into a
vector of length `o`.

:::

### Problem 6: `last`

The stdlib has no `List.last`; a hand-rolled one returns an
`'a option` (or raises) because the list might be empty. On
vectors the *type* can demand non-emptiness: an index of `n s`
means length at least one, so `last` returns a bare `'a`.

:::quiz code id=M08-L08-q6
Implement `last : ('a, n s) vec -> 'a`, the last element of a
non-empty vector. (Hint: a non-empty vector is either a singleton
`Cons (x, Nil)` or has a non-empty tail; the recursive call needs
the tail's *pattern* to say so.)

```ocaml
let last : type n. ('a, n s) vec -> 'a =
  fun _ -> failwith "not implemented"
```

```ocaml skip
let () =
  if last (Cons (1, Cons (2, Cons (3, Nil)))) <> 3 then failwith "wrong";
  if last (Cons ("only", Nil)) <> "only" then failwith "one element";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec last : type n. ('a, n s) vec -> 'a = function
  | Cons (x, Nil) -> x
  | Cons (_, (Cons _ as tl)) -> last tl
```

No `Nil` case is needed: the input index is `n s`, and
`Nil : ('a, z) vec` can never have a successor index, so the
compiler refutes it by itself; the two cases are exhaustive. The
second pattern must be `Cons (_, (Cons _ as tl))`, not a bare
`Cons (_, tl)`: a bare `tl` only has the abstract length `n`,
and `last` demands a successor index. Matching the tail against
`Cons _` refines its length to a successor, which is exactly the
proof the recursive call needs. And `last Nil` does not compile
at all, so the empty-list crash of a list-based `last` cannot be
written.

:::

### Problem 7: `zip_matching`

The equal-length `zip` from the
[use-cases lecture](M08-L05-gadts-use-cases.html) rejects vectors
of unequal length outright. To zip *unequal* vectors, stopping at
the shorter one, the result length is `min m n`; `zip_matching`
takes a `min` proof.

:::quiz code id=M08-L08-q7
Implement `zip_matching`, matching the three cases of the `min`
proof.

```ocaml
let zip_matching : type m n o.
  (m, n, o) min -> ('a, m) vec -> ('b, n) vec -> ('a * 'b, o) vec =
  fun _ _ _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let p : (z s s s, z s s s s s, z s s s) min =
    MinSucc (MinSucc (MinSucc MinZero1)) in
  let r = zip_matching p
            (Cons (1, Cons (2, Cons (3, Nil))))
            (Cons (10, Cons (20, Cons (30, Cons (40, Cons (50, Nil)))))) in
  if r <> Cons ((1, 10), Cons ((2, 20), Cons ((3, 30), Nil))) then
    failwith "wrong";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec zip_matching : type m n o.
  (m, n, o) min -> ('a, m) vec -> ('b, n) vec -> ('a * 'b, o) vec =
  fun p l1 l2 -> match p, l1, l2 with
  | MinZero1, Nil, _ -> Nil
  | MinZero2, _, Nil -> Nil
  | MinSucc p', Cons (x, xs), Cons (y, ys) ->
      Cons ((x, y), zip_matching p' xs ys)
```

`MinZero1` (`min 0 n = 0`) and `MinZero2` (`min m 0 = 0`) stop at an
empty vector; `MinSucc` consumes one element from each and recurses.
The proof picks exactly the case that the two vectors' shapes allow,
so the match is exhaustive.

:::

## Part 3: the typed interpreter

These return to the GADT-typed AST from the
[tutorial](M08-L07-tutorial.html): an `'a expr` that can only be
built well-typed, run by `eval : 'a expr -> 'a`.

### Problem 8: witness-driven `let`

The tutorial's higher-order `let` evaluated by *substitution*,
re-running the bound expression on each use. To run it exactly once,
we evaluate it to a value and then turn that value *back* into an
expression, and the snag was knowing which leaf to use, `Int_lit` or
`Bool_lit`. A *type witness*
([from the typed pretty-printer](M08-L05-gadts-use-cases.html#use-1-typed-pretty-printers))
settles it: `Let` carries an `'a ty`, and matching on it chooses the
constructor.

:::quiz code id=M08-L08-q8
Implement `inject : 'a ty -> 'a -> 'a expr`, which wraps a value
back into the AST using its witness. (`eval`'s `Let` case is already
written; it evaluates the bound expression once and feeds it through
`inject`.)

```ocaml
type _ ty =
  | T_int  : int ty
  | T_bool : bool ty

type _ expr =
  | Int_lit  : int -> int expr
  | Bool_lit : bool -> bool expr
  | Add      : int expr * int expr -> int expr
  | If       : bool expr * 'a expr * 'a expr -> 'a expr
  | Let      : 'a ty * 'a expr * ('a expr -> 'b expr) -> 'b expr

let inject : type a. a ty -> a -> a expr = fun _t _v -> failwith "not implemented"

let rec eval : type a. a expr -> a = function
  | Int_lit n    -> n
  | Bool_lit b   -> b
  | Add (x, y)   -> eval x + eval y
  | If (c, t, e) -> if eval c then eval t else eval e
  | Let (t, e, body) -> let v = eval e in eval (body (inject t v))
```

```ocaml skip
let () =
  (* let x = 4 + 6 in x + x  ==> 20, with 4 + 6 evaluated once *)
  let p1 = Let (T_int, Add (Int_lit 4, Int_lit 6), fun x -> Add (x, x)) in
  if eval p1 <> 20 then failwith "let-int";
  (* let b = true in if b then 1 else 0  ==> 1 *)
  let p2 = Let (T_bool, Bool_lit true, fun b -> If (b, Int_lit 1, Int_lit 0)) in
  if eval p2 <> 1 then failwith "let-bool";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let inject : type a. a ty -> a -> a expr = fun t v ->
  match t with
  | T_int  -> Int_lit v
  | T_bool -> Bool_lit v
```

In the `inject` body the witness `t` refines `a`: in the `T_int`
branch `a = int`, so `v : int` and `Int_lit v : int expr`; in the
`T_bool` branch `a = bool`. That refinement is exactly what tells us
which constructor is well-typed. With `inject`, `eval`'s `Let` case
evaluates the bound expression once (`let v = eval e`) and threads
the value back through the body, so there is no re-evaluation and no
generic "value" constructor.

:::

### Problem 9: constant folding

A `simplify` pass folds constant subexpressions (`1 + 2` becomes
`3`) and prunes `if`s whose condition is already known, leaving
everything else unchanged. Its type captures that it *preserves* the
expression's type: an `'a expr` simplifies to an `'a expr`.

:::quiz code id=M08-L08-q9
Implement `simplify`. Fold `Add`, `Mul`, and `Eq_int` when both
operands are literals; reduce `If` when the condition folds to a
`Bool_lit`; otherwise rebuild the node from its simplified parts.

```ocaml
type _ expr =
  | Int_lit  : int -> int expr
  | Bool_lit : bool -> bool expr
  | Add      : int expr * int expr -> int expr
  | Mul      : int expr * int expr -> int expr
  | Eq_int   : int expr * int expr -> bool expr
  | If       : bool expr * 'a expr * 'a expr -> 'a expr

let rec eval : type a. a expr -> a = function
  | Int_lit n -> n
  | Bool_lit b -> b
  | Add (x, y) -> eval x + eval y
  | Mul (x, y) -> eval x * eval y
  | Eq_int (x, y) -> eval x = eval y
  | If (c, t, e) -> if eval c then eval t else eval e

let simplify : type a. a expr -> a expr = fun _ -> failwith "not implemented"
```

```ocaml skip
let () =
  let e = Mul (Add (Int_lit 1, Int_lit 2), Int_lit 3) in
  if simplify e <> Int_lit 9 then failwith "fold arithmetic";
  if eval (simplify e) <> 9 then failwith "eval matches";
  let e2 = If (Eq_int (Int_lit 1, Int_lit 1), Int_lit 5, Int_lit 6) in
  if simplify e2 <> Int_lit 5 then failwith "prune if";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec simplify : type a. a expr -> a expr = function
  | Int_lit n  -> Int_lit n
  | Bool_lit b -> Bool_lit b
  | Add (x, y) ->
      (match simplify x, simplify y with
       | Int_lit a, Int_lit b -> Int_lit (a + b)
       | x', y' -> Add (x', y'))
  | Mul (x, y) ->
      (match simplify x, simplify y with
       | Int_lit a, Int_lit b -> Int_lit (a * b)
       | x', y' -> Mul (x', y'))
  | Eq_int (x, y) ->
      (match simplify x, simplify y with
       | Int_lit a, Int_lit b -> Bool_lit (a = b)
       | x', y' -> Eq_int (x', y'))
  | If (c, t, e) ->
      (match simplify c with
       | Bool_lit true  -> simplify t
       | Bool_lit false -> simplify e
       | c' -> If (c', simplify t, simplify e))
```

Every branch returns an expression of the *same* index it received
(`Add` stays `int expr`, `Eq_int` stays `bool expr`), so the type
`'a expr -> 'a expr` holds throughout: the optimiser cannot
accidentally change a program's type. With warning 4 enabled (off
by default; pass `-w +4`), OCaml would flag the inner matches as
"fragile": the catch-all `x', y'` would keep absorbing cases if new
constructors were added to `expr`. That is a fair caution for
production code; for this fixed little language it is harmless.

:::

## Where this sits

Problems 1 and 2 are the [CS3100](https://kcsrk.info/cs3100_m21/)
monad assignment: a state monad rich enough to *be* a reference
implementation, first monomorphic, then polymorphic via a universal
type. Problems 3 to 7 build on the GADT assignment: every
length-changing operation carries a type-level proof, and the
non-empty index makes `last` total, so the compiler checks the
shapes that ordinary lists check (if at all) only at runtime.
Problems 8 and 9 extend the tutorial's interpreter: a witness-driven
`let` (resolving the re-injection puzzle from the tutorial's HOAS
aside) and a
type-preserving optimiser. This is the far end of what we do with
types in this course; if you enjoyed it, the dependently typed
languages (Agda, Idris, F\*) make this style the default.

## Reading

- **Real World OCaml**, *GADTs*:
  <https://dev.realworldocaml.org/gadts.html>

## Sources

This lecture's problems adapt the monad and GADT programming
assignments from the author's CS3100 course, used here as a private
structural reference; the surface code, prompts, and explanations
are written for this course. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
