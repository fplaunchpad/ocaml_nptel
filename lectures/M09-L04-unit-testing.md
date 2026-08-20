---
title: "Unit testing"
lecture_no: 4
week: 9
duration_target_min: 18
concepts: [unit testing, test suite, test runner, fixtures, test independence, positive and negative cases, dune integration, CI gate]
keywords: [OCaml, OUnit2, unit test, test suite, runner, fixture, assert_raises, dune, runtest, continuous integration]
activity_question: "Write an OUnit2 test case for the value-oriented `Stack`: create a fresh stack, push `7`, pop, and assert (with a printer) that the popped value is `7`."
think_about_this: "A failing test breaks the build, exactly like a type error does. What does that change about when bugs are found, compared with discovering them by running the program by hand?"
reading:
  - title: "Cornell CS3110, OUnit"
    url: https://cs3110.github.io/textbook/chapters/data/ounit.html
  - title: "OUnit2 GitHub repository and API docs"
    url: https://github.com/gildor478/ounit
---

# Unit testing


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Unit testing</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 4</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

A **unit test** checks one *unit* of code: a single function, or
a single module, exercised in isolation against its
specification. The check is small, fast, and repeatable: fixed
inputs, an expected result, and a comparison between the two.
**Unit testing** is the practice of writing many such checks and
running them together. It is the most local level of testing: a
unit test exercises one function on its own, as opposed to
*integration* testing (do the functions work together?) and
*system* testing (does the whole program meet its requirements?).
Bugs are cheapest to find at the unit level, because a failing
unit test points at one function, not at a whole pipeline.

:::slide

## Unit testing

A **unit test** checks one *unit* in isolation: a single
function or module, against its specification.

- Small, fast, repeatable: fixed input, expected result, a
  comparison.
- **Unit testing** = many such checks, run together as a
  **suite**.
- The most local level of testing
  - below *integration* (units together) and *system* (the whole
    program) testing.
- A failing unit test points at *one function*, not a whole
  pipeline.

:::

The previous two lectures produced *case tables*: a contract to
check against ([specifications](M09-L02-specifications-invariants.html)),
and the inputs worth checking ([test design](M09-L03-test-design.html)).
So far we have run those cases as bare `assert`s, which is fine for
a handful on one page and unworkable for a real project: the first
failed `assert` halts everything, tells you a line number and
nothing else, and there is no way to run one suite among many.

This lecture turns a case table into something a project can live
with: a *suite* of named unit tests, run by a *runner* that
reports which ones failed, wired into the build so the tests run
on every change. The tool we use is
[OUnit2](https://github.com/gildor478/ounit); but the tool is
incidental. The vocabulary (case, suite, fixture) and the ideas
(independence, positive-and-negative, the build gate) transfer to
Alcotest, to `ppx_inline_test`, to JUnit and pytest. We pick one
and use it; skim the others when you meet them.

:::slide

## What this lecture covers

- From a designed case table to a **named, runnable suite**.
- A **runner** that reports *which* case failed, not just that
  one did.
- **Fixtures**: each case starts from a known state, so cases
  stay independent.
- **Positive and negative** cases: test the contract *and* its
  error paths.
- The **build gate**: `dune runtest`, and a failing test breaks
  the build like a type error.

:::

## Three words

Three words recur across every testing framework, and they mean
the same thing everywhere. Worth pinning down.

A **test case** is a single named scenario: a fixed input, an
expected result, and the comparison between them. "Push three
items, then peek, and see the third" is one case.

A **test suite** is a collection of cases run together. The
suite is the unit of execution: you run a suite, and the
framework reports how many passed, how many failed, and where.

A **test fixture** is the setup (and teardown) that runs around
each case so it starts from a known state. For a stack, the
fixture is "a fresh empty stack." Fixtures keep cases short and,
crucially, *independent*.

:::slide

## Three words

| Term | Meaning |
| --- | --- |
| **Test case** | One named scenario: input + expected + comparison. |
| **Test suite** | A collection of cases run as one unit. |
| **Test fixture** | Setup/teardown around each case (a known state). |

- The framework runs the cases and reports what failed.
  Everything else is you.

:::

## From a case table to a suite

Here is the smallest possible suite. It is the bare `assert`
turned into a *named case*, collected into a suite, handed to a
runner:

```ocaml
open OUnit2

let test_addition _ = assert_equal 4 (2 + 2)

let suite = "arithmetic" >::: [ "two plus two" >:: test_addition ]

let _ = run_test_tt_main suite
```

Four moving parts, and they are the whole framework:

- `assert_equal expected actual` is the comparison (expected
  first, so the failure message "expected E, got A" reads
  correctly).
- `"name" >:: case` makes one named case; `"name" >::: [ ... ]`
  collects cases into a named suite (one colon, one case; three
  colons, a list).
- `run_test_tt_main` runs the suite and prints a report: a dot
  per pass, an `F` per failure, a count at the end.

Run the cell: one dot, `OK`. The point of the *name* is that
when a case fails six months from now, the report says *which*
scenario broke, not just "an assertion on line 273."

:::slide

## From a case table to a suite

```ocaml
open OUnit2

let test_addition _ = assert_equal 4 (2 + 2)

let suite =
  "arithmetic" >::: [ "two plus two" >:: test_addition ]

let _ = run_test_tt_main suite
```

- `assert_equal expected actual` (expected first: readable
  failures).
- `>::` one named case; `>:::` a named list of cases.
- `run_test_tt_main` runs them and reports which failed.

:::

A note on failure messages: `assert_equal` has no generic way to
print arbitrary OCaml values, so a bare failure says "expected
... got ..." with no values. Pass `~printer` and it becomes
useful: `assert_equal ~printer:string_of_int 4 (2 + 2)`. Make it
a habit.

## Tests as a build gate

The real payoff is not running tests by hand; it is running them
*automatically, on every change*. In a `dune` project the tests
live in their own directory with a `(test ...)` stanza:

```dune
(test
 (name test_stack)
 (libraries ounit2 my_library))
```

`dune runtest` builds whatever is stale, runs the test
executable, and shows its output. If a test fails, `dune` exits
non-zero, and that is the whole point: a failing test breaks the
build, exactly the way a type error does. Wire `dune runtest`
into continuous integration and a broken contract can no longer
reach `main` unnoticed. Types and tests become the same kind of
gate: both run on every change, both refuse to let a known
problem through.

:::slide

## Tests as a build gate

```dune
(test
 (name test_stack)
 (libraries ounit2 my_library))
```

- `dune runtest` builds, runs, reports.
- A failing test exits non-zero: it **breaks the build**, like
  a type error.
- In CI, that means a broken contract cannot reach `main`
  unnoticed.

:::

You can try the build gate yourself. The terminal below boots a
real Linux machine inside this page (nothing installed on your
computer, nothing on a server), sitting in `~/morse`: a small
library in `lib/`, a binary in `bin/`, and an OUnit2 suite in
`test/`. Run `dune runtest`; then break an expected string with
`nano test/test_morse.ml` and run it again to watch the suite go
red and the exit status flip.

:::slide

## Live: `dune runtest`

- Boot it; `dune runtest` builds and runs the suite.
- `nano test/test_morse.ml`: break a case, re-run, watch it
  fail (and the non-zero exit CI keys on).

:::vm-terminal dir=/root/morse
:::

:::

## Each case from a known state

When the code under test is *stateful* (a mutable stack, a file,
a connection), each case must start from a known state, or cases
contaminate one another. The OCaml idiom is simple: a helper
that builds a fresh value, called at the top of every case.

```ocaml
exception Empty

module Stack = struct
  type 'a t = { mutable items : 'a list }
  let create () = { items = [] }
  let is_empty s = s.items = []
  let push x s = s.items <- x :: s.items
  let pop s = match s.items with
    | [] -> raise Empty
    | x :: rest -> s.items <- rest; x
  let peek s = match s.items with
    | [] -> raise Empty
    | x :: _ -> x
end
```

This is the `Stack` from
[the modules material](M07-L06-module-basics.html), in its
value-oriented shape: every operation takes a `Stack.t`, so each
case can `Stack.create ()` its own. (Empty-stack `pop`/`peek`
*raise* `Empty`, which gives us an error path to test.)

:::slide

## The `Stack` under test

```ocaml
exception Empty
module Stack = struct
  type 'a t = { mutable items : 'a list }
  let create () = { items = [] }
  let push x s = s.items <- x :: s.items
  let pop s = match s.items with
    | [] -> raise Empty | x :: r -> s.items <- r; x
end
```

- Value-oriented: every op takes a `Stack.t`.
- Each case gets its own `Stack.create ()`: cases stay
  independent.

:::

## Positive and negative cases

A good suite tests both what the function should *accept* and
what it should *reject*. Positive cases check normal behaviour;
negative cases check the error paths, which is where most
production bugs actually hide.

```ocaml
open OUnit2

let test_lifo _ =
  let s = Stack.create () in
  Stack.push 1 s; Stack.push 2 s; Stack.push 3 s;
  assert_equal ~printer:string_of_int 3 (Stack.pop s);
  assert_equal ~printer:string_of_int 2 (Stack.pop s);
  assert_equal ~printer:string_of_int 1 (Stack.pop s)

let test_pop_empty_raises _ =
  let s = Stack.create () in
  assert_raises Empty (fun () -> Stack.pop s)

let suite =
  "stack" >::: [
    "LIFO order"        >:: test_lifo;
    "pop empty raises"  >:: test_pop_empty_raises;
  ]
```

Handing `suite` to `run_test_tt_main` (as in the arithmetic
example above) reports both cases passing:

```text
..
Ran: 2 tests in: 0.00 seconds.
OK
```

Two things to notice. `test_lifo` makes several assertions on one
setup: that is fine, it is one behaviour (LIFO) expressed with
several checks, and the report still names the line that failed.
And `assert_raises` takes a *thunk*, `fun () -> Stack.pop s`, not
`Stack.pop s`: the framework needs an un-evaluated computation it
can wrap in its own `try ... with`, so it can catch the exception
and compare it.

:::slide

## Positive and negative cases

```ocaml
let test_lifo _ =
  let s = Stack.create () in
  Stack.push 1 s; Stack.push 2 s; Stack.push 3 s;
  assert_equal ~printer:string_of_int 3 (Stack.pop s);
  assert_equal ~printer:string_of_int 2 (Stack.pop s)

let test_pop_empty_raises _ =
  let s = Stack.create () in
  assert_raises Empty (fun () -> Stack.pop s)
```

- Positive: normal behaviour (LIFO). Negative: the error path.
- `assert_raises` takes a **thunk** (`fun () -> ...`), so the
  framework can catch the exception.

:::

:::slide

## Collecting them into a named suite

```ocaml
let suite =
  "stack" >::: [
    "LIFO order"        >:: test_lifo;
    "pop empty raises"  >:: test_pop_empty_raises;
  ]
```

- Each case gets a **name**; `>:::` collects them into the suite.
- Those names (`LIFO order`, `pop empty raises`) are exactly what
  the runner prints when a case fails, on the next slide.

:::

## When a function breaks, the report points at it

Suppose someone "refactors" `push` into a no-op:

```text
let push _ _ = ()        (* DELIBERATELY BROKEN *)
```

Re-run the two-case suite. The vanished pushes leave the stack
empty, so `LIFO order`'s first `pop` now raises `Empty`; the
`pop empty raises` case never pushes, so it is unaffected:

```text
E.
==============================================================================
Error: stack:0:LIFO order.
  ...
  Empty
------------------------------------------------------------------------------
Ran: 2 tests in: 0.00 seconds.
FAILED: Cases: 2  Tried: 2  Errors: 1  Failures: 0  Skip: 0  Todo: 0
```

`E.` reads left to right: the first case errored, the second
(`.`) passed. OUnit2 marks an unexpected exception `E` and a
failed comparison `F`; either way the case is red, and the
report *names* it (`stack:0:LIFO order`). The green case tells
you the break is confined to the `push` path. That localisation
is the runner earning its keep, and the reason a named suite
beats a wall of `assert`s, where the first failure halts the
rest.

:::slide

## When a function breaks

```text
let push _ _ = ()        (* DELIBERATELY BROKEN *)

E.
Error: stack:0:LIFO order.   (* raised Empty *)
Ran: 2 tests in: 0.00 seconds.
FAILED: Cases: 2  Errors: 1  Failures: 0
```

- `E.`: `LIFO order` (which pushes) errored; `pop empty raises`
  passed.
- The report *names* the broken case; the green one bounds the
  damage.
- A named suite localises the break; bare `assert`s halt at the
  first.

:::

## What a runner does, and does not, do

OUnit2 (and its peers) runs named cases and reports failures.
That is the whole job. Three things it deliberately does *not*
do, each handled elsewhere in this module:

- **Generate inputs.** Every case here is one hand-picked input.
  Random exploration of the input space is
  [property-based testing](M09-L05-property-based-testing.html),
  next lecture.
- **Measure coverage.** "Did my cases reach every branch?" is
  the [coverage](M09-L03-test-design.html) question, answered by
  `bisect_ppx`.
- **Pick the cases for you.** *Which* inputs to test is
  [test design](M09-L03-test-design.html); the runner just runs
  whatever you wrote.

One sibling of the unit test is worth naming: the *expect test*.
Instead of writing the expected value by hand, you run the case
once, let the framework capture the actual output, read it, and
keep the captured version; from then on, the case fails whenever
the output changes. It is a unit test whose expected side is
recorded rather than written, and it is most useful where
the output is messy or evolving (pretty-printers, error
reports, end-to-end transcripts). Real World OCaml's testing
chapter shows the workflow with `ppx_expect`.

:::slide

## A runner runs cases; it does not...

- **generate inputs** -> property-based testing (next lecture).
- **measure coverage** -> `bisect_ppx` (the test-design
  lecture).
- **choose the cases** -> that is test design; the runner runs
  what you wrote.

A clean tool that does one thing: run cases, report failures.

:::

## Activity

:::quiz mcq id=M09-L04-q1
Every case in the `Stack` suite begins with
`let s = Stack.create ()` instead of sharing one stack across
all cases. What is the main reason?

- [x] Independence: one case's mutations cannot affect another,
  and the suite's result does not depend on the order cases run
  in.
- [ ] OUnit2 refuses to run a suite that shares state between
  cases.
- [ ] A fresh stack per case makes the suite run faster.
- [ ] `Stack.create` is the only function allowed to call
  `Stack.push`.

**Why:** a single shared mutable stack makes case *n* depend on
everything cases 1..*n*-1 did to it. A failure then cascades
into unrelated cases, and the result depends on run order, so a
green suite stops meaning "each behaviour works." A fresh
fixture per case isolates each one to the single thing it
checks. OUnit2 does not forbid sharing (nothing stops you doing
the wrong thing), and the speed difference is negligible; the
reason is independence.
:::

:::quiz code id=M09-L04-q2
Write an OUnit2 test case for
`"push then pop on a fresh stack returns the pushed value"`, then
put it in a suite named `"stack"`. Use
the value-oriented `Stack` from this lecture. The case should
create a fresh stack, push `7`, pop, and assert the result is
`7` (with a printer).

```ocaml
let test_push_pop_seven _ =
  failwith "not implemented"

let suite =
  "stack" >::: [
    "push and pop" >:: test_push_pop_seven;
  ]
```

```ocaml skip
let () =
  let s = Stack.create () in
  Stack.push 7 s;
  assert (Stack.pop s = 7);
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```ocaml
let test_push_pop_seven _ =
  let s = Stack.create () in
  Stack.push 7 s;
  assert_equal ~printer:string_of_int 7 (Stack.pop s)

let suite =
  "stack" >::: [
    "push and pop" >:: test_push_pop_seven;
  ]
```

Arrange (create + push), act (the `pop` inside the assertion),
assert (with a printer so a failure prints the numbers). That is
the canonical shape of a case.

:::

## What's next

[Lecture 5](M09-L05-property-based-testing.html) takes the step
this lecture deliberately did not: instead of hand-writing each
input and its answer, *generate* inputs and check that a
*property* holds over all of them. That is property-based
testing with QCheck: you will see why functional code makes
properties natural to state, and watch the shrinker cut a
failing input down to its smallest form.

[Lecture 6](M09-L06-model-based-testing.html) tests stateful
code against a reference; [Lecture 7](M09-L07-tutorial.html)
puts the whole toolkit on one worked example.

:::slide

## What's next

- L5: **property-based testing with QCheck**. Generate inputs;
  check a property; shrink failures.
- L6: **model-based testing**. A structure vs a reference.
- L7: **tutorial**. The full toolkit on one evaluator.

:::

## Reading

- **Cornell CS3110**, *OUnit*:
  <https://cs3110.github.io/textbook/chapters/data/ounit.html>
- **OUnit2 repository**, README and API docs (MIT-licensed):
  <https://github.com/gildor478/ounit>
- **Real World OCaml**, *Testing* (uses Alcotest, same ideas):
  <https://dev.realworldocaml.org/testing.html>

## Sources

This lecture's prose, worked examples, and quizzes are original
to this course. Cornell CS3110's OUnit chapter is the conceptual
antecedent for the case/suite/runner vocabulary; its prose is
CC BY-NC-ND licensed and has not been derivatively reused. The
`Stack` is the [module-basics](M07-L06-module-basics.html)
module in a value-oriented shape so cases stay independent.
OUnit2 (MIT) is used through its public API.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
