---
title: "Property-based testing with QCheck"
lecture_no: 5
week: 9
duration_target_min: 35
concepts: [property-based testing, QCheck, generators, shrinking, properties, invariants, equational reasoning, custom arbitraries, input space, balanced trees]
keywords: [OCaml, QCheck, property-based testing, PBT, QuickCheck, generators, shrinking, counterexample, sorted array, balanced BST, red-black tree, custom arbitrary, input space]
activity_question: "A colleague's [dedup : int list -> int list] passes a single QCheck property on 1000 random inputs. Is the implementation necessarily correct? What other properties would you demand before you believe them?"
think_about_this: "Why is property-based testing more useful in a functional language than in an imperative one? What is it about purity and equational reasoning that makes properties easier to *state*, never mind check?"
reading:
  - title: "QCheck on GitHub (README, tutorial, API)"
    url: https://github.com/c-cube/qcheck
  - title: "QCheck API documentation"
    url: https://c-cube.github.io/qcheck/
  - title: "Hughes, QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs (2000)"
    url: https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf
---

# Property-based testing with QCheck


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Property-based testing with QCheck</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[Lecture 4](M09-L04-unit-testing.html) gave you OUnit2 and a habit
for it: pick an input, write down its expected output, compare,
report. The hand-written assertions in `test_lifo` exercise
a stack on three specific inputs out of the infinite number of
ways someone might use a stack. The five `max3` assertions in
[the opening lecture](M09-L01-why-test-typed-code.html#a-small-concrete-demonstration)
exercise the function on five specific triples out of the trillions
of `int * int * int` values; the
[test-design audit](M09-L03-test-design.html) showed that those
five miss one of the function's four paths entirely.

That gap is the topic of this lecture. There is a fundamental
limit to unit testing: *you can only check the cases you thought
of.* Even the disciplined version of "thinking of cases", the
[boundary-and-partition design](M09-L03-test-design.html) you
practised two lectures ago, still hand-picks one representative
per region. A bug that only fires on an input you did not
consider sits quietly in the code, passing your test suite,
until a user finds it.

Property-based testing closes that gap by inverting the
relationship between the test author and the inputs. Instead of
writing down a list of (input, expected output) pairs, you write
down a *property*: a relationship between inputs and outputs that
should hold *for any* input. A property-based testing library
then *generates* inputs and checks the property on each one.
A few hundred random inputs cost you almost nothing and exercise
corners you would never have written by hand.

This lecture is the introduction to the OCaml flavour of that
idea: the [QCheck](https://github.com/c-cube/qcheck) library.

:::slide

## What this lecture covers

- The **limit of unit testing**: you only check the cases you
  thought of.
- **Property-based testing (PBT)**: write a property, let the
  library generate inputs.
- **QCheck**, OCaml's PBT library: generators, properties,
  shrinking.
- Worked examples on **`List.rev`** and **`List.sort`**.
- Why **functional programming and PBT fit together** especially
  well.

:::

## The limit of hand-written tests

Let us sharpen the problem. We have a function you have written
at least twice in this course, recursively in the functions
module and via `fold` in the higher-order module; here it
returns as a *test subject*:

```ocaml
let rev xs =
  let rec go acc = function
    | [] -> acc
    | x :: rest -> go (x :: acc) rest
  in
  go [] xs
```

We write a unit-test suite for it:

```ocaml
let () =
  assert (rev [] = []);
  assert (rev [1] = [1]);
  assert (rev [1; 2] = [2; 1]);
  assert (rev [1; 2; 3] = [3; 2; 1]);
  print_endline "rev tests passed"
```

Four assertions. The function passes all four. Are we done?

Maybe. The implementation is right. But we tested it on four
inputs whose answer was obvious to write by hand. We did not test
it on:

- a list of length 100,
- a list with duplicates,
- a list of strings (instead of `int`s),
- a list where every element is the same,
- a list whose elements are pairs.

In each of these, the function would have worked, but we did not
*check*. And if the implementation had a subtle bug, that bug
might only fire on, say, lists of length 100 or more (a recursion-
depth issue, perhaps), or on lists with duplicates (a hash-set
bug). Our four-case test suite would not catch it.

The right reaction is not "write fifty more cases." That is
exhausting and quickly hits diminishing returns: there are
infinitely many lists, and you do not know which finite subset is
representative. The right reaction is to step back and ask: what
should *be* true of `rev`, no matter what list we apply it to?
And then let a machine generate the lists.

:::slide

## The limit of unit testing

```ocaml
let () =
  assert (rev [] = []);
  assert (rev [1] = [1]);
  assert (rev [1; 2] = [2; 1]);
  assert (rev [1; 2; 3] = [3; 2; 1]);
  print_endline "four cases pass"
```

- Four cases. All pass.
- Did we check length 100? Duplicates? `string list`? Pairs?
- The right step is not "write fifty more cases."
- The right step is: state a *property* and let the library
  generate inputs.

:::

## Properties: what should be true of `rev`?

A *property* is a statement that should hold for *every* input of
some shape. For `rev`, three obvious properties:

1. **Involution**: `rev (rev xs) = xs` for every list `xs`.
2. **Length preservation**: `List.length (rev xs) = List.length xs`.
3. **Permutation**: the multiset of elements is unchanged.

The first is the most striking. It captures something that has to
be true *by the meaning* of `rev`: reversing twice gets you back.
Notice that we did not write down *what* `rev` produces; we wrote
down a *relationship* the output bears to the input. This is a
key feature of properties: they often abstract over the answer.
You do not say "rev of `[1; 2; 3]` is `[3; 2; 1]`"; you say "rev
is self-inverse." The first form needs you to pick an input and
work out the answer. The second form does not.

The second property, length preservation, is a *consequence* of
the contract of `rev`: it rearranges elements, it does not add or
drop any. If a buggy `rev` ever returned a list of a different
length, this property would catch it without us having to write
down the exact answer.

The third, permutation, is even more specific: it says the
*elements* are the same, just in a different order. Combined with
length preservation, it pins down a much smaller space of
possible behaviours. Smaller, but not a single point: the
identity function preserves the multiset and is its own inverse,
so it passes all three properties and is clearly not `rev`. What
none of them mention is *order*; a property that does, say
relating `rev (x :: xs)` to `rev xs @ [x]`, is what separates
`rev` from the impostors. Properties constrain the behaviour;
they rarely characterise it, and noticing which behaviours
slip through is part of the craft.

:::slide

## Properties of `rev`

For *every* list `xs`:

1. `rev (rev xs) = xs`  (involution)
2. `List.length (rev xs) = List.length xs`  (length preserved)
3. The multiset of elements is unchanged  (permutation)

- A property is a statement that should hold for *every* input.
- Often abstracts over the answer ("self-inverse" rather than
  "exactly that list").
- Several properties together approximate a specification.

:::

## QCheck: the API in one example

Now the OCaml part. The [QCheck](https://github.com/c-cube/qcheck)
library lets us write the involution property like this:

```ocaml
let test_rev_involutive =
  QCheck.Test.make
    ~name:"rev is involutive"
    ~count:1000
    QCheck.(list int)
    (fun xs -> rev (rev xs) = xs)
```

Five pieces:

- **`QCheck.Test.make`** is the constructor for a property-based
  test. It returns a `QCheck.Test.t` you can hand to the runner.
- **`~name`** is the display string in the output. Same role as
  the name on an OUnit2 case.
- **`~count`** is how many random inputs to try. Default is 100;
  we bumped it to 1000 because cheap.
- **`QCheck.(list int)`** is a *generator*: a recipe for producing
  random `int list`s. `QCheck.int` is a generator for random ints;
  `QCheck.list g` lifts a generator `g` over elements into a
  generator for lists of elements.
- **`(fun xs -> ...)`** is the *property*: a function that
  receives a generated input and returns a `bool`. `true` means
  the property held; `false` means it failed.

To run the test:

```ocaml
let _ = QCheck_runner.run_tests ~colors:false [test_rev_involutive]  (* = 0 *)
```

That form works right here in the page's cells: the runner's
report lands in the cell's output pane, and the call returns `0`
when everything passed. (`~colors:false` because the output pane
is not a terminal: without it the report arrives wrapped in the
ANSI colour codes meant for one, and they render as garbage.) In
a `dune` project you would instead end the test file with the
variant below, which additionally parses command-line flags and
exits with the right status code:

```text
let () =
  QCheck_runner.run_tests_main [test_rev_involutive]
```

`QCheck_runner.run_tests_main` is the entry point; it parses CLI
flags (so you get `-v`, `-s` for seed, etc. for free) and prints
results. A passing run reports something like:

```
random seed: 42
Law rev is involutive: OK (passed 1000 tests).
```

A thousand random lists, all satisfying `rev (rev xs) = xs`. We
have not exhausted the input space (no machine can; there are
infinitely many lists), but the law has held against 1000
adversaries we did not pick, which is a stronger signal than four
hand-picked cases.

:::slide

## QCheck in one example

```ocaml
let test_rev_involutive =
  QCheck.Test.make
    ~name:"rev is involutive"
    ~count:1000
    QCheck.(list int)
    (fun xs -> rev (rev xs) = xs)

let _ = QCheck_runner.run_tests ~colors:false [test_rev_involutive]  (* = 0 *)
```

- `QCheck.Test.make` constructs the test.
- Generator: `QCheck.(list int)` produces random `int list`s.
- Property: a function `'a -> bool`. Returns `true` if the input
  satisfies the law.

:::

## When a property fails

A passing report is only half the story; the reason PBT earns its
keep is what happens when the property is *false*. Let us assert
a false belief on purpose: that every list is already sorted.

```ocaml
let test_all_sorted =
  QCheck.Test.make
    ~name:"every list is already sorted"
    ~count:1000
    QCheck.(list int)
    (fun xs -> xs = List.sort compare xs)
```

```ocaml
let _ = QCheck_runner.run_tests ~colors:false [test_all_sorted]  (* = 1 *)
```

Run it. QCheck needs only a handful of draws to find a list that
is not sorted, and the report names the offender (the exact
values vary with the random seed):

```
--- Failure ------------------------------------------------------

Test every list is already sorted failed (66 shrink steps):

[0; -1]

failure (1 tests failed, 0 tests errored, ran 1 tests)
```

Two things deserve attention. First, the failing input is
printed, which is why a generator carries a *printer* alongside
the random producer. Second, look how *small* it is: the first
unsorted list QCheck stumbled on was almost certainly dozens of
elements long, but after "66 shrink steps" it reported a
two-element list, the smallest list that is not sorted. That
minimisation step is called *shrinking*, and it has its own
section later in this lecture.
The return value `1` is the number of failed tests, which is what
makes the `dune` exit-code wiring work.

:::slide

## When a property fails

```ocaml
let test_all_sorted =
  QCheck.Test.make
    ~name:"every list is already sorted"
    ~count:1000
    QCheck.(list int)
    (fun xs -> xs = List.sort compare xs)

let _ = QCheck_runner.run_tests ~colors:false [test_all_sorted]  (* = 1 *)
```

- A deliberately *false* property: QCheck catches it in a few
  draws.
- The report prints the failing input, already minimised: `[0; -1]`.
  - How it got that small: *shrinking*, later in this lecture.
- `run_tests` returns the number of failed tests.

:::

## Generators

The library's interesting work is in its generators. A
[`QCheck.arbitrary 'a`](https://c-cube.github.io/qcheck/) is a
value bundling three things: a random producer of `'a` values, a
*printer* (for failure messages), and a *shrinker* (more on
shrinking in a moment).

The basic generators are exactly what you expect:

- `QCheck.int`: a uniformly random `int`.
- `QCheck.small_int`: small positive `int`s (handy for sizes).
- `QCheck.bool`: `true` or `false`.
- `QCheck.string`: a random string.
- `QCheck.float`: a random `float`, including `infinity` and `nan`
  (but only rarely; do not count on a run hitting them).

And combinators that build bigger generators out of smaller ones:

- `QCheck.list g`: a list of values from `g`.
- `QCheck.array g`: an array of values from `g`.
- `QCheck.pair g1 g2`: a pair.
- `QCheck.option g`: `None` half the time, `Some (g ())` the rest.
- `QCheck.oneof [g1; g2; ...]`: pick one of the given generators.
- `QCheck.map f g`: produce `f (g ())`.

These compose: `QCheck.(list (pair int string))` is a generator for
random lists of (int, string) pairs.

```ocaml
let gen_int_pair_list : (int * string) list QCheck.arbitrary =
  QCheck.(list (pair int string))
```

Each test you write picks a generator that matches the type of
input the function under test expects, and that is most of the
configuration work.

:::slide

## Generators

| Generator | Produces |
| --- | --- |
| `QCheck.int` | uniform `int` |
| `QCheck.small_int` | small positive `int` |
| `QCheck.bool` | `true` / `false` |
| `QCheck.string` | random string |
| `QCheck.float` | random `float` (incl. `nan`, `infinity`, rarely) |

Combinators:

- `list g`, `array g`, `pair g1 g2`, `option g`
- `oneof [g1; g2; ...]`, `map f g`

These compose: `QCheck.(list (pair int string))`.

:::

## Properties are pure functions

Notice that the property `fun xs -> rev (rev xs) = xs` is a
*pure* OCaml function. No state, no IO, just an input and a
boolean output. QCheck does not need any special syntax; it just
calls the function 1000 times on 1000 different inputs.

This is exactly the reason that property-based testing fits so
neatly into functional programming. In an imperative language,
properties have to navigate state: you set up the world, you run
the function, you compare *the world before and after*. In OCaml,
the function takes its arguments and returns its result; the
property is the relationship between the two, expressible as a
single expression. There is no setup, no teardown, no shared
state.

Better still: in a pure language, the property *literally is the
spec*. The OCaml expression `rev (rev xs) = xs` is the same
mathematical statement a textbook would write. You can read it
aloud, you can manipulate it equationally, you can prove things
about it. PBT inherits this clarity from the language. In
Python, where everything could mutate, the same property reads
"call rev on xs, save the result; call rev on that, save *that*
result; compare to the original xs; oh also check that nothing
secretly mutated xs along the way."

:::slide

## Why FP makes PBT natural

A property is a pure function `'a -> bool`.

- **No state**: no setup-teardown ceremony.
- **No mutation**: the input cannot be changed by the call.
- **Equational**: `rev (rev xs) = xs` *is* the spec, in code.

In imperative languages PBT works, but you spend energy fighting
mutation. Here, the property reads exactly like the textbook law.

:::

## Negative properties: preconditions

Sometimes a property only holds for *some* inputs, not all. For
example, "the head of a list equals its first element" is true
only for non-empty lists. QCheck supports this with
*preconditions* via `QCheck.assume`:

```ocaml
let test_hd_first =
  QCheck.Test.make
    ~name:"hd returns first element"
    QCheck.(list int)
    (fun xs ->
       QCheck.assume (xs <> []);
       List.hd xs = List.nth xs 0)
```

```ocaml
let _ = QCheck_runner.run_tests ~colors:false [test_hd_first]  (* = 0 *)
```

When the generated input fails the precondition, QCheck *skips*
that input and generates another. The case still counts as
checked but does not exercise the property; the run above
passes with every empty list silently discarded. If too many
inputs fail the precondition (because the generator produces
them rarely), QCheck gives up and warns you. That is your
signal to write a *custom* generator that produces only inputs
in the precondition's range, rather than rejecting most of what
the default generator makes.

:::slide

## Preconditions

```ocaml
let test_hd_first =
  QCheck.Test.make ~name:"hd returns first"
    QCheck.(list int)
    (fun xs ->
       QCheck.assume (xs <> []);
       List.hd xs = List.nth xs 0)

let _ = QCheck_runner.run_tests ~colors:false [test_hd_first]  (* = 0 *)
```

- `QCheck.assume` skips inputs that fail the precondition.
- If too many skips, QCheck warns: write a custom generator
  instead.

:::

## A second example: `List.sort`

The sort property is richer because "sorted" by itself is too weak
to pin down behaviour. A function that returns the empty list on
every input is "sorted" trivially. To capture `List.sort` we need
*two* properties: the output is sorted, AND the output is a
permutation of the input.

```ocaml
let is_sorted xs =
  let rec go = function
    | [] | [_] -> true
    | a :: b :: rest -> a <= b && go (b :: rest)
  in
  go xs

let same_elements xs ys =
  let count x l = List.length (List.filter (( = ) x) l) in
  List.length xs = List.length ys &&
  List.for_all (fun x -> count x xs = count x ys) xs

let test_sort_sorted =
  QCheck.Test.make
    ~name:"sort produces a sorted list"
    QCheck.(list int)
    (fun xs -> is_sorted (List.sort compare xs))

let test_sort_permutation =
  QCheck.Test.make
    ~name:"sort preserves the multiset"
    QCheck.(list_small int)
    (fun xs -> same_elements (List.sort compare xs) xs)

let test_sort_length =
  QCheck.Test.make
    ~name:"sort preserves length"
    QCheck.(list int)
    (fun xs -> List.length (List.sort compare xs) = List.length xs)
```

`same_elements` checks multiset equality by *counting*: the two
lists have the same length, and every element of the first occurs
the same number of times in both. Counting keeps the checker
independent of the function under test. (The tempting shortcut,
sort both lists and compare, uses a sort to specify sort; fine
when the yardstick sort is one you already trust, but the
count-based checker dodges the question entirely.) The checker is
quadratic, so the permutation test draws its inputs from
`QCheck.(list_small int)`, a variant of `list` that keeps the
generated lists modest; `QCheck.(list int)` happily produces
lists thousands of elements long.

Three properties. Each one would be satisfied by some wrong
function, but a function that satisfies *all three* is hard
to write incorrectly.

- "produces a sorted list" by itself is satisfied by `fun _ -> []`.
- "preserves the multiset" by itself is satisfied by `fun xs -> xs`
  (the identity).
- "preserves length" by itself is satisfied by *many* functions
  (the identity, `rev`, ...).

Together, only sort-like functions survive. All three pass
against `List.sort`:

```ocaml
let _ = QCheck_runner.run_tests ~colors:false
    [test_sort_sorted; test_sort_permutation; test_sort_length]  (* = 0 *)
```

:::slide

## Sort property 1: the output is sorted

```ocaml
let is_sorted xs =
  let rec go = function
    | [] | [_] -> true
    | a :: b :: rest -> a <= b && go (b :: rest)
  in
  go xs

let test_sort_sorted =
  QCheck.Test.make ~name:"sorted"
    QCheck.(list int)
    (fun xs -> is_sorted (List.sort compare xs))
```

- `is_sorted`: every adjacent pair is in order.
- Alone, this test cannot reject every wrong sort:
  - `fun _ -> []` passes it; the empty list is sorted.

:::

:::slide

## Sort property 2: the output is a permutation

```ocaml
let same_elements xs ys =
  let count x l = List.length (List.filter (( = ) x) l) in
  List.length xs = List.length ys &&
  List.for_all (fun x -> count x xs = count x ys) xs

let test_sort_permutation =
  QCheck.Test.make ~name:"permutation"
    QCheck.(list_small int)
    (fun xs -> same_elements (List.sort compare xs) xs)
```

- `same_elements`: same length, every element occurs equally
  often in both
  - counting keeps the checker independent of the sort under
    test.
  - quadratic, so generate with `list_small`.
- Alone, this test cannot reject every wrong sort:
  - the identity `fun xs -> xs` passes it; any list is a
    permutation of itself.

:::

:::slide

## Sort property 3: the length is preserved

```ocaml
let test_sort_length =
  QCheck.Test.make ~name:"length"
    QCheck.(list int)
    (fun xs -> List.length (List.sort compare xs) = List.length xs)

let _ = QCheck_runner.run_tests ~colors:false
    [test_sort_sorted; test_sort_permutation; test_sort_length]  (* = 0 *)
```

- Alone, this test passes many wrong sorts (the identity,
  `rev`, ...).
- **Together**, the three properties reject them all:
  - sorted + permutation + length: only sort-like functions
    survive.

:::

This is the *art* of property-based testing: choosing a small set
of properties whose conjunction approximates the specification.
For most data-structure operations, three or four properties
suffice. For more complex code (a parser, a query planner), you
might write a dozen. Each property is small; each is independent;
each contributes one constraint.

## Shrinking: finding the smallest counterexample

The most important feature of QCheck (and of QuickCheck more
generally) is *shrinking*. When the library finds an input that
fails the property, it does not just report "this 17-element list
broke things." It actively tries to *minimise* the failing input:
"can I delete one element and still see the failure? Can I delete
another? Can I replace this element with a smaller one?" The
result is the smallest failing input the library can find,
typically a one or two element list, which is far easier to
debug.

Let us see this in action with a *deliberately buggy* sort. A
common rookie mistake: forgetting the singleton case in a merge
sort. (`merge`, combining two sorted lists into one sorted list,
is the standard helper.)

```ocaml
let rec merge xs ys = match xs, ys with
  | [], l | l, [] -> l
  | x :: xs', y :: ys' ->
    if x <= y then x :: merge xs' ys else y :: merge xs ys'

let rec bad_sort = function
  | [] -> []
  (* missing case: | [x] -> [x] *)
  | xs ->
    let n = List.length xs / 2 in
    let left = List.filteri (fun i _ -> i < n) xs in
    let right = List.filteri (fun i _ -> i >= n) xs in
    merge (bad_sort left) (bad_sort right)
```

If `xs` has length 1, then `n = 0`, `left = []`, `right = xs`. So
`bad_sort [x]` calls `bad_sort []` (returns `[]`) and `bad_sort
[x]` (recurses), forever. Stack overflow on any non-empty input.

We point the "sorted" property from before at `bad_sort`:

```ocaml
let test_bad_sort_sorted =
  QCheck.Test.make
    ~name:"bad_sort produces a sorted list"
    QCheck.(list int)
    (fun xs -> is_sorted (bad_sort xs))

let _ = QCheck_runner.run_tests ~colors:false [test_bad_sort_sorted]  (* = 1 *)
```

Run it. QCheck explores random lists. Some are empty (returns
empty, trivially sorted). Most are non-empty. The first non-empty
list it generates causes a stack overflow. QCheck catches the
exception, marks the test errored, and starts shrinking.

Shrinking proceeds roughly as follows:

1. The original failing input was, say, `[3; -5; 0; 17; 42]` (5
   elements).
2. Can we drop one? Try `[-5; 0; 17; 42]` (drop first). Fails.
   Smaller input. Continue.
3. Drop another. Try `[0; 17; 42]`. Fails. Keep going.
4. Down to `[17; 42]`. Fails. Smaller.
5. Down to `[42]`. Fails. Smaller still.
6. Down to `[]`. *Passes* (`bad_sort` handles the empty case). So
   `[]` is not a counterexample: some one-element list is the
   minimum. The shrinker also shrinks the surviving *element*
   towards zero, and reports `[0]`.

The output looks something like (the seed and the step count
vary from run to run):

```
random seed: 449586813

=== Error ======================================================

Test bad_sort produces a sorted list errored on (68 shrink steps):

[0]

exception Stack overflow

================================================================
failure (0 tests failed, 1 tests errored, ran 1 tests)
```

Three characters of input. The bug is *obvious* now: "a single-
element list overflows the stack." Without shrinking, the original
failing input would have been dozens of elements wide, and the bug
would have been buried in irrelevant noise. The shrinker is what
makes PBT *debuggable*.

:::slide

## A deliberately buggy sort

```ocaml
let rec merge xs ys = match xs, ys with
  | [], l | l, [] -> l
  | x :: xs', y :: ys' ->
    if x <= y then x :: merge xs' ys else y :: merge xs ys'

let rec bad_sort = function
  | [] -> []
  (* missing case: | [x] -> [x] *)
  | xs ->
    let n = List.length xs / 2 in
    let left = List.filteri (fun i _ -> i < n) xs in
    let right = List.filteri (fun i _ -> i >= n) xs in
    merge (bad_sort left) (bad_sort right)
```

- The `[x]` case is missing: `left = []`, `right = [x]`
  - so `bad_sort [x]` recurses on `[x]` forever.
- Stack overflow on any non-empty input.

:::

:::slide

## Shrinking finds the minimal counterexample

```ocaml
let test_bad_sort_sorted =
  QCheck.Test.make
    ~name:"bad_sort produces a sorted list"
    QCheck.(list int)
    (fun xs -> is_sorted (bad_sort xs))

let _ = QCheck_runner.run_tests ~colors:false [test_bad_sort_sorted]  (* = 1 *)
```

- Random input that triggered the bug was dozens of elements wide.
- Shrinker repeatedly minimises until further reduction passes.
- Reported counterexample: `[0]`. Bug is obvious.

:::

The shrinker is built into the library's generators. When you use
`QCheck.(list int)`, the resulting `arbitrary` value carries a
shrinking strategy: drop elements, replace elements with smaller
ones. (A custom generator built with `QCheck.make` is the
exception: it carries *no* shrinker unless you pass one. A note
on that later in the lecture.)

For the level of this lecture, you almost never need to write a
shrinker by hand. The built-in generators come with reasonable
ones, and your time is better spent on properties than on
shrinkers. We mention shrinking because it is what makes PBT
output *actionable*, but the day-to-day reality is "use the
default shrinker, point at your property, watch QCheck do the
work."

A question to keep in the back of your mind: how do you know
QCheck is exploring inputs *usefully*? If 90 percent of the
lists it generated were length 0, a passing run would mean very
little. We return to this later in the lecture, under
"Beyond the built-in generators".

## Equational reasoning gives properties for free

Coming back to *why* this works so naturally in OCaml: in a pure
functional language, every law you can state in a textbook is a
property you can hand to QCheck.

For lists:

- `List.length (xs @ ys) = List.length xs + List.length ys`
- `List.rev (xs @ ys) = List.rev ys @ List.rev xs`
- `List.map f (List.map g xs) = List.map (fun x -> f (g x)) xs`
- `List.fold_left f a (xs @ ys) = List.fold_left f (List.fold_left f a xs) ys`

For functions:

- `(fun x -> f (g x)) = compose f g`
- `id (f x) = f x`
- `f (id x) = f x`

For numeric operators:

- `x + y = y + x`
- `(x + y) + z = x + (y + z)`

Each one is a single line of OCaml turned into a QCheck property.
The equational nature of functional code means *the laws ARE the
properties*. In an imperative language you would write
"compute lhs, store it; compute rhs, store it; compare." Here
the law is itself executable.

This is the deepest reason testing-by-property is more popular in
the FP world than elsewhere. The language gives you a vocabulary
of pure functions, and the testing library hands that vocabulary
straight to a fuzzer.

## Beyond the built-in generators

What we have so far is enough to write *interesting* properties
for any pure function whose input fits one of QCheck's built-in
generators (lists of ints, strings, pairs, options). Two pieces
lie beyond this lecture.

First, **steering the distribution**. "1000 random lists" hides
an important question: *which* 1000? For a sorter, the telling
inputs are the already-sorted list, the reverse-sorted list,
lists full of ties, the empty and one-element lists; a uniformly
random `(list int)` visits all of these rarely, so a boundary
bug can survive 1000 trials. When the bugs you care about live
in a corner of the input space, you build a generator that
visits that corner on purpose, out of the `QCheck.Gen`
combinators, and you check your work with `QCheck.collect`,
which reports the distribution a generator actually produces.
The [tutorial](M09-L07-tutorial.html) builds one such generator
for a recursive expression type; the QCheck documentation
covers the rest of that toolkit.

Second, **state**. Everything we tested today is a pure
function. Much of real software is a stateful API: a queue you
enqueue to and dequeue from, where each operation's behaviour
depends on everything that came before. Writing properties for
that needs one more idea, and it is the topic of the
[next lecture](M09-L06-model-based-testing.html).

## Shrinking, in depth

We introduced shrinking informally with the `bad_sort` example: a
failing multi-element list got shrunk to a 1-element list, and the
bug was obvious in the small witness. Now we look at how the
shrinker works.

### Why shrinking matters

When a generator finds a counterexample, it almost never finds
the *minimal* one. The first failing list might have 7 elements,
6 of which are irrelevant noise. The reported failure should be
"`[3]`", not "`[42; -17; 0; 3; 99; -2; 8]`". The difference is
the difference between a tractable bug report and an
intractable one.

Shrinking is the process of *minimising* the failing input
while preserving the failure. It is a search procedure:

1. Start with the witness the generator found.
2. Propose a smaller candidate (drop an element, halve a
   number, ...).
3. Re-run the property on the candidate.
4. If the candidate fails, recurse with it as the new witness.
5. If the candidate passes, try a different reduction.
6. Stop when no further reduction fails.

The result is a *local minimum* of "things that still fail."
Not necessarily the globally smallest, but small enough.

:::slide

## Why shrinking matters

- The witness the generator finds is almost never minimal:
  - `[42; -17; 0; 3; 99; -2; 8]` fails; the bug is just `[3]`.
- Shrinking searches for a smaller witness:
  1. Propose a smaller candidate (drop an element, halve a
     number).
  2. Re-run the property on the candidate.
  3. Candidate fails: recurse from it. Passes: try another cut.
  4. Stop when no reduction still fails.
- Result: a *local minimum*, small enough to read at a glance.

:::

### How QCheck shrinks each type

QCheck's built-in `arbitrary`s come with shrinking baked in. The
default behaviour for the standard types:

**Integers.** Shrink toward zero. Given `n = 42`, try `0`, then
`21`, then `32` (half-way), and so on by bisection. If the bug
fires only on negative numbers, the shrinker walks `-42` -> `0`
-> `-21` -> ..., converging on the smallest negative that still
fails (often `-1`).

**Booleans.** Shrink `true` to `false`. (`false` is the "smaller"
value in QCheck's convention, by alphabetical / numerical order
of constructors.)

**Strings.** Shrink by deleting characters; once minimum-length
is reached, shrink each remaining character (toward `'a'` or
similar). A failing 20-character string converges to a 0 or 1
character string in a few steps.

**Lists.** Shrink in two phases:

1. *Structural.* Try dropping single elements, then pairs, then
   halves. A failing list of length 7 might shrink to length 6,
   then 4, then 2, then 1.
2. *Element-wise.* Once the list is at its minimum length, shrink
   each element individually (using the element's shrinker).

**Pairs, options.** Shrink each component independently, then
the whole.

**Sum types.** If a value is `Some x`, try `None`. If it is
`Inr y`, try `Inl ...`. Then recurse into the component.

The shrinkers compose: `QCheck.(list (pair int (option string)))`
inherits a shrinker that descends into the list, then into each
pair, then into each `option`, then into the integer or string,
all by minimising at each level.

:::slide

## Built-in shrinking, by type

| Type | Shrinks toward |
| --- | --- |
| `int` | `0` by bisection |
| `bool` | `false` |
| `string` | empty / `"a"` by deletion |
| `'a list` | drop elements, then shrink each |
| `'a option` | `None`, then shrink `'a` |
| `('a, 'b) result` | `Error _`, then shrink |
| pairs, tuples | each component independently |

The shrinkers compose recursively for compound types. (Custom
`QCheck.make` generators carry **no** shrinker unless you pass
`~shrink`.)

:::

### The integer-shrink-toward-zero heuristic

A specific case worth pinning down. When QCheck shrinks an
integer, it does *not* try every smaller value (that would be
useless for `min_int`); it bisects toward zero. The sequence for
`n = 100`:

```
100 -> 0 (try the limit)
100 -> 50 (try the halfway point)
100 -> 75
...
```

If `0` already fails the property, the shrinker reports `0` and
stops. If `0` passes but `50` fails, the search converges
between `0` and `50`. The result is logarithmic in the magnitude
of the original number, which means even very large
counterexamples shrink to small ones in a handful of steps.

The heuristic *is* a heuristic: it can miss the true minimum.
If the bug fires only on prime numbers and the bisection avoids
primes, the shrunk witness might be larger than the smallest
failing prime. In practice this is rare, and the shrinker's
local minimum is usually small enough to debug.

### When you need a custom shrinker

One caveat to carry forward. If you build a custom generator
with `QCheck.make` and do not pass a shrinker, the resulting
arbitrary has *no* shrinking: QCheck reports the original
failing input verbatim, however large. The optional `~shrink`
argument fixes that; it takes a function from a failing value to
the candidates to try in its place, usually a few lines built
from the `QCheck.Shrink` helpers. You will write exactly one in
this module, in the
[model-based testing lecture](M09-L06-model-based-testing.html),
where the failing input is a list of commands of a custom
variant type. Beyond that, the built-in shrinkers for `int`,
`list`, `string`, and friends handle nearly every case.

### Why "smallest failure" is more useful than "first failure"

A final note on shrinking's value. The original QuickCheck paper
made the point that *random testing without shrinking* is much
less useful than random testing *with* shrinking, even though
the random-generation work is the same. The reason: programmers
don't care about a 200-character string that crashes the parser;
they care about *which character* in that string caused the
crash. Shrinking turns "huge counterexample" into "minimal
counterexample," which is what a debugger needs.

If you take one thing from QCheck's API, take the shrinker. The
generator does the search; the shrinker does the diagnosis.

## When PBT does not help

PBT is not a universal solvent. There are cases where unit tests
still win.

**Specific known cases.** "What does `sort [3; 1; 2]` return?" is
a unit test, not a property. PBT cannot tell you the *answer* to
that specific question.

**Where the spec IS a list of cases.** Some functions are defined
by a finite table (the days of the week, the bytecode opcodes).
There is no "for all" structure to abstract over; a hand-written
case per row is more honest.

**Cases where generators are expensive.** If generating a valid
input is itself a multi-step process (parse, normalise, validate),
a hand-written corpus of representative inputs may be cheaper than
a custom generator.

**Cases where the property is just "the output equals the
expected output."** That is unit testing dressed in PBT clothes,
without any of the benefit.

The right reflex is: unit tests for *known specific cases*; PBT
for *invariants*. They are complementary, just like types and
tests.

:::slide

## When PBT does not help

- **Specific cases**: "sort [3; 1; 2] = [1; 2; 3]" is a unit test,
  not a property.
- **Tabular specs**: a finite enumerated table is unit-test
  shaped.
- **Expensive valid input**: writing a generator may cost more
  than a corpus.
- **The "property" is just expected = actual**: that is a unit
  test in disguise.

PBT is for *invariants*. Unit tests are for *cases*.

:::

## A short history

PBT was introduced by Koen Claessen and John Hughes in the
[QuickCheck](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf)
library for Haskell, published in ICFP 2000. The idea has since
been ported to dozens of languages:
[Hypothesis](https://hypothesis.readthedocs.io/) in Python,
[fast-check](https://github.com/dubzzz/fast-check) in
JavaScript, [proptest](https://github.com/proptest-rs/proptest) in
Rust, and many others. OCaml's
[QCheck](https://github.com/c-cube/qcheck) (by Simon Cruanes and
contributors) is the direct descendant of QuickCheck, with OCaml-
idiomatic conventions.

The intellectual contribution of QuickCheck was not the random
testing itself: random testing predates QuickCheck by decades. It
was *the combination of random generation with automatic shrinking
inside a strong type system*. The type system makes it possible to
auto-generate inputs for any type, and shrinking makes the
counterexamples small enough to debug. Together they make PBT
productive for working programmers, not just a research curiosity.

A recurring surprise in Hughes's later experience reports is that
property-based testing often finds bugs not in the implementation
but in the *specification* itself: the hand-written reference
model that was supposed to be the oracle. Testing a real telecoms
system against a formal model, his team repeatedly found that
counterexamples pointed at mistakes in the model, not the code.
This is the strongest argument for properties over hand-written
cases: a property is forced to confront inputs you would never
have thought to write down, including the ones that expose your
own misunderstanding of what "correct" means.

## Activity

:::quiz mcq id=M09-L05-q1
A colleague writes a `dedup : int list -> int list` and a single
QCheck property:

```text
let test = QCheck.Test.make QCheck.(list int)
  (fun xs -> List.length (dedup xs) <= List.length xs)
```

The property passes on 1000 random inputs. What is the strongest
conclusion you can draw about `dedup`?

- [ ] `dedup` is correct.
- [ ] `dedup` is incorrect; one property is never enough.
- [x] Many incorrect implementations satisfy this property.
- [ ] `dedup` returns the correct multiset of elements.

**Why:** the property only states that the output is no longer
than the input. `fun _ -> []` satisfies it (length 0 is at most
any length). So does the identity. So does "return the first
element only." A single weak property cannot replace a
specification; you need *several* properties whose conjunction
constrains behaviour. Length-no-longer-than is one constraint;
"every element of the output appears in the input", "no
duplicates in the output", and "every input element appears in
the output" would together pin `dedup` down.
:::

:::quiz mcq id=M09-L05-q2
QCheck runs a property on a buggy function and reports:

```
Test failed on input: [3].
```

The function was tested with `QCheck.(list int)`, which generates
random lists of random length. The reported input is a one-element
list, but the *random* input that triggered the bug was, the
seed log suggests, a 12-element list. What happened?

- [ ] QCheck regenerated the input from a smaller seed.
- [x] QCheck *shrunk* the failing 12-element input down to the
  smallest input that still fails, namely `[3]`.
- [ ] The 12-element input did not actually fail; QCheck mis-
  reported.
- [ ] The bug fires randomly and the seed determines which
  inputs trigger it.

**Why:** shrinking is QCheck's process of repeatedly minimising
a failing input. After finding a 12-element counterexample, it
tries dropping elements, replacing elements with smaller ones,
and so on, until further reduction would make the property pass.
The reported `[3]` is the *minimal* witnessed failure. This is
the central feature that makes PBT actionable: the original
random failure is usually too noisy to debug; the shrunk
witness is usually the bug in its purest form.
:::

:::quiz code id=M09-L05-q3
Write a QCheck property that captures: *concatenating the empty
list to any list yields the original list.* Use the generator
`QCheck.(list int)`. Name the property `"empty is right identity
for @"`.

The body of the test should be a function `xs -> bool` returning
`true` when the law holds.

```ocaml
let test_concat_empty_right =
  QCheck.Test.make
    ~name:"empty is right identity for @"
    QCheck.(list int)
    (fun _xs -> failwith "not implemented")
```

```ocaml skip
let () =
  (* The student's test must, when applied to any list, hold. *)
  let prop xs = xs @ [] = xs in
  assert (prop []);
  assert (prop [1]);
  assert (prop [1; 2; 3]);
  assert (prop [-7; 0; 42]);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let test_concat_empty_right =
  QCheck.Test.make
    ~name:"empty is right identity for @"
    QCheck.(list int)
    (fun xs -> xs @ [] = xs)
```

Four lines. The property `xs @ [] = xs` is a one-line statement
of a list-monoid law; it is exactly the kind of equational
property functional code makes easy to state.

:::

## Common pitfalls

**Pitfall 1: too few properties.** A function with one property
that "passes" is barely more tested than a function without
properties at all. State several. The conjunction is what
constrains behaviour.

**Pitfall 2: tautological properties.** Watch for properties that
hold of any function with the right type. `fun xs -> List.length
(rev xs) >= 0` is true of every list, including the wrong ones.
The property has to *exclude* implementations.

**Pitfall 3: properties that depend on the implementation.** "rev
allocates a new list" depends on the implementation, not the
spec. Phrase properties in terms of *observable behaviour*.

**Pitfall 4: too-narrow generators.** If `QCheck.small_int` only
produces 0-9 but the bug fires on `min_int`, the bug will not be
caught. Default generators are reasonable; custom ones need
thought.

**Pitfall 5: confusing "passed 1000 cases" with "proved".** PBT
gives you evidence, not proof. A bug that fires only on inputs
with a specific shape (e.g. a deeply nested record) may evade
1000 random inputs. PBT is a *sieve*, not a verifier.

:::slide

## Common pitfalls

1. **Too few properties**: one law barely constrains anything.
2. **Tautological properties**: hold of any function with the
   right type.
3. **Implementation-bound properties**: should phrase in terms
   of behaviour.
4. **Too-narrow generators**: tweak when bugs persist.
5. **"Passed N cases" ≠ "proved"**: PBT is a sieve, not a
   verifier.

:::

## What's next

So far the things we have tested are *pure functions*: an input
goes in, an output comes out, no state. PBT works well there. But
much of real software is stateful: a hash table you `add` to and
`remove` from, a queue you `enqueue` and `dequeue`, a file you
`read` and `write`. How do you write a property for a *stateful*
data structure, where each operation depends on every operation
that came before?

[Lecture 6](M09-L06-model-based-testing.html) answers with
*model-based testing*: test a stateful implementation against a
simple reference implementation, by generating random sequences
of operations and asserting observable equivalence at each
step. It is the canonical PBT pattern for stateful code, and it
cleanly extends what we have built in this lecture.

[Lecture 7](M09-L07-tutorial.html) puts unit testing and
property-based testing together on a single, larger example: a
small arithmetic evaluator (a float cousin of the
pattern-matching tutorial's interpreter),
with a deliberately broken implementation that QCheck finds in
seconds.

:::slide

## What's next

- L6: **model-based testing.** A mutable queue vs. a
  list-based reference.
- L7: **tutorial.** The full toolkit on the arithmetic
  evaluator; a deliberately buggy version found by the
  shrinker.

:::

## Reading

- **QCheck**, the OCaml property-based testing library used in
  this lecture. README, tutorial, and API docs are all in the
  upstream repository:
  <https://github.com/c-cube/qcheck>
- **QCheck API documentation**, generated from the source:
  <https://c-cube.github.io/qcheck/>
- **Claessen and Hughes**, *QuickCheck: A Lightweight Tool for
  Random Testing of Haskell Programs*, ICFP 2000. The paper that
  introduced PBT and the combination of random generation with
  automatic shrinking:
  <https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf>
- **Cornell CS3110**, *Randomized testing with QCheck*. Source
  for the abstraction layering (generator, arbitrary, property)
  used in this lecture:
  <https://cs3110.github.io/textbook/chapters/correctness/randomized.html>
- **Cornell CS3110**, *Black-box and glass-box testing*. The
  framework of "paths through the specification" we used in the
  input-space section:
  <https://cs3110.github.io/textbook/chapters/correctness/black_glass_box.html>
- **Real World OCaml**, *Testing*. The Quickcheck section
  discusses distribution choice and how `ppx_quickcheck` derives
  generators automatically:
  <https://dev.realworldocaml.org/testing.html>

## Sources

This lecture's prose, worked examples, and quizzes are original
to this course. The QCheck library by Simon Cruanes and
contributors is BSD-2-Clause licensed; we link to its
repository and use its public API surface, with no derivative
reuse of its prose. The QuickCheck origin paper (Claessen and
Hughes) is the canonical reference for the technique itself;
we cite it for context. Cornell CS3110's randomized-testing
and black-box-testing chapters are CC BY-NC-ND licensed and
have not been derivatively reused; the *paths through the
specification* framing we use in the input-space section
follows their pedagogical sequence with our own examples and
prose, and we link to both for further reading. Real World
OCaml's Testing chapter has a parallel discussion of Quickcheck
distribution choice that we link to but have not reused. The
`bad_sort` example (missing singleton case) and the sorted-list,
operation-based-BST, and DAG-by-vertex-order generator recipes
are folklore in the PBT community, presented here in our own
words and OCaml.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
