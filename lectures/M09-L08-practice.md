---
title: "Practice: writing tests"
lecture_no: 8
week: 9
duration_target_min: 0
concepts: [practice problems, property-based testing, unit testing, generators, model-based testing, QCheck, OUnit2]
keywords: [OCaml, practice, assignment, testing, QCheck, OUnit2, property, generator, model-based testing]
think_about_this: "In every other worksheet you write the function and the tests are given. Here it is the other way round: the function is given, and you write the tests. A good property is one that the correct function passes and a plausible wrong function fails. As you write each property, ask yourself: what bug would this catch?"
reading:
  - title: "Cornell CS3110, Testing"
    url: https://cs3110.github.io/textbook/chapters/correctness/test_debug.html
  - title: "QCheck, property-based testing for OCaml"
    url: https://github.com/c-cube/qcheck
---

# Practice: writing tests

This is a *Practice* chapter, not a Tutorial. There are no slides
and there is no video; it is a worksheet. The
[tutorial](M09-L07-tutorial.html) walked through a worked example on
screen. Here you solve the problems yourself, directly in the
browser.

Testing is the one place where the worksheet runs backwards: the
*function under test* is given to you in a cell, already correct,
and your job is to write the **tests**. Each problem has an editable
cell seeded with a stub and a checker cell below it. Each checker
prints `all tests passed` on success. The OUnit2 checkers also print
a test report. A reference solution sits below each problem behind
a collapsed *Reference solution* panel.

All of this uses only the testing tools from the module: `QCheck`
for properties and generators, and `OUnit2` for example-based unit
tests. Run each problem's first cell (the function under test)
before you run its checker.

The property and suite builders take the implementation to test as
an argument. Use that argument in your answer. The checker supplies
both correct and faulty implementations: a useful test must accept
the correct one and reject representative bugs.

The worksheet comes in three parts:

- **Part 1: properties** (Problems 1 to 4). Write a QCheck property
  for a given function: a single Boolean fact that should hold for
  every input.
- **Part 2: unit tests** (Problems 5 to 6). Write OUnit2 suites with
  example-based and boundary cases.
- **Part 3: generators and a model** (Problems 7 to 8). Write a
  generator that reaches the corners of its space, and a
  model-based property that pits an implementation against a
  reference.

## Part 1: properties

## Problem 1: a property for `clamp`

`clamp lo hi x` forces `x` into the range `[lo, hi]`. Here it is:

```ocaml
let clamp lo hi x =
  if x < lo then lo
  else if x > hi then hi
  else x
```

Write a property `prop_clamp clamp (lo, hi, x)` that captures the
central guarantee: whatever `x` is, the result lies within `[lo, hi]`.
The checker feeds it triples in which `lo <= hi` is already arranged,
so you do not need a precondition.

:::quiz code id=M09-L08-q1
Implement
`prop_clamp : (int -> int -> int -> int) -> int * int * int -> bool`.
Use the supplied `clamp` function; the checker also supplies faulty
implementations that your property should reject.

```ocaml
let prop_clamp clamp (lo, hi, x) =
  failwith "not implemented"
```

```ocaml skip
let gen_clamp =
  QCheck.make
    QCheck.Gen.(map (fun (a, b, x) -> (min a b, max a b, x))
                  (triple int int int))
let () =
  let test = QCheck.Test.make ~count:1000 gen_clamp (prop_clamp clamp) in
  QCheck.Test.check_exn ~rand:(Random.State.make [|42|]) test;
  if prop_clamp (fun _ _ x -> x) (0, 10, -1) then failwith "must detect a result below the range";
  if prop_clamp (fun _ _ x -> x) (0, 10, 11) then failwith "must detect a result above the range";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prop_clamp clamp (lo, hi, x) =
  let r = clamp lo hi x in
  lo <= r && r <= hi
```

The property runs `clamp` and asserts the single fact that matters:
the result is between `lo` and `hi` inclusive. It would catch a
`clamp` that forgot either bound (returning `x` unchanged when it is
too big, say). Note what it does *not* say: that `r = x` when `x` is
already in range. That is a second, independent property worth
adding.

:::

## Problem 2: a property for `gcd`

The greatest common divisor:

```ocaml
let rec gcd a b =
  if b = 0 then a else gcd b (a mod b)
```

Write `prop_gcd_divides gcd (a, b)` stating that `gcd a b` divides
both `a` and `b` exactly. The checker uses strictly positive inputs,
so you need not worry about zero or negatives.

:::quiz code id=M09-L08-q2
Implement
`prop_gcd_divides : (int -> int -> int) -> int * int -> bool`.
Use the supplied `gcd` function; the checker also supplies faulty
implementations that your property should reject.

```ocaml
let prop_gcd_divides gcd (a, b) =
  failwith "not implemented"
```

```ocaml skip
let gen_pos_pair =
  QCheck.make QCheck.Gen.(pair (int_range 1 1000) (int_range 1 1000))
let () =
  let test = QCheck.Test.make ~count:1000 gen_pos_pair (prop_gcd_divides gcd) in
  QCheck.Test.check_exn ~rand:(Random.State.make [|42|]) test;
  if prop_gcd_divides (fun _ _ -> 7) (6, 10) then failwith "must detect a non-divisor";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prop_gcd_divides gcd (a, b) =
  let g = gcd a b in
  a mod g = 0 && b mod g = 0
```

"Divides exactly" means the remainder is zero, so the property is
`a mod g = 0 && b mod g = 0`. This is a good example of a property
that is much easier to state than the function: we do not recompute
the gcd to check it, we check the defining relationship. (Restricting
the generator to positive inputs sidesteps `gcd a 0 = a` and the
sign conventions, which would otherwise need their own cases.)

:::

## Problem 3: a property for `insert`

`insert x l` inserts `x` into an already-sorted list, keeping it
sorted:

```ocaml
let rec insert x l =
  match l with
  | [] -> [x]
  | y :: ys -> if x <= y then x :: l else y :: insert x ys

(* a helper you may use in your property *)
let rec is_sorted = function
  | [] | [_] -> true
  | a :: (b :: _ as rest) -> a <= b && is_sorted rest
```

Write `prop_insert insert (x, xs)` that sorts `xs` first (so the
precondition holds for any random `xs`), inserts `x`, and then
checks **two** things: the result is sorted, and it is exactly one
element longer than the input.

:::quiz code id=M09-L08-q3
Implement
`prop_insert : (int -> int list -> int list) -> int * int list ->
bool`.
Use the supplied `insert` function; the checker also supplies faulty
implementations that your property should reject.

```ocaml
let prop_insert insert (x, xs) =
  failwith "not implemented"
```

```ocaml skip
(* Keep recursive student code within the browser's stack budget. *)
let gen_insert =
  QCheck.make QCheck.Gen.(pair int (list_size (int_range 0 30) int))
let () =
  let test = QCheck.Test.make ~count:1000 gen_insert (prop_insert insert) in
  QCheck.Test.check_exn ~rand:(Random.State.make [|42|]) test;
  if prop_insert (fun _ xs -> xs) (2, [1; 3]) then failwith "must detect a missing element";
  if prop_insert (fun x xs -> x :: xs) (2, [1; 3]) then failwith "must detect an unsorted result";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prop_insert insert (x, xs) =
  let sorted = List.sort compare xs in
  let result = insert x sorted in
  is_sorted result && List.length result = List.length sorted + 1
```

Sorting `xs` inside the property turns any random list into a valid
input, which is cheaper than generating sorted lists directly. The
conjunction states two independent facts: order is preserved, and no
element was lost or duplicated. The length check is what catches a
buggy `insert` that drops `x` on some path.

:::

## Problem 4: cross-checking `merge` against a reference

`merge` combines two sorted lists into one sorted list:

```ocaml
let rec merge xs ys =
  match xs, ys with
  | [], _ -> ys
  | _, [] -> xs
  | x :: xs', y :: ys' ->
      if x <= y then x :: merge xs' ys else y :: merge xs ys'
```

Instead of restating sortedness and the multiset property
separately, use a **reference oracle**: for sorted inputs,
`merge xs ys` should equal `List.sort compare (xs @ ys)`. Write
`prop_merge merge (xs, ys)` that sorts both inputs, then compares
`merge`
against that oracle.

:::quiz code id=M09-L08-q4
Implement
`prop_merge : (int list -> int list -> int list) -> int list * int
list -> bool`.
Use the supplied `merge` function; the checker also supplies faulty
implementations that your property should reject.

```ocaml
let prop_merge merge (xs, ys) =
  failwith "not implemented"
```

```ocaml skip
let gen_two =
  let open QCheck.Gen in
  let short_list = list_size (int_range 0 30) int in
  QCheck.make (pair short_list short_list)
let () =
  let test = QCheck.Test.make ~count:1000 gen_two (prop_merge merge) in
  QCheck.Test.check_exn ~rand:(Random.State.make [|42|]) test;
  if prop_merge (fun xs _ -> xs) ([1; 3], [2]) then failwith "must detect dropped elements";
  if prop_merge ( @ ) ([1; 3], [2; 4]) then failwith "must detect incorrect ordering";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prop_merge merge (xs, ys) =
  let xs = List.sort compare xs and ys = List.sort compare ys in
  merge xs ys = List.sort compare (xs @ ys)
```

`List.sort compare (xs @ ys)` is an obviously-correct (if slower)
way to get the merged result, so it makes a perfect oracle: any
disagreement is a bug in `merge`. This is the seed of model-based
testing, where the "reference" is a whole module rather than a
one-line expression (Problem 8).

:::

## Part 2: unit tests

## Problem 5: OUnit2 tests for `to_binary`

`to_binary n` renders a non-negative integer in base 2 as a string,
and rejects negative input:

```ocaml
let to_binary n =
  if n < 0 then invalid_arg "to_binary: negative"
  else if n = 0 then "0"
  else
    let rec go n acc =
      if n = 0 then acc
      else go (n / 2) (string_of_int (n mod 2) ^ acc)
    in
    go n ""
```

Fill in the OUnit2 suite below with example cases (use
`assert_equal ~printer` so a failure prints the strings) and one
`assert_raises` case for the negative input. The checker runs the
suite.

:::quiz code id=M09-L08-q5
Add test cases to `suite_binary to_binary`. Use the supplied function.
Include zero, one, a positive number with several binary digits,
and a negative-input exception case.

```ocaml
open OUnit2
let suite_binary to_binary =
  "to_binary" >::: [
    (* Add the requested cases, calling the supplied to_binary. *)
  ]
```

```ocaml skip
(* Run submitted cases in the grading runner's real OUnit context.
   Expected assertion failures from faulty implementations stay local. *)
let rec quiz_run_cases ctxt = function
  | OUnitTest.TestCase (_, f) ->
      (try f ctxt with
       | OUnitTest.Skip _ | OUnitTest.Todo _ ->
           failwith "complete every test; do not skip cases")
  | OUnitTest.TestLabel (_, t) -> quiz_run_cases ctxt t
  | OUnitTest.TestList ts -> List.iter (quiz_run_cases ctxt) ts

let quiz_rejects ctxt tests =
  try quiz_run_cases ctxt tests; false with
  | OUnitTest.OUnit_failure _ | Assert_failure _ -> true

let () =
  let submitted = suite_binary to_binary in
  if OUnitTest.test_case_count submitted < 4 then
    failwith "add the required test cases";
  let grading = OUnit2.("quiz" >::: [
    "correct implementation" >:: (fun ctxt -> quiz_run_cases ctxt submitted);
    "detect faulty implementations" >:: (fun ctxt ->
      if not (quiz_rejects ctxt (suite_binary (fun n -> if n = 0 then "" else to_binary n))) then
        failwith "include an assertion for zero";
      if not (quiz_rejects ctxt (suite_binary (fun n -> if n = 1 then "0" else to_binary n))) then
        failwith "include an assertion for one";
      if not (quiz_rejects ctxt (suite_binary (fun n -> if n > 1 then "0" else to_binary n))) then
        failwith "include an assertion for a larger positive input";
      if not (quiz_rejects ctxt (suite_binary (fun n -> if n < 0 then "0" else to_binary n))) then
        failwith "check that negative input raises";
      ());
  ]) in
  let failed = ref false in
  OUnit2.run_test_tt_main ~exit:(fun _ -> failed := true) grading;
  if !failed then failwith "submitted tests did not pass the checks";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
open OUnit2
let suite_binary to_binary =
  "to_binary" >::: [
    "zero" >:: (fun _ ->
      assert_equal ~printer:(fun s -> s) "0" (to_binary 0));
    "one" >:: (fun _ ->
      assert_equal ~printer:(fun s -> s) "1" (to_binary 1));
    "six" >:: (fun _ ->
      assert_equal ~printer:(fun s -> s) "110" (to_binary 6));
    "thirteen" >:: (fun _ ->
      assert_equal ~printer:(fun s -> s) "1101" (to_binary 13));
    "negative raises" >:: (fun _ ->
      assert_raises (Invalid_argument "to_binary: negative")
        (fun () -> to_binary (-1)));
  ]
```

The `~printer` turns a failure into a readable "expected `110`, got
..." message instead of an opaque "not equal". The `assert_raises`
case wraps the call in a thunk `(fun () -> ...)` so OUnit can run it
and catch the exception; the expected exception must match exactly,
including its string argument.

:::

## Problem 6: boundary tests for `clamp`

`clamp` again (same definition as Problem 1):

```ocaml
let clamp lo hi x =
  if x < lo then lo
  else if x > hi then hi
  else x
```

A property checks a fact over *random* inputs; unit tests are where
you nail down the **boundaries** by hand. Write an OUnit2 suite with
one case for each path through `clamp`: `x` below the range, above
it, strictly inside, exactly at `lo`, and exactly at `hi`.

:::quiz code id=M09-L08-q6
Add the five boundary cases to `suite_clamp clamp`: below, above,
inside, at the lower bound, and at the upper bound. Use the supplied
function and an interval with distinct bounds.

```ocaml
open OUnit2
let suite_clamp clamp =
  "clamp" >::: [
    (* Add the requested cases, calling the supplied clamp. *)
  ]
```

```ocaml skip
(* Run submitted cases in the grading runner's real OUnit context.
   Expected assertion failures from faulty implementations stay local. *)
let rec quiz_run_cases ctxt = function
  | OUnitTest.TestCase (_, f) ->
      (try f ctxt with
       | OUnitTest.Skip _ | OUnitTest.Todo _ ->
           failwith "complete every test; do not skip cases")
  | OUnitTest.TestLabel (_, t) -> quiz_run_cases ctxt t
  | OUnitTest.TestList ts -> List.iter (quiz_run_cases ctxt) ts

let quiz_rejects ctxt tests =
  try quiz_run_cases ctxt tests; false with
  | OUnitTest.OUnit_failure _ | Assert_failure _ -> true

let () =
  let submitted = suite_clamp clamp in
  if OUnitTest.test_case_count submitted < 5 then
    failwith "add the required test cases";
  let grading = OUnit2.("quiz" >::: [
    "correct implementation" >:: (fun ctxt -> quiz_run_cases ctxt submitted);
    "detect faulty implementations" >:: (fun ctxt ->
      if not (quiz_rejects ctxt (suite_clamp (fun lo hi x -> if x < lo then x else clamp lo hi x))) then
        failwith "check the below case";
      if not (quiz_rejects ctxt (suite_clamp (fun lo hi x -> if x > hi then x else clamp lo hi x))) then
        failwith "check the above case";
      if not (quiz_rejects ctxt (suite_clamp (fun lo hi x -> if lo < x && x < hi then lo else clamp lo hi x))) then
        failwith "check the interior case";
      if not (quiz_rejects ctxt (suite_clamp (fun lo hi x -> if lo < hi && x = lo then hi else clamp lo hi x))) then
        failwith "check the lower boundary case";
      if not (quiz_rejects ctxt (suite_clamp (fun lo hi x -> if lo < hi && x = hi then lo else clamp lo hi x))) then
        failwith "check the upper boundary case";
      ());
  ]) in
  let failed = ref false in
  OUnit2.run_test_tt_main ~exit:(fun _ -> failed := true) grading;
  if !failed then failwith "submitted tests did not pass the checks";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
open OUnit2
let suite_clamp clamp =
  "clamp" >::: [
    "below"  >:: (fun _ -> assert_equal ~printer:string_of_int 0  (clamp 0 10 (-5)));
    "above"  >:: (fun _ -> assert_equal ~printer:string_of_int 10 (clamp 0 10 99));
    "inside" >:: (fun _ -> assert_equal ~printer:string_of_int 7  (clamp 0 10 7));
    "at lo"  >:: (fun _ -> assert_equal ~printer:string_of_int 0  (clamp 0 10 0));
    "at hi"  >:: (fun _ -> assert_equal ~printer:string_of_int 10 (clamp 0 10 10));
  ]
```

Five cases for the three branches plus the two boundary values where
off-by-one bugs hide (`<` versus `<=`). The two "at" cases are the
ones a property over random integers would almost never hit, which
is exactly why hand-written boundary tests earn their keep.

:::

## Part 3: generators and a model

## Problem 7: a generator that reaches the corners

A property is only as good as the inputs it sees. Write a generator
`gen_signed : int QCheck.Gen.t` that produces a healthy mix of
**negative, zero, and positive** integers, with zero appearing often
enough to matter (a plain `int` generator almost never returns
exactly `0`). The checker draws 300 samples and insists all three
kinds show up.

:::quiz code id=M09-L08-q7
Replace the placeholder with a generator that visits all three
corners. (`QCheck.Gen.oneof_weighted` and `QCheck.Gen.return` are
useful here.)

```ocaml
let gen_signed : int QCheck.Gen.t =
  QCheck.Gen.int  (* placeholder: almost never returns 0 or negatives *)
```

```ocaml skip
let () =
  let samples = QCheck.Gen.generate ~n:300 gen_signed in
  assert (List.exists (fun x -> x < 0) samples);
  assert (List.exists (fun x -> x = 0) samples);
  assert (List.exists (fun x -> x > 0) samples);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let gen_signed : int QCheck.Gen.t =
  QCheck.Gen.oneof_weighted [
    (1, QCheck.Gen.return 0);
    (3, QCheck.Gen.int_range (-1000) (-1));
    (3, QCheck.Gen.int_range 1 1000);
  ]
```

`oneof_weighted` picks one of the listed generators according to its
weight, so `return 0` guarantees zero turns up roughly one draw in
seven, while the two ranges supply negatives and positives. This is
the same idea as seeding a float generator with `nan` and `infinity`:
if a value is special to the specification, the generator must
actually produce it.

:::

## Problem 8: a model-based property for a counter

Here is a tiny stateful `Counter` and a command type describing the
operations a client can perform:

```ocaml
module Counter = struct
  type t = int ref
  let create () = ref 0
  let incr c = c := !c + 1
  let add c n = c := !c + n
  let get c = !c
end

type cmd = Incr | Add of int

type 'a counter_ops = {
  create : unit -> 'a;
  incr : 'a -> unit;
  add : 'a -> int -> unit;
  get : 'a -> int;
}

let counter_ops = {
  create = Counter.create; incr = Counter.incr;
  add = Counter.add; get = Counter.get;
}
```

Write a model-based property
`prop_counter : 'a counter_ops -> cmd list -> bool`. Run the command
list against a real `Counter` and, in parallel, against a
*reference model* (a plain `int ref` you maintain yourself), then
check that the supplied `ops.get` agrees with the model at the end.

:::quiz code id=M09-L08-q8
Implement `prop_counter ops cmds`. Use `ops.create`, `ops.incr`,
`ops.add`, and `ops.get` to exercise the supplied counter, comparing
its final value with your model. The checker also supplies faulty
counter operations.

```ocaml
let prop_counter ops cmds =
  failwith "not implemented"
```

```ocaml skip
let gen_cmds =
  QCheck.make
    QCheck.Gen.(list_size (int_range 0 20)
                  (oneof [ return Incr; map (fun n -> Add n) (int_range 1 5) ]))
let () =
  let test = QCheck.Test.make ~count:1000 gen_cmds (prop_counter counter_ops) in
  QCheck.Test.check_exn ~rand:(Random.State.make [|42|]) test;
  if prop_counter { counter_ops with incr = (fun _ -> ()) } [Incr] then
    failwith "must detect an ignored increment";
  if prop_counter { counter_ops with add = (fun _ _ -> ()) } [Add 3] then
    failwith "must detect an ignored addition";
  if prop_counter { counter_ops with create = (fun () -> ref 1) } [] then
    failwith "must check the initial counter value";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let prop_counter ops cmds =
  let c = ops.create () in
  let model = ref 0 in
  let step cmd =
    match cmd with
    | Incr  -> ops.incr c;  model := !model + 1
    | Add n -> ops.add c n; model := !model + n
  in
  List.iter step cmds;
  ops.get c = !model
```

The model is the simplest thing that could possibly track the
counter's value: a bare `int ref`. `step` applies each command to
both the real counter and the model, and at the end the two must
agree. Because QCheck generates *sequences* of commands and shrinks
failing ones, this single property exercises far more interleavings
than you would write by hand, and reports the shortest command list
that breaks the implementation.

:::
