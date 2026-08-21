---
title: "GADTs: use cases beyond toy interpreters"
lecture_no: 5
week: 8
duration_target_min: 25
concepts: [type witnesses, typed pretty-printers, type-safe builders, Peano encoding, length-indexed lists]
keywords: [OCaml, GADT, type witness, query builder, length-indexed list, Peano encoding, vec]
activity_question: "Reusing the lecture's [type _ ty] witness, write [default : type a. a ty -> a] that produces a default value for the witnessed type (0, the empty string, false, a pair of defaults, the empty list). This runs the witness the opposite direction from [show]."
think_about_this: "A GADT lets you write a function whose return type depends on the input *value* (not just the input type). Why is that more powerful than overloading or type classes?"
reading:
  - title: "Real World OCaml, More GADTs"
    url: https://dev.realworldocaml.org/gadts.html
---

# GADTs: use cases beyond toy interpreters


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">GADTs: use cases beyond toy interpreters</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The [toy expression-AST from the previous lecture](M08-L04-gadts-basics.html#the-gadt-form)
is the standard "first example" of GADTs. It is useful for showing
the mechanics, but it leaves a misleading impression: that GADTs
are mostly for interpreters. They are not. This lecture shows three
idioms you will see in real OCaml code where GADTs earn their keep:
typed pretty-printers, type-safe builders, and types that enforce a
data structure's shape. Two further idioms, heterogeneous lists and
the machinery behind `printf`, are big enough to get their own
treatment in the [next lecture](M08-L06-hlists-witnesses.html).

The common thread across all of these is *type witnesses*. Where
an ordinary value carries data, a witness is a value whose runtime
shape is uninteresting but whose *type* carries information the
program needs at compile time. GADTs are how OCaml encodes
witnesses naturally.

:::slide

## This lecture: GADTs in real code

- Last lecture's toy expression AST leaves a misleading
  impression: that GADTs are mostly for interpreters.
- They are not. Three idioms where GADTs earn their keep:
  - Typed pretty-printers.
  - Type-safe builders that prevent illegal states.
  - Length-indexed lists: safe `hd`/`tl`, equal-length `zip`.
- Two more next time: heterogeneous lists and the GADT behind
  `printf`.
- Common thread: the *type* carries information the program needs.
- GADTs are how OCaml encodes this naturally.

:::

## Use 1: typed pretty-printers

Suppose you want one function `show` that pretty-prints any value
whose type you know at compile time. With
[ordinary variants](M04-L03-variants.html) you would write a
separate `show_int`, `show_string`, `show_list`, and so on. With a
GADT *witness* of OCaml types, you can have one `show`:

:::slide

## Use 1: typed pretty-printers

```ocaml
type _ ty =
  | T_int    : int ty
  | T_string : string ty
  | T_bool   : bool ty
  | T_pair   : 'a ty * 'b ty -> ('a * 'b) ty
  | T_list   : 'a ty -> 'a list ty

let rec show : type a. a ty -> a -> string = fun t v ->
  match t with
  | T_int    -> string_of_int v
  | T_string -> "\"" ^ v ^ "\""
  | T_bool   -> string_of_bool v
  | T_pair (a, b) ->
      let (x, y) = v in
      "(" ^ show a x ^ ", " ^ show b y ^ ")"
  | T_list t' ->
      "[" ^ String.concat "; " (List.map (show t') v) ^ "]"
```

- `'a ty` is a *witness* for type `'a`: `show t v` renders the
  value that `t` describes.

:::

:::slide

## Using the typed pretty-printer

```ocaml
let _ = show T_int 42                              (* = "42" *)
let _ = show (T_pair (T_int, T_string)) (3, "hi")  (* = "(3, \"hi\")" *)
let _ = show (T_list T_int) [1; 2; 3]              (* = "[1; 2; 3]" *)
```

Each case of `show` refines the type and unpacks the value
accordingly.

:::

Read the GADT carefully. A value of type `int ty` is a witness for
the OCaml type `int`. The only such value is `T_int`. A value of
type `string ty` witnesses `string`, and the only such value is
`T_string`. Compound types get compound witnesses: `T_pair (a,
b) : ('a * 'b) ty` is built out of sub-witnesses `a : 'a ty` and
`b : 'b ty`.

The function `show` takes a witness `t : 'a ty` plus a value `v :
'a`. The key trick: when we pattern-match on `t`, each case refines
`'a` to the specific concrete type the constructor witnesses. In
the `T_int` case, `'a = int`, so `v : int`, and we can call
`string_of_int v`. In the `T_pair (a, b)` case, `'a = 'b * 'c` for
some types `'b` and `'c` that match the sub-witnesses, so we can
destructure `v` as a pair and recursively show each side.

Without GADTs, no single function could have its parameter type
depend on the value of an earlier argument. The first argument's
*value* (which constructor of `ty`) determines the second
argument's *type*. That dependency is what GADTs encode.

This pattern is used heavily in serialisation libraries and
[`type-conv`-style](https://github.com/janestreet/ppx_jane)
deriving infrastructure: you derive a value of type `'a ty` for
your record type, then use it to serialise, deserialise, generate
test cases, or print values, all without writing the code by hand.

## Use 2: type-safe builders

A *builder* lets you assemble a value piece by piece while the type
of the partial value changes as you go. A small SQL-style query is
the classic example: the type parameter tracks the *current row
type*, exactly as a SQL result schema does. We build it as a GADT
and actually run it over in-memory rows:

:::slide

## Use 2: a type-safe query builder

```ocaml
type _ query =
  | From   : 'row list -> 'row query
  | Where  : 'row query * ('row -> bool) -> 'row query
  | Select : 'row query * ('row -> 'col) -> 'col query
```

- `From rows`: a query over a table of `'row`s.
- `Where (q, p)`: keep the rows of `q` that pass `p`; row type
  unchanged.
- `Select (q, f)`: project each row through `f`; row type becomes
  `'col`.

:::

:::slide

## Running a query

```ocaml
let rec run : type a. a query -> a list = function
  | From rows     -> rows
  | Where (q, p)  -> List.filter p (run q)
  | Select (q, f) -> List.map f (run q)
```

- `run` interprets the pipeline: `From` yields the rows, `Where`
  filters them, `Select` projects each one.

:::

:::slide

## Running a query: an example

```ocaml
type emp = { name : string; dept : string; salary : int }
let staff =
  [ { name = "Asha";  dept = "Eng"; salary = 120 };
    { name = "Ravi";  dept = "Ops"; salary = 90  };
    { name = "Meera"; dept = "Eng"; salary = 150 } ]

let top_eng : string query =
  Select (Where (From staff, fun e -> e.dept = "Eng" && e.salary > 100),
          fun e -> e.name)

let _ = run top_eng   (* = ["Asha"; "Meera"] *)
```

- `From staff` is an `emp query`; `Select (..., fun e -> e.name)`
  turns it into a `string query`. The type follows the rows.

:::

:::slide

## The type catches a bad filter

```ocaml skip
let _ = Where (From staff, fun s -> s = "Eng")
(* error: predicate is string -> bool, but the rows are emp *)
```

- `Where`'s predicate must match the query's *current* row type.
- A filter written against the wrong column type is a compile
  error, not a runtime query failure.

:::

The type parameter of `query` is always the type of a row at that
point in the pipeline. `From staff` starts at `emp`; `Where` keeps
the row type; `Select` rewrites it to whatever the projection
returns. Compose them and the compiler checks every stage lines up,
so a predicate or projection applied to the wrong row type is
rejected before the query ever runs.

Real query libraries push this much further. OCaml's
[Petrol](https://github.com/Gopiandcode/petrol), for instance, keeps
the *columns* and which operations are legal (you cannot `ORDER BY`
a non-`SELECT`) in the type as well. That extra safety rides on
heavier type machinery than we use here, but the core idea is
exactly this one: let the type track the shape of the data as the
query is built.

## Use 3: length-indexed lists

The standard `List.hd []` and `List.tl []` raise at runtime, the way
indexing past the end of a C array is undefined behaviour. We can
turn those into *compile* errors by recording the list's *length* in
its type.

To do that we first need *numbers that live in types*. We build them
the way you count on your fingers: `z` is zero, and `'n s` (`s` for
*successor*) is one more than `'n`. So `z` is 0, `z s` is 1, `z s s`
is 2, and so on, the classic *Peano* encoding:

:::slide

## Peano numerals: numbers in the types

```ocaml
type z = Z               (* zero           *)
type 'n s = S of 'n      (* successor, n+1 *)

let zero = Z             (* : z     *)
let one  = S Z           (* : z s   *)
let two  = S (S Z)       (* : z s s *)

let succ n     = S n     (* 'n -> 'n s  : add one      *)
let pred (S n) = n       (* 'n s -> 'n  : take one off *)
```

- `z`, `z s`, `z s s`, ... are the naturals, one `S` per unit.
- `succ` adds an `S`; `pred` peels one off, and takes only `'n s`,
  so the predecessor of zero cannot even be written.

:::

A list type that carries one of these numbers as an index records
how long the list is, and the compiler keeps it honest:

:::slide

## Use 3: a length-indexed list

```ocaml
type ('a, _) vec =
  | Nil  : ('a, z) vec
  | Cons : 'a * ('a, 'n) vec -> ('a, 'n s) vec

let v = Cons (1, Cons (2, Cons (3, Nil)))   (* (int, z s s s) vec *)
```

- The length is in the index: `Nil` has length `z`, and each `Cons`
  adds one `s`.
- So `v`'s type, `(int, z s s s) vec`, says "three ints" out loud.

:::

:::slide

## Safe `hd` and `tl`

```ocaml
let hd : type n. ('a, n s) vec -> 'a = fun (Cons (x, _)) -> x
let tl : type n. ('a, n s) vec -> ('a, n) vec = fun (Cons (_, xs)) -> xs

let _ = hd v   (* = 1 *)
```

```ocaml skip
let _ = hd Nil   (* error: Nil has length z, hd needs length n s *)
```

- `hd` / `tl` take only `'n s`-length vectors: the non-empty ones
  (length at least one).
- `hd Nil` will not compile, so the `List.hd []` crash can no longer
  be written.
- OCaml knows `Nil` cannot have a length-`'n s` type, so the single
  `Cons` case is already complete (no missing-case warning).

:::

:::slide

## `map`: length-preserving

```ocaml
let rec map : type n. ('a -> 'b) -> ('a, n) vec -> ('b, n) vec =
  fun f l -> match l with
  | Nil -> Nil
  | Cons (x, xs) -> Cons (f x, map f xs)

let _ = map (fun x -> x * 10) v
(* = Cons (10, Cons (20, Cons (30, Nil))) *)
```

- The result type carries the *same* length index `n` as the input.
- Length preservation is enforced by the type, not just intended.

:::

:::slide

## `zip`: equal lengths only

```ocaml
let rec zip : type n. ('a, n) vec -> ('b, n) vec -> ('a * 'b, n) vec =
  fun xs ys -> match xs, ys with
  | Nil, Nil -> Nil
  | Cons (x, xs), Cons (y, ys) -> Cons ((x, y), zip xs ys)
```

```ocaml skip
let _ = zip v (Cons ("a", Cons ("b", Nil)))
(* error: v has length z s s s, this one z s s *)
```

- Both inputs share the same length `n`, so zipping lists of
  different lengths does not type-check.
- A `Nil` paired with a `Cons` would mean unequal lengths, which
  cannot happen here, so the two cases are all OCaml needs.

:::

:::slide

## `reverse`: why the obvious version is tricky

```ocaml skip
let rec rev l acc = match l with
  | Nil -> acc
  | Cons (x, xs) -> rev xs (Cons (x, acc))
```

- Its result length is `'m + 'n` (the two pieces added), so its
  type would be `('a, 'm) vec -> ('a, 'n) vec -> ('a, 'm + 'n) vec`.
- But OCaml's types cannot *add*: there is no `'m + 'n`, so this
  version cannot be given a length-indexed type.

:::

:::slide

## `reverse`: with successor only

```ocaml
let rec snoc : type n. ('a, n) vec -> 'a -> ('a, n s) vec =
  fun l x -> match l with
  | Nil -> Cons (x, Nil)
  | Cons (y, ys) -> Cons (y, snoc ys x)

let rec rev : type n. ('a, n) vec -> ('a, n) vec =
  fun l -> match l with
  | Nil -> Nil
  | Cons (x, xs) -> snoc (rev xs) x

let _ = rev v   (* = Cons (3, Cons (2, Cons (1, Nil))) *)
```

- `snoc` adds one element (`n` to `n s`); `rev`'s type keeps the
  *same* length `n`.
- But it is **O(n²)**: `snoc` is O(n), called n times.
- The O(n) accumulator version needs *type-level addition*; the
  book aside on type-level arithmetic develops it.

:::

These vectors put the *length* in the type; the
[next lecture's](M08-L06-hlists-witnesses.html) heterogeneous lists
put the *element types* there instead. Both are the same move:
encode a structural invariant as a type index, and the compiler
checks it for you.

## Aside: type-level arithmetic

This section is in the book, not the slides; skip it on a first
read. The slides noted that operations which *change* a vector's
length, an O(n) reverse, or appending two vectors, need the type
system to *add* lengths. We cannot write `'m + 'n`, but we can
encode addition as a relation witnessed by a value: a
`('m, 'n, 'o) plus` is a *proof* that `'m + 'n = 'o`.

```ocaml
type (_, _, _) plus =
  | PlusZero : (z, 'n, 'n) plus                  (* 0 + n = n *)
  | PlusSucc : ('m, 'n, 'o) plus -> ('m s, 'n, 'o s) plus
                                  (* m+n=o, so (m+1)+n = o+1 *)
```

A value of this type *is* a proof; this is the Curry-Howard
correspondence (propositions are types, proofs are values).
`PlusZero` is the base fact `0 + n = n`; `PlusSucc` adds one to the
first summand and to the sum. With it, `append` can promise that the
result length is exactly the sum of the inputs. Its type says so:

```text
val append :
  ('m, 'n, 'o) plus -> ('a, 'm) vec -> ('a, 'n) vec -> ('a, 'o) vec
```

The proof argument and the first vector shrink in lock-step: each
`Cons` taken off the first vector is matched by one `PlusSucc`
peeled off the proof, so the result length stays justified at every
step. Writing the body that keeps this promise is one of the
practice problems, so we leave it there. The same `plus` justifies
an O(n) length-preserving reverse.

The technique scales to other arithmetic. *Multiplication*,
`('m, 'n, 'o) mult` meaning `m * n = o`, is built from `plus`,
because `(m+1) * n = n + m*n`:

```ocaml
type (_, _, _) mult =
  | MultZero : (z, 'n, z) mult                   (* 0 * n = 0 *)
  | MultSucc : ('n, 'p, 'o) plus * ('m, 'n, 'p) mult -> ('m s, 'n, 'o) mult
                                  (* m*n=p and n+p=o, so (m+1)*n = o *)
```

And *minimum*, `('m, 'n, 'o) min` meaning `min m n = o`, has three
cases, mirroring a `zip` that stops at the shorter vector:

```ocaml
type (_, _, _) min =
  | MinZero1 : (z, 'n, z) min                    (* min 0 n = 0 *)
  | MinZero2 : ('m, z, z) min                    (* min m 0 = 0 *)
  | MinSucc  : ('m, 'n, 'o) min -> ('m s, 'n s, 'o s) min
```

The price is the same throughout: *you* supply the proof by hand.
Appending a 2-vector to a 3-vector needs the value
`PlusSucc (PlusSucc PlusZero)`, a proof that `2 + 3 = 5`, passed in
explicitly. Languages built for this (Agda, Idris,
F\*) construct such proofs automatically; in OCaml it is manual. The
[Module 8 practice](M08-L08-practice.html) puts these to work,
implementing `append` (with `plus`), `cross` (with `mult`), and a
length-matching `zip` (with `min`).

## Two more idioms, next lecture

Two further GADT idioms are common enough to deserve their own
treatment, and the [next lecture](M08-L06-hlists-witnesses.html)
develops both:

- *Heterogeneous lists*: a list whose elements have different
  types, each tracked at compile time, that you can still recurse
  over. The witness pattern from `show` generalises to drive
  operations across such a list.
- *Format strings and `Printf`*: the most famous hidden use of
  GADTs in OCaml. A format string like `"%d %s\n"` has a *type*
  that forces the following arguments to be `int` then `string`,
  checked at compile time. It is a witness list encoded inside the
  string literal.

Both build directly on the typed-witness idea above, which is why
they fit naturally after this lecture rather than inside it.

## Do I need a GADT here?

The [last lecture's guidance on when to reach for a
GADT](M08-L04-gadts-basics.html#when-to-reach-for-gadts) applies
to these use cases too: most code is better served by plain
[records](M04-L02-records.html) and
[variants](M04-L03-variants.html), and the sharp edges (locally
abstract types, explicit annotations, hostile error messages) are
the same. Before reaching for the heavier machinery, a short
checklist:

:::slide

## Do I need a GADT here?

- Do different cases need to carry *different* type information?
  (If no: ordinary variant.)
- Will the compiler reject an illegal construction *and* can I
  name a concrete bug class that this prevents? (If no: not worth
  the cost.)
- Am I building a small embedded language or a typed-witness API?
  (If yes: GADTs are likely the right tool.)
- Is the complexity proportional to the safety win? (Always check.)

:::

Most real OCaml code never needs GADTs. The small fraction that
does (typed DSLs, query builders, the format-string code in the
stdlib) uses them heavily. We are in this course to know when
they are right; that is the goal, not to make GADTs the default.

## A quick check

:::quiz mcq id=M08-L05-q3
In the `show` function with a GADT witness, why does
`show (T_pair (T_int, T_string)) (3, "hi")` type-check while
`show T_int (3, "hi")` does not?

- [ ] OCaml permits pairs only when a matching `T_pair` constructor appears nearby.
- [x] The pair value requires a pair witness, not `T_int`.
- [ ] `show` cannot handle tuples.
- [ ] `T_int` is not a valid value.

**Why:** the witness in the first argument determines the type
the second argument must have. `T_pair (T_int, T_string) : (int *
string) ty`, so the second argument must be `int * string`. `T_int
: int ty`, so the second argument must be `int`. The pair does
not match `int`, hence the type error in the second case.
:::

:::quiz mcq id=M08-L05-q2
`From staff` has type `emp query`. Why does the compiler reject
`Where (From staff, fun s -> s = "Eng")`?

- [x] The predicate accepts `string`, but the row type is `emp`.
- [ ] `Where` cannot follow `From`; the constructors must appear in
  a fixed order.
- [ ] `From` is not a valid starting point for a builder.
- [ ] Predicates are not allowed to use `=`.

**Why:** the type parameter of `query` tracks the *current* row
type. `From staff` is an `emp query`, so `Where`'s signature
`'row query * ('row -> bool) -> 'row query` forces the predicate to
accept `emp`. A `string -> bool` predicate fails to unify, and the
mistake is caught at compile time rather than at query execution.
:::

:::slide

## Activity

`show` *consumes* a value given its witness. Go the other way:
reusing the lecture's `ty`, write `default : type a. a ty -> a`
that *produces* a default value for the witnessed type: `0` for
`T_int`, `""` for `T_string`, `false` for `T_bool`, a pair of
defaults for `T_pair`, and `[]` for `T_list`.

:::

:::solution

:::slide

## Activity solution

```ocaml
let rec default : type a. a ty -> a = fun t ->
  match t with
  | T_int    -> 0
  | T_string -> ""
  | T_bool   -> false
  | T_pair (a, b) -> (default a, default b)
  | T_list _ -> []

let _ = default T_int                       (* = 0 *)
let _ = default (T_pair (T_int, T_string))  (* = (0, "") *)
```

- `default` runs the witness *backwards*: instead of reading a
  value it builds one, with the type fixed per case as in `show`.
- `T_list` ignores its element witness: the empty list has no
  element to default.

:::

:::

A code quiz:

:::quiz code id=M08-L05-q1
The witness GADT below covers three types: `String_t`, `Int_t`,
and `Bool_t`. Implement `convert3 : type a. a t -> a -> string`
over all three witnesses: strings rendered in quotes, ints with
`string_of_int`, bools with `string_of_bool`.

```ocaml
type _ t =
  | String_t : string t
  | Int_t    : int t
  | Bool_t   : bool t

let convert3 : type a. a t -> a -> string = fun t _ ->
  match t with
  | String_t -> failwith "not implemented"
  | Int_t    -> failwith "not implemented"
  | Bool_t   -> failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (convert3 Int_t 42 = "42") "int";
  check (convert3 String_t "hi" = "\"hi\"") "string";
  check (convert3 Bool_t true = "true") "bool true";
  check (convert3 Bool_t false = "false") "bool false";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let convert3 : type a. a t -> a -> string = fun t v ->
  match t with
  | String_t -> "\"" ^ v ^ "\""
  | Int_t    -> string_of_int v
  | Bool_t   -> string_of_bool v
```

The compiler refines `a` per branch. In the `Bool_t` case, `a =
bool`, so `v : bool`, and `string_of_bool v` produces the right
output.

:::

## What is next

:::slide

## What is next

Lecture 6: **hlists and witnesses**.

- Heterogeneous lists: mixed element types you can recurse over.
- Driving operations across them with a list of witnesses.
- The witness list behind `Format.printf`.

:::

The [next lecture](M08-L06-hlists-witnesses.html) takes the
typed-witness idea from this lecture and pushes it to
heterogeneous lists and the GADT machinery behind `printf`. After
that, the [tutorial](M08-L07-tutorial.html) brings together the
monad pattern from
lectures [1](M08-L01-option-monad.html)-[3](M08-L03-state-monad.html)
and the GADT pattern from
lectures [4](M08-L04-gadts-basics.html)-[6](M08-L06-hlists-witnesses.html):
a small expression language whose AST is a GADT (so ill-typed
programs cannot be constructed), evaluated through an option monad
(so runtime failures like division-by-zero short-circuit cleanly).

## Reading

- **Real World OCaml**, *More GADTs*:
  <https://dev.realworldocaml.org/gadts.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
