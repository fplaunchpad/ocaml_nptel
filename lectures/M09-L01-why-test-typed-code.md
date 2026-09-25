---
title: "Why test a type-safe program?"
lecture_no: 1
week: 9
youtube_id: ILjevo5bdgs
duration_target_min: 25
concepts: [testing, type safety, behaviour, validation, complementary roles of types and tests, faults and failures]
keywords: [OCaml, testing, type safety, behaviour, unit testing, property-based testing, validation, faults, failures, debugging]
activity_question: "A colleague's deduplication function is [let dedup (xs : 'a list) : 'a list = []]. The compiler accepts it without warnings. What is the strongest statement you can make about this function?"
think_about_this: "If types eliminate whole classes of bugs by construction, why are there still bugs in well-typed programs? What kind of bug is the type checker structurally unable to see?"
reading:
  - title: "Cornell CS3110, Testing and Debugging"
    url: https://cs3110.github.io/textbook/chapters/correctness/test_debug.html
  - title: "Real World OCaml v2, Testing"
    url: https://dev.realworldocaml.org/testing.html
---

# Why test a type-safe program?


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Why test a type-safe program?</h2>
<p class="title-slide-label">Module 9 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Eight modules ago, the very first lecture of this course claimed,
roughly, that OCaml's type system catches "a lot" of bugs. By
Module 5 you had pattern-match exhaustiveness on top of basic
type-checking. By Module 7 you had abstract types and signatures
hiding implementation choices. By Module 8 you had monads and
GADTs precise enough to refuse, at compile time, an expression
that would otherwise have produced a runtime "type error" by some
other name.

It is a fair impression, by this point in the course, that a
program which type-checks is *mostly correct*. Many bugs you would
have hit in C, Python, or Java really are gone: you do not pass an
`int` where a `string list` was wanted, you do not forget the empty
list case of a recursive function, you do not extract a value from
an `Option.t` without saying what should happen on `None`. Each of
those was a runtime crash in the language you came from. In OCaml,
the first is a compile error and the other two are exhaustiveness
warnings the compiler insists you confront.

This module asks a sharper question. *What kind of bug does the
type system structurally fail to catch?* And what do you do about
those bugs? The answer is not "give up on safety"; the answer is
"types and tests are complementary." Types catch *type errors*.
Tests catch *behaviour*. The rest of the course assumes you
appreciate that distinction precisely.

:::slide

## Where we are

- Eight modules of OCaml safety:
  - types catch type errors,
  - exhaustive matches force case handling,
  - abstraction enforces interfaces.
- A common impression: "if it type-checks, it's mostly correct."
- That impression is *almost* right, but the gap matters.
- This module: what types do NOT catch, and how testing fills the
  gap.

:::

## The sort that does not sort

Here is the example to keep in mind for the rest of this module.

```ocaml
let sort (xs : 'a list) : 'a list = xs

let _ = sort [3; 1; 2]  (* = [3; 1; 2] *)
```

This is a function called `sort`, of type `'a list -> 'a list`,
that takes a list and returns "a sorted version" of it. The OCaml
compiler is entirely happy. The types check. There are no warnings.
The function has the exact same type signature as `List.sort
compare` (modulo the comparator), and at a glance, in a `dune`
build log, the two would be indistinguishable.

It does not sort.

`sort [3; 1; 2]` evaluates to `[3; 1; 2]`, unchanged. The function
just returns its input. There is nothing wrong with it according to
OCaml's type checker, because the *type* of "a function that takes
a list and returns a list" says nothing about *which* list. The
identity function has that type. So does `List.rev`. So does any
function that returns a constant list of the right element type.
The type system has been completely satisfied by a totally wrong
program.

:::slide

## The well-typed function that does the wrong thing

```ocaml
let sort (xs : 'a list) : 'a list = xs
```

- Type: `'a list -> 'a list`. Same as `List.sort compare` modulo
  the comparator.
- Compiler: happy.
- Behaviour: `sort [3; 1; 2] = [3; 1; 2]`, not `[1; 2; 3]`.
- **The type signature is satisfied; the specification is not.**

:::

This is *the* example that motivates this entire module. It is not
contrived. The same shape of bug shows up in real codebases all
the time. A pricing function returns its argument unchanged. A
deduplication routine returns the empty list. A normalisation pass
forgets to do half of its work. Each function has the right type.
Each function compiles. Each is wrong. The compiler cannot tell
you about any of them, because none of them is a type error.

The reason is that the *type* of a function is a coarse
approximation of its *behaviour*. The type `'a list -> 'a list`
says "give me a list of some element type, and I will give you
back another list of the same element type." That is true of an
infinite family of functions, only one of which is the sort you
wanted. The type checker accepts every member of that family
without prejudice; choosing the right member is your job, and
checking that you chose right is the job of *testing*.

## A taxonomy of what types catch and what they don't

It is worth being precise about which bugs OCaml's type system
*does* catch, because the contrast is what makes this module
necessary in the first place. Eight modules in, the list is long.

:::slide

## What types catch by construction

- **Type errors**: passing an `int` where a `string` was expected;
  applying a non-function; mixing `int` and `float` without
  conversion.
- **Exhaustiveness warnings**: `match` without a case for the
  empty list, for `None`, or for some constructor of a variant.
- **Use-before-definition**: variables not yet bound; recursive
  references without `let rec`.
- **Forced shapes**: `'a -> 'a` is so polymorphic that only the
  identity inhabits it (up to non-termination)
  - the technical name is *parametricity*; rare but real.

:::

The last item, parametricity, deserves a moment. A function of
type `'a -> 'a` has *no other choice* than the identity function
(modulo doing nothing forever, raising an exception, etc.). The
type itself rules out everything else: the function cannot inspect
the input (it does not know `'a`), cannot construct a new `'a` out
of thin air (only the input has type `'a`), and must return
something of type `'a` (only the input has that type). So the type
*forces* the implementation, up to obvious caveats. This is a real
case where the type catches behaviour. But it is rare. It happens
only at the boundaries: at functions whose type is so polymorphic
that very few implementations satisfy it. Most useful code has
types that do not pin down behaviour anywhere near this tightly.

:::slide

## What types do NOT catch

- **Behaviour bugs**: well-typed functions that produce the wrong
  output. The `sort` example.
- **Performance regressions**: a well-typed sort is allowed to
  be O(n^3); the type is the same as O(n log n).
- **I/O mismatches**: a function may read a file and parse it
  wrong; the result type is the same.
- **Integration bugs**: two well-typed components, plugged
  together, may interact in an unintended way.
- **Resource leaks** (in the abstract sense): leaving a file
  open, never closing a connection. The type does not record
  "is closed."
- **Off-by-one errors, sign mistakes, swapped arguments of the
  same type, ...**

:::

The "swapped arguments of the same type" point is worth pausing
on, because it is the most common behaviour bug in a strongly
typed codebase. If a function takes two `int`s, one meaning
"index" and the other meaning "length", the type checker has no
way to tell you which is which at a call site. A misordered
`String.sub s start length` where you wrote `String.sub s length
start` will type-check perfectly. The error shows up at runtime,
or worse, silently, in a slightly different output.

OCaml has tools that close some of this gap (labelled arguments,
records-with-field-names, units of measure via newtype wrappers),
and we will use them. But the type system does not, on its own,
prevent the mistake. You catch it the same way C programmers
catch off-by-one errors: by writing tests that drive the function
on examples whose answers you know.

## Types and tests are complementary

The right way to think about this is not "types versus tests" but
"types and tests." They cover different ground.

Types are *cheap*. The compiler runs them every time you build,
on every line of code. They scale to large codebases automatically.
They catch a specific *category* of mistake on *every* code path
without needing examples. If you change a record field, the
compiler points at every site that uses it. That is the dividend
the type system pays back for the syntax cost.

Tests are *expensive* by comparison. Each test you write covers
a specific scenario; you have to author it, run it, maintain it
as the code evolves. But tests can express what types cannot.
The test `assert (sort [3; 1; 2] = [1; 2; 3])` says, in code, what
the function is *supposed to do*; the type system, by design,
cannot say that. The job of tests is to encode behaviour that the
type system has no vocabulary for.

:::slide

## Types and tests, complementary

| Catches | Types | Tests |
| --- | --- | --- |
| Type errors | yes | (incidentally) |
| Exhaustiveness | yes (warnings) | (incidentally) |
| Parametricity-forced shape | yes | no |
| Wrong output for a known input | no | yes |
| Off-by-one in a loop bound | no | yes |
| Swapped same-typed arguments | no | yes |
| Performance regressions | no | yes (benchmarks) |

- Types: every build, every line, every path, every developer.
  Cheap per check.
- Tests: per scenario, per case. Expensive per check, but
  expressive about *behaviour*.

:::

This complementarity is not new. Cornell CS3110's textbook makes
the same point in its chapter on testing and debugging: "*Validation
is the process of building our confidence in correct program
behavior.*" Validation is broader than testing. It includes
*social* methods: a code review, where a colleague reads your
change and asks why line 40 is safe; pair programming, where a
second pair of eyes watches the code appear. (Industrial studies
have repeatedly found code inspection to be embarrassingly
effective at finding faults, often more so than the test suite.)
It includes *formal* methods: mathematical proof that the code
meets a specification, which we discuss below. And it includes
*testing*: actually running the program on chosen inputs and
checking what comes out. Types sit naturally with the formal
side, but the boundary is thin.

Real World OCaml's testing chapter adds a point worth keeping:
types *raise* the value of testing, because the snap-together
quality of strongly typed code means a relatively small number
of tests can exercise a large surface. The two are not in
tension; if anything, they complement each other more strongly
than tests-versus-types in a dynamic language.

:::slide

## Three roads to confidence

- **Social**: code review, pair programming, walkthroughs.
  - Inspection finds faults tests miss; a human asks "why is
    this safe?"
- **Formal**: proofs that code meets a spec; types are the
  everyday, automated end of this road.
- **Testing**: run the program on chosen inputs, check the
  output.
  - Cheapest evidence per unit of effort; the focus of this
    module.

:::

So the question for the rest of this module is not *whether* to
test, but *how*.

## Two kinds of test, plus a side door

In practice, two styles of automated test cover most of what you
need to do on a small to medium OCaml codebase, with a third
narrower style filling a gap. Before any of them can do useful
work, though, two questions have to be answered that no tool
answers for you: what counts as *correct* (that is the job of a
*specification*, the subject of the next lecture), and *which*
inputs are worth trying (the subject of the lecture after that).
The tools then mechanize what the answers tell you to check.

:::slide

## Two kinds of test, plus a side door

1. **Unit tests** (L4): "for *this* input, *this* output."
   Hand-written examples.
2. **Property-based tests** (L5, L6): "for *any* generated
   input, this property holds."
3. **Model-based tests** (L7): stateful PBT against a simple
   reference implementation.
4. **Expect tests** (mentioned in L4): the output, captured
   verbatim, compared on every run.

- Before any tool, two questions no tool answers:
  - *what counts as correct?* (specifications, L2)
  - *which inputs are worth trying?* (test design, L3)

:::

**Unit tests** are the workhorse. You pick specific inputs and
write down the expected output. `sort [3; 1; 2]` should equal `[1;
2; 3]`. `sort []` should equal `[]`. `sort [42]` should equal
`[42]`. Run the function on each, compare the output, report
mismatches. The OCaml library for this in CS3110's tradition is
[OUnit2](https://github.com/gildor478/ounit); we cover it in
[Lecture 4](M09-L04-unit-testing.html). Other libraries
([Alcotest](https://github.com/mirage/alcotest), the inline
testing in Real World OCaml's chapter) take the same shape with
different cosmetics; the conceptual content is the same.

**Property-based tests**, or PBT, are the more interesting
addition. Instead of writing down one input and its answer, you
write down a *property* that should hold for *any* input, plus
a way to generate random inputs of the right shape. The library
runs the property on a few hundred inputs and reports any input
for which the property failed. The library we'll use is
[QCheck](https://github.com/c-cube/qcheck), which is the OCaml
descendant of Haskell's QuickCheck. Lecture 5 makes the case for
why PBT is *particularly* natural in OCaml: pure functions and
equational reasoning give you a clean way to state properties.

**Expect tests** are a side door that we will mention but not
dwell on. They are useful when the "right output" is too messy or
too varied to write a manual assertion: you let the test runner
*capture* the output the first time, you look at it once, and
from then on the test fails if the output differs from the
captured version. They are excellent for exploratory work and for
end-to-end scenarios. Real World OCaml's chapter demonstrates them
in detail; we cover them only briefly because the conceptual
content overlaps with unit tests once you have seen one.

## What about formal verification?

A fair question to ask, at this point, is: why test at all? If
types are not enough, why not go all the way and *prove* the
program correct? Tools like
[Rocq](https://rocq-prover.org/) (formerly Coq),
[Lean](https://lean-lang.org/), and [Isabelle](https://isabelle.in.tum.de/)
can in principle express, mechanically check, and force you to
discharge a proof that `sort` permutes its input and produces a
sorted list. So why bother with tests once we have that?

Two reasons.

First, formal verification is *expensive*. Verifying even a
modest piece of software is a research-grade undertaking,
typically requiring multiple times the original engineering
effort. The verified compilers (CompCert), kernels (seL4), and
crypto libraries (Fiat) that exist are real engineering triumphs;
each took person-years. For a typical application or library, a
proof is overkill.

Second, the *specification problem* does not go away. To prove
`sort` correct, you have to write down what "correct" means, in
the proof assistant's language, with full formality. That
specification might itself contain bugs. (Many real verification
projects discover that the *original* spec was wrong: "permutes"
is subtle when there are duplicates, "sorted" is subtle for
custom comparators.) Tests express the same property at less
formality, are vastly cheaper to write, and on a well-chosen
sample tell you most of what a proof would tell you.

We will not see formal verification in this course, except as a
distant reference. Tests are what you will reach for in
practice; this module is the introduction.

:::slide

## Why not just prove correctness?

- Formal verification is **expensive**: CompCert, seL4, Fiat each
  cost person-years.
- For typical code, **tests are vastly cheaper** and catch most
  of what a proof would catch.
- And the **specification problem** is real either way: writing
  down what "correct" means is its own challenge.
- This module: testing, the practical workhorse.
- Out of scope: formal verification (Rocq, Lean, Isabelle).

:::

## Faults and failures

A short note on vocabulary, taken from CS3110. The everyday word
*bug* is fine, but to be precise about what testing does, two
sharper terms help.

A *fault* is the human error in the code: the wrong operator, the
swapped arguments, the missing base case. Faults exist in the
source, often silently, before they have any visible consequence.

A *failure* is the observable violation of intended behaviour: the
`sort` that returns `[3; 1; 2]` when it should return `[1; 2;
3]`; the crashed program; the wrong invoice.

Dijkstra put the limit of testing in one sentence in 1970:
"Program testing can be used to show the presence of bugs, but
never to show their absence." A green suite does not certify the
faults are gone; it certifies that on the inputs we happened to
try, no fault produced a visible failure. That is exactly why the
next two lectures are about choosing inputs deliberately: the
value of a test is bounded by the cleverness of the input behind
it.

That pair gives the next two words one-line definitions.
*Testing* is the craft of turning faults into failures: driving
the program with inputs chosen so that the errors hiding in the
source produce behaviour we can observe. *Debugging* is the
reverse traversal: tracking an observed failure back to the
fault that caused it, and fixing that fault. A test suite that
"passes" does not say there are no faults; it says that for the
inputs we tried, no fault produced a visible failure. Choosing
inputs cleverly enough that the existing faults *do* fail is
the whole craft.

When a test does turn a fault into a failure, the remaining work
is *debugging*: tracing the visible failure back to the fault
that caused it. CS3110's advice here is to behave like a
scientist. Look at the evidence (the failing input, the wrong
output); form a hypothesis about what the code must be doing to
produce it; design the *smallest* experiment that would confirm
or refute the hypothesis (usually: a smaller input that still
fails); and repeat until the fault is cornered. The single most
useful debugging move is *shrinking the failing input*: a bug
report that says `sort [2; 1] = [2; 1]` points at the fault far
better than one that says a 10,000-element list came back
wrong. Hold that thought; when we reach property-based testing
you will see the library perform exactly this shrinking step,
automatically.

CS3110's chapter goes on to distinguish *black-box* testing
(write tests against the specification, ignoring the
implementation) and *glass-box* testing (write tests that exercise
every branch of the implementation). Both have a place. They get
a [whole lecture of their own](M09-L03-test-design.html) in this
module. For now, the vocabulary is enough.

:::slide

## Faults vs failures

- **Fault**: the human error in the source code. Silent, present
  even when the program "works".
- **Failure**: the observable bad behaviour. The crash, the wrong
  output, the broken invariant.
- **Testing**: turning faults into failures, so we can see them.
- **Debugging**: tracing a failure back to the fault that caused
  it, then fixing the fault.
- A green test suite means "we didn't trigger any fault on the
  inputs we tried", not "there are no faults".

:::

:::notes
Drop Dijkstra's line here: "Program testing can be used to show the
presence of bugs, but never to show their absence." (Notes on
Structured Programming, 1970.) It is the one-sentence version of the
green-suite bullet: passing means the faults we have did not fail on
the inputs we happened to try. That is exactly why the next lectures
are about choosing inputs deliberately.
:::

:::slide

## From failure to fault: debug like a scientist

- Evidence: the failing input and the wrong output.
- Hypothesis: what must the code be doing to produce this?
- Experiment: the *smallest* input that still fails.
  - `sort [2; 1] = [2; 1]` beats a wrong 10,000-element list.
- Refine and repeat until the fault is cornered.
- Property-based testing automates the shrinking step.

:::

## What types DO buy you, even with tests

A reasonable reader might wonder, at this point, whether the
type system is actually pulling its weight if you still have to
test the same code. The answer is yes.

A typed language *reduces the surface area you have to test*. In
Python or JavaScript, every function you write has to be tested
against malformed input: what happens when a string is passed
instead of an int, what happens when `None` is passed instead of
a list, what happens when an object is missing a field. Whole
test suites exist just to confirm that a function rejects
nonsense and produces sensible errors. In OCaml, those tests do
not exist, because the type checker rules out the situations
they would test. You write tests against *behaviour on
well-typed input*, which is a smaller surface.

The "snap-together" quality Real World OCaml mentions is real:
when types fit, a small number of tests often suffices, because
each test is *informative*. In a dynamically typed language you
would have to test the same behaviour with five different
malformed inputs to confirm the function survived; in OCaml the
type checker confirms most of that for free, and the tests can
focus on the interesting cases.

So tests pay back more, *per test*, in a typed language. That is
why a chapter on testing in an OCaml textbook is shorter than
the same chapter in a Python textbook, but no less important.
You write fewer tests; the ones you write matter more.

:::slide

## What do types buy you, even with tests?

- Dynamic-language suites are full of malformed-input tests:
  - wrong type, missing field, `None` where a list goes.
- In OCaml the type checker rules those inputs out
  - so those tests simply do not exist.
- Tests target *behaviour on well-typed input*
  - type shrink the test surface.
- Fewer tests, each more informative
  - RWO: types *raise* the value of every test you write.

:::

## A small concrete demonstration

Here is the example we will revisit through the module: a tiny
function we *think* is right, with a small set of hand-written
tests that probe its behaviour.

:::slide

## Five hand-written tests on `max3`

```ocaml
let max3 x y z =
  if x > y then
    if x > z then x else z
  else
    if y > z then y else z

let () =
  assert (max3 1 2 3 = 3);
  assert (max3 3 2 1 = 3);
  assert (max3 2 3 1 = 3);
  assert (max3 5 5 5 = 5);
  assert (max3 (-1) (-2) (-3) = -1);
  print_endline "max3 tests passed"
```

- Five specific cases. Each runs cheaply.
- Each is informative: "this input maps to that output."
- The tests give us confidence that `max3` is correct, but not proof.

:::

Five hand-written assertions, each a simple equality check
against a specific case. We run them; they all pass; we believe
the function. (This is the CS3110 textbook's `max3` example, a
stock teaching function; it returns in the
[test-design lecture](M09-L03-test-design.html) as the glass-box
specimen whose four paths we cover deliberately, and where these
five tests turn out to miss one of those paths entirely.)

But notice the limit of what these five assertions can tell us.
We have only checked the function on five specific inputs out of
the trillions of input triples that `int * int * int` admits. The
inputs we chose were the ones we *thought of*. A bug that only
shows up on, say, `max3 max_int 0 1` is still there if we did
not happen to try `max_int`. The five tests give us confidence,
not proof. That is the deal that testing makes: confidence,
scaled by the cleverness with which you pick inputs.

In [Lecture 4](M09-L04-unit-testing.html), we'll lift raw
`assert`s like these into the OUnit2 framework: each `assert`
becomes a named *test case*, the framework runs all of them, and
a failure points at the specific case that failed. In
[Lecture 5](M09-L05-property-based-testing.html), we'll go
further: instead of choosing the inputs ourselves, we'll
*generate* them randomly and check a *property* the answer
should satisfy. The property for `max3` is easy to state: the
answer equals one of the three inputs and is at least as large
as each of them. And when a generated input does fail a
property, you will watch QCheck *shrink* it to the smallest
failing case before reporting it.

## Activity: the well-typed sort

:::quiz mcq id=M09-L01-q1
A colleague gives you this implementation of `dedup`, which is
meant to remove duplicate elements from a list:

```text
let dedup (xs : 'a list) : 'a list = []
```

The OCaml compiler accepts it without warnings. What is the
strongest statement we can make about this function?

- [ ] It is correct, because the type checker would have caught
  any error.
- [x] It is well-typed but its behaviour does not match what
  "dedup" usually means.
- [ ] It is ill-typed; OCaml will refuse it.
- [ ] It has a parametricity-forced shape, so it must be the
  unique correct function.

**Why:** the function has type `'a list -> 'a list`, the same
type as `List.sort_uniq compare` and as the identity function
and as `List.rev`. The type checker has no way to say which of
these the author *meant*. A type-correct program can still have
wrong behaviour; this is the central point of the lecture.
Parametricity *does* constrain `'a list -> 'a list` somewhat
(the function cannot invent new `'a` values), but it does not
pin down the answer to a unique function: at minimum the
identity, `List.rev`, "return empty", and "return a list of the
input's first element repeated" all satisfy the type.
:::

:::quiz mcq id=M09-L01-q2
Which of the following bugs in a *well-typed* OCaml function is
caught at compile time, before any tests run?

- [x] Forgetting the `None` case in a `match` on an `option`
  value (a warning, not an error, but flagged by the compiler).
- [ ] Returning the wrong list element from a function that
  takes an `int list` and returns an `int`.
- [ ] Writing `String.sub s length start` when you meant
  `String.sub s start length` (both `int`s).
- [ ] Computing factorial with the recursive case `n * fact n`
  (forgetting the `- 1`), producing an infinite loop on any
  positive input.

**Why:** the missing-`None`-case is exactly what
[exhaustiveness warnings](M05-L05-exhaustiveness.html) catch.
The other three are behaviour bugs in well-typed code: returning
the wrong element type-checks (any element will do); swapping
two `int` arguments type-checks (both have the same type); and
a non-terminating recursive call type-checks (the type does not
record termination). Each requires a test to find.
:::

:::quiz mcq id=M09-L01-q3
"Tests are unnecessary in a strongly typed language like OCaml,
because the type checker already catches most bugs." Which of
the following is the most accurate response?

- [ ] Correct. OCaml programs that compile usually do not need
  tests.
- [ ] Incorrect, because OCaml's type system is much weaker than
  it appears.
- [x] Incorrect, because types catch type errors, not
  behavioural ones; the two are complementary.
- [ ] Correct in principle, but tests are cheap so we write them
  anyway.

**Why:** the right framing is that types and tests catch
*different categories* of mistake, and you need both. Types
catch type errors and a few parametricity-forced shapes, very
cheaply and on every build. Tests catch behaviour: wrong
outputs, swapped arguments of the same type, off-by-one bounds,
performance regressions. The two are complementary, not
substitutes. (And OCaml's type system is *not* weak, as the
preceding eight modules have shown; the gap that tests fill is
not weakness, it is a fundamental limit of any type system.)
:::

## Common pitfalls

A short list of mental traps to watch for as you build a testing
habit on top of an OCaml codebase.

**Pitfall 1: trusting the compiler too much.** "It compiles" is
not "it works." This module exists because that confusion is
common. Get into the habit of writing at least one test per
function before you trust it.

**Pitfall 2: testing only the cases your code already handles.**
The most dangerous tests are the ones written by inspecting the
implementation and confirming it does what it does. Test against
the *spec* (CS3110's "black-box" view), not just against the
code's existing branches.

**Pitfall 3: writing tests after every bug, never before.** It
is fine to add a regression test after a bug, but if every test
in your suite is a regression test, your test suite has only
ever found the bugs you already know about. Write tests against
intended behaviour, not just against past bugs.

**Pitfall 4: equating "all tests pass" with "no bugs."** The
test suite tells you the cases you tried did not fail. It does
not tell you the cases you did not try are fine. Systematic
[test-case design](M09-L03-test-design.html), PBT (Lecture 5),
and code coverage tools (`bisect_ppx`, covered with test design)
help close that gap, but never fully.

:::slide

## Common pitfalls

1. **"It compiles" is not "it works"**: at least one test per
   function, before you trust it.
2. **Testing what the code does**: test against the *spec*, not
   the implementation's existing branches.
3. **Only regression tests**: a suite of past bugs finds only
   the bugs you already knew about.
4. **"All tests pass" is not "no bugs"**: design, PBT, and
   coverage narrow the gap; nothing closes it.

:::

## What's next

This module has seven lectures: this one, two on deciding what
and how to test, three on the tools that mechanize those
decisions, and one tutorial that brings everything together on a
single worked example.

[Lecture 2](M09-L02-specifications-invariants.html) is about
*specifications*: the contract a function makes with its caller
(what it requires, what it returns, what it raises), and, for
data abstractions, the invariants an implementation must
maintain. A test checks code against a spec; without the spec
there is nothing to check.

[Lecture 3](M09-L03-test-design.html) is about *choosing test
cases*: black-box testing (boundaries and partitions of the
input space, read off the specification) and glass-box testing
(covering the paths through the implementation), plus the
coverage tooling that measures how much of the code your suite
actually exercises.

[Lecture 4](M09-L04-unit-testing.html) gives you a concrete
unit-testing tool: OUnit2. We will write tests for a small
`Stack` module, integrate it into `dune`, and watch the test
runner report a pass and a failure. That is the floor of
practical testing; you should be able to use it on every piece
of code you write from now on.

[Lecture 5](M09-L05-property-based-testing.html) introduces
property-based testing with QCheck. You will see why FP makes
PBT natural, watch the shrinker minimise a failing input, and
write your first generators.

[Lecture 6](M09-L06-model-based-testing.html) takes testing to
*stateful* code: a mutable queue is tested against a simple
reference implementation by generating random sequences of
operations and checking that the two agree.

[Lecture 7](M09-L07-tutorial.html) is the wrap-up tutorial:
the full toolkit applied to a small arithmetic evaluator,
with a deliberately buggy implementation that QCheck finds in
seconds.

:::slide

## What's next: the seven lectures of M9

Deciding what to test:

- L2: **Specifications and invariants.** Contracts, preconditions,
  rep invariants.
- L3: **Designing test cases.** Black-box, glass-box, coverage.

Mechanizing the checks:

- L4: **OUnit2 unit testing.**
- L5: **QCheck PBT.** Properties, shrinking, generators.
- L6: **Model-based testing.** Stateful data structures vs.
  a reference implementation.

Bringing it together:

- L7: **Tutorial.** The full toolkit on one evaluator.

:::

## Reading

- **Cornell CS3110**, *Testing and Debugging*:
  <https://cs3110.github.io/textbook/chapters/correctness/test_debug.html>
- **Cornell CS3110**, *Black-box and Glass-box Testing*:
  <https://cs3110.github.io/textbook/chapters/correctness/black_glass_box.html>
- **Real World OCaml**, *Testing*:
  <https://dev.realworldocaml.org/testing.html>

## Sources

This lecture's prose, worked examples, and quizzes are original
to this course. Materials referenced during preparation are
listed in the *Reading* section above; Cornell CS3110 and Real
World OCaml are CC BY-NC-ND-licensed and have not been
derivatively reused. The "well-typed sort that doesn't sort"
framing is folklore in the typed-FP community; the `max3`
function follows CS3110's testing chapter and is a stock
teaching example, attributed where it appears.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
