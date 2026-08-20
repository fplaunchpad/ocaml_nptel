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
cell seeded with a stub and a checker cell below it. For the
property and generator problems the checker prints `all tests
passed`; for the OUnit2 problems it prints the usual OUnit report
(`OK`). A reference solution sits below each problem behind a
collapsed *Reference solution* panel.

All of this uses only the testing tools from the module: `QCheck`
for properties and generators, and `OUnit2` for example-based unit
tests. Run each problem's first cell (the function under test)
before you run its checker.

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

Write a property `prop_clamp (lo, hi, x)` that captures the central
guarantee: whatever `x` is, the result lies within `[lo, hi]`. The
checker feeds it triples in which `lo <= hi` is already arranged, so
you do not need a precondition.

:::quiz code id=M09-L08-q1
Implement `prop_clamp : int * int * int -> bool`.

```ocaml
let prop_clamp (lo, hi, x) =
  failwith "not implemented"
```

```ocaml skip
let gen_clamp =
  QCheck.make
    QCheck.Gen.(map (fun (a, b, x) -> (min a b, max a b, x))
                  (triple int int int))
let test_clamp =
  QCheck.Test.make ~name:"clamp stays in range" ~count:1000 gen_clamp prop_clamp
let () =
  assert (QCheck_runner.run_tests ~colors:false [test_clamp] = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let prop_clamp (lo, hi, x) =
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

Write `prop_gcd_divides (a, b)` stating that `gcd a b` divides both
`a` and `b` exactly. The checker uses strictly positive inputs, so
you need not worry about zero or negatives.

:::quiz code id=M09-L08-q2
Implement `prop_gcd_divides : int * int -> bool`.

```ocaml
let prop_gcd_divides (a, b) =
  failwith "not implemented"
```

```ocaml skip
let gen_pos_pair =
  QCheck.make QCheck.Gen.(pair (int_range 1 1000) (int_range 1 1000))
let test_gcd =
  QCheck.Test.make ~name:"gcd divides both" ~count:1000 gen_pos_pair prop_gcd_divides
let () =
  assert (QCheck_runner.run_tests ~colors:false [test_gcd] = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let prop_gcd_divides (a, b) =
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

Write `prop_insert (x, xs)` that sorts `xs` first (so the
precondition holds for any random `xs`), inserts `x`, and then
checks **two** things: the result is sorted, and it is exactly one
element longer than the input.

:::quiz code id=M09-L08-q3
Implement `prop_insert : int * int list -> bool`.

```ocaml
let prop_insert (x, xs) =
  failwith "not implemented"
```

```ocaml skip
let gen_insert = QCheck.make QCheck.Gen.(pair int (list int))
let test_insert =
  QCheck.Test.make ~name:"insert keeps sorted, grows by one"
    ~count:1000 gen_insert prop_insert
let () =
  assert (QCheck_runner.run_tests ~colors:false [test_insert] = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let prop_insert (x, xs) =
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
`prop_merge (xs, ys)` that sorts both inputs, then compares `merge`
against that oracle.

:::quiz code id=M09-L08-q4
Implement `prop_merge : int list * int list -> bool`.

```ocaml
let prop_merge (xs, ys) =
  failwith "not implemented"
```

```ocaml skip
let gen_two = QCheck.make QCheck.Gen.(pair (list int) (list int))
let test_merge =
  QCheck.Test.make ~name:"merge equals sort of concatenation"
    ~count:1000 gen_two prop_merge
let () =
  assert (QCheck_runner.run_tests ~colors:false [test_merge] = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let prop_merge (xs, ys) =
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
Add test cases to `suite_binary`.

```ocaml
open OUnit2
let suite_binary =
  "to_binary" >::: [
    (* add cases here, e.g.
       "six" >:: (fun _ -> assert_equal ~printer:(fun s -> s) "110" (to_binary 6)); *)
  ]
```

```ocaml skip
let () = run_test_tt_main suite_binary
```
:::

:::solution

Reference solution:

```
open OUnit2
let suite_binary =
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
Add the five boundary cases to `suite_clamp`.

```ocaml
open OUnit2
let suite_clamp =
  "clamp" >::: [
    (* one case per path: below, above, inside, at lo, at hi *)
  ]
```

```ocaml skip
let () = run_test_tt_main suite_clamp
```
:::

:::solution

Reference solution:

```
open OUnit2
let suite_clamp =
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
```

Write a model-based property `prop_counter : cmd list -> bool`. Run
the command list against a real `Counter` and, in parallel, against
a *reference model* (a plain `int ref` you maintain yourself), then
check that `Counter.get` agrees with the model at the end.

:::quiz code id=M09-L08-q8
Implement `prop_counter`.

```ocaml
let prop_counter cmds =
  failwith "not implemented"
```

```ocaml skip
let gen_cmds =
  QCheck.make
    QCheck.Gen.(list_size (int_range 0 20)
                  (oneof [ return Incr; map (fun n -> Add n) (int_range 1 5) ]))
let test_counter =
  QCheck.Test.make ~name:"counter matches model" ~count:1000 gen_cmds prop_counter
let () =
  assert (QCheck_runner.run_tests ~colors:false [test_counter] = 0);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let prop_counter cmds =
  let c = Counter.create () in
  let model = ref 0 in
  let step cmd =
    match cmd with
    | Incr  -> Counter.incr c;   model := !model + 1
    | Add n -> Counter.add c n;  model := !model + n
  in
  List.iter step cmds;
  Counter.get c = !model
```

The model is the simplest thing that could possibly track the
counter's value: a bare `int ref`. `step` applies each command to
both the real counter and the model, and at the end the two must
agree. Because QCheck generates *sequences* of commands and shrinks
failing ones, this single property exercises far more interleavings
than you would write by hand, and reports the shortest command list
that breaks the implementation.

:::
