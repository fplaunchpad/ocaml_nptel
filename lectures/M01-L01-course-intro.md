---
title: "Course introduction: what you'll learn, how it's run"
lecture_no: 1
week: 1
duration_target_min: 15
concepts: [course logistics, syllabus overview, in-browser dev environment, grading]
keywords: [OCaml, NPTEL, functional programming, course intro, syllabus, FP]
activity_question: "How is the certification score split between weekly assignments and the final exam?"
think_about_this: "Why do you think the course bothers to teach functional programming at all, when most software you've used is written in imperative languages?"
reading:
  - title: "Functional Programming in OCaml (Cornell CS3110)"
    url: https://cs3110.github.io/textbook/
  - title: "Real World OCaml"
    url: https://dev.realworldocaml.org/
---

# Course introduction


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Course introduction: what you'll learn, how it's run</h2>
<p class="title-slide-label">Module 1 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Welcome to **Functional Programming with OCaml**. This first lecture
is short and almost entirely logistical: what we will cover over the
twelve weeks, who the course is aimed at, how it is graded, and how
you will run OCaml code directly in your browser without installing
anything. The [next lecture](M01-L02-why-fp.html) is where the actual
technical content begins.

I want to spend this opening session on framing rather than on syntax,
because the choices a course makes about what to teach are themselves
worth understanding. There are dozens of programming language courses
on [NPTEL](https://nptel.ac.in/) and elsewhere, and they make very
different choices about which language to use, which features to
emphasise, and how much mathematical content to include. By the end
of this lecture you should know what *kind* of course this is, and
whether it is the right one for what you want to learn next.

A quick note on the format. Every lecture in this course comes as
both a 20-30 minute recorded video, where I work through slides
with you, and a long-form chapter, which is what you are reading now.
The chapter elaborates on the same material, with more worked
examples, asides, pitfalls, and inline quizzes you can attempt.
The slides are the spine; the chapter is the body. If you only have
time for one, watch the video. If you want to really learn the
material, read the chapter afterwards.

:::slide

## Functional Programming with OCaml

- A 12-week NPTEL course on functional programming,
  - taught through OCaml,
  - with a strong second half on secure systems software.

- KC Sivaramakrishnan, IIT Madras. Most students call me "KC".

:::

## Who is this course for?

This is a course about programming languages, taught through one
particular language. The audience I have in mind is a third- or
fourth-year undergraduate in computer science who has written some
C, maybe some Java or Python, knows what a pointer is, knows what
a `for` loop is, and has taken a data structures and algorithms
course. If that's you, you have everything you need.

It is also a course for working software engineers who want to
broaden the set of language paradigms they are comfortable in.
Functional programming concepts have crossed over into mainstream
languages over the last decade: lambdas in C++ and Java, type
inference in Rust and TypeScript, pattern matching in Swift and
Python (since 3.10), immutable data structures everywhere. Working
in OCaml for twelve weeks gives you a coherent setting where all of
these ideas hang together, instead of feeling like bolt-ons to a
language designed for something else.

It is *not* a first programming course. We will not pause to explain
what a variable is or what a function call does. If those concepts
are still wobbly for you, work through any introductory programming
text first, then come back. The functional-programming half makes
occasional cross-language asides (Python, Java, C, Rust, and the
odd JavaScript) where they help orient the reader. The
secure-systems half (Modules 9 to 12) leans on C and C++ heavily as
the canonical "what unsafe languages do" baseline, so by then you
will want to be able to read C syntax casually.

:::slide

## Who is this course for?

- Undergraduate and postgraduate students in CS and related disciplines.
- Systems engineers, software developers, researchers.
- Anyone who wants to build reliable, type-safe software.

**Prerequisites:** C programming, basic data structures and algorithms.
Nothing more.

:::

## What you will learn

The course splits cleanly into two halves. The first eight modules
(weeks) teach functional programming proper, using OCaml as the
vehicle. We start with expressions and values, work up through
functions, data types, pattern matching, higher-order functions,
side effects, modules, and finally monadic abstractions and
generalised algebraic data types. By the end of Module 8 you will
be able to read and write idiomatic OCaml at the level of a working
professional, and you will have internalised the FP habits of
thought that transfer to every other language you will ever use.

The last four modules (weeks 9-12) cover secure systems software,
which sounds like a separate course but is intimately connected to
what we did in the first half. Module 9 takes the type-safety
intuition you built up over the first eight weeks and asks the
sharper question: what kind of bug does the type system structurally
*fail* to catch? The answer is "behaviour", and the response is
testing. We cover OUnit2 for unit tests and QCheck for property-based
testing, which is a particularly natural fit for a language where so
many functions are pure. Module 10 then turns to memory safety as a
security story. The reason we can talk about "undefined behaviour"
precisely in week 10 is that we will have spent eight weeks
pinning down what *defined* behaviour even means; week 10 names
the C memory bugs (use-after-free, buffer overflow, uninitialised
read, double-free) and shows how they become CVEs. The industry
numbers are stark: roughly 70% of the vulnerabilities Microsoft
fixes each year are memory-safety bugs (MSRC, 2019); the Chromium
project found about the same 70% share among its high-severity
bugs (2020); 76% of Android's vulnerabilities in 2019 were
memory-safety bugs in its native (C/C++) code (Google, *Memory
Safe Languages in Android 13*, 2022); and Google's Project Zero
found that roughly two-thirds of the 0-days exploited in the wild
in 2021 were memory-corruption bugs. The [White House February 2024
memorandum](M10-L01-memory-safety-and-security.html) urged the
industry toward memory-safe languages. Week 10 then shows how
OCaml rules each of these bug classes out by construction.
We also walk a [Heartbleed-style
example](M10-L05-tutorial.html) end to end. Module 11 picks up
where the vanilla type system stops:
[OxCaml](https://oxcaml.org), a research branch of OCaml maintained
by Jane Street, adds a *mode system* on top of the language we will
have learned by then; the modes extend the types with locality (safe
stack allocation), uniqueness (use-after-free of manually managed
resources, caught at compile time), and linearity (use exactly
once). Module 12 caps the course by asking
what falls out if a language is this safe: the answer is MirageOS,
where the operating system itself is an OCaml program.

:::slide

## The course map

![12-module course roadmap](/assets/diagrams/M01-roadmap.svg)

Eight FP modules, then four secure-systems modules.

:::

:::slide

## By the end of the course

- Write **idiomatic OCaml**.
- **Reason equationally** about your code.
- Back the type system up with **tests** (OUnit2, QCheck).
- Name the C bug classes OCaml rules out.
- Use [OxCaml](https://oxcaml.org) **modes** to close performance
  and safety gaps a **garbage collector (GC)** (automatic memory
  reclamation) alone cannot.
- Follow the safety story down to the **OS** ([MirageOS](https://mirage.io)).

:::

Three skills you will leave with, in increasing order of generality:

**You will write idiomatic OCaml.** Not just OCaml that compiles, but
OCaml that an experienced reviewer would glance at and nod.
Idiomatic means *the natural way* to express an idea in this
language: when to reach for a record instead of a tuple, when a
variant beats a class hierarchy, when pattern matching is clearer
than `if`, when a fold is clearer than a loop. Each of these choices
feels arbitrary at first and obvious in retrospect; the course is
largely about getting you to the second state.

**You will reason equationally about your code.** This is shorthand
for a habit of mind that functional programming makes possible. When
a function is pure (returns a value, has no side effects), you
can substitute equals for equals: replace any expression with its
value, replace any call with its body. This sounds like a small
thing and is in fact one of the larger differences between FP and
imperative programming. We will spend [the next lecture](M01-L02-why-fp.html#equational-reasoning)
setting up why this matters, and the rest of the course exercising
it.

**You will understand the safety story.** OCaml is one of a small
number of mainstream languages where memory safety is provided by
construction in the type system while staying within a small
constant factor of C and C++ in performance. Idiomatic OCaml is
often very close to C on tight code, sits in the same league as
Java or Go on typical workloads, and is dramatically faster than
dynamic languages like Python or Ruby. The safety is not paid for
with slowness: it comes from the type system ruling out, at
compile time, classes of undefined behaviour that C programs hit
at runtime. *Garbage collection* (the runtime feature that
reclaims memory automatically once a value is no longer reachable,
so you never call `free` by hand) helps on top, but the load-bearing
safety is in the types. The secure-systems half of the course makes
this concrete on three fronts. Where types reach their structural
limit (a well-typed function can still compute the wrong answer),
[Module 9](M09-L01-why-test-typed-code.html) brings in tests, both
unit tests and property-based tests, as the complement that catches
behaviour. Where vanilla OCaml's types reach *their* limit (stack
allocation, manually managed resources), [Module
11](M11-L01-locality.html) introduces OxCaml's mode system,
which extends the types to track *how* a value may be used, not just
*what* it is. In between, [Module
10](M10-L01-memory-safety-and-security.html) makes the memory-safety claim
precise: you will see what *defined* and *undefined* behaviour mean,
the C bug classes the GC plus types rule out, and where the OCaml
runtime itself draws the line.

## Why OCaml?

The choice of OCaml deserves some defense, because it is not the most
popular language and you might reasonably ask why we did not pick
Python or Rust or Haskell. The short answer is that OCaml is the
best teaching language for the *concepts* we want to teach. The
long answer comes in three parts.

First, OCaml is *functional-first* with a *serious* type system.
"Functional-first" means immutability, expressions, recursion,
and higher-order functions are the natural way to write programs,
the same way classes and inheritance are natural in Java. "Serious"
means the type system is sound: if your program type-checks,
certain classes of bugs simply cannot happen. Sound, expressive
type systems are uncommon. JavaScript and Python have no real
static types. C++ has a type system that lets you escape too
easily, via `reinterpret_cast`, `void*`, and pointer arithmetic.
Java's type system is sound, but its vocabulary forces you to
express optionality through nullable references and tagged unions
through class hierarchies, which means a lot of "did you remember
to handle this case?" lives at runtime instead of compile time.
Rust is the closest sibling to OCaml in this respect, and a lot
of Rust's design is directly inherited from ML (the family OCaml
belongs to). The name records that lineage: "OCaml" is *Objective
Caml*, and "Caml" was the *Categorical Abstract Machine Language*,
built at the French research institute INRIA in the 1980s on top
of Robin Milner's ML. The "Objective" arrived in 1996 with an
object system the course never uses; the functional core under
the name is the part that matters.

Second, OCaml is *practical*. It is used in production at
[Jane Street](https://www.janestreet.com) (whose internal systems
are millions of lines of OCaml),
[Bloomberg](https://www.bloomberg.com/company/values/tech-at-bloomberg/)
(financial infrastructure), Facebook (the [Hack](https://hacklang.org)
and [Flow](https://flow.org) type checkers for PHP and JavaScript
respectively, both written in OCaml),
[Docker](https://www.docker.com) (their virtualization toolkit),
[Ahrefs](https://ahrefs.com) (one of the world's largest web
crawlers and SEO platforms, with a backend in OCaml),
[Semgrep](https://semgrep.dev) (a static-analysis tool for finding
bugs and security issues, written in OCaml), and
[Tarides](https://tarides.com) (the OCaml platform company, builder
of MirageOS and the Multicore OCaml runtime). It powers
the [WebAssembly reference interpreter](https://github.com/WebAssembly/spec/tree/main/interpreter)
that defines the WebAssembly standard, and the
[CompCert](https://compcert.org) verified C compiler.
[Rust's first compiler](https://github.com/rust-lang/rust/tree/ef75860a0a72f79f97216f8aaa5b388d98da6480/src/boot)
was written in OCaml. So is the [Rocq theorem prover](https://rocq-prover.org)
(formerly Coq), and the [Tezos blockchain](https://tezos.com).
Beyond industry, OCaml is widely used across academia. "Practical"
here means: people use it to ship things that other people depend
on. This is not a research curiosity.

Third, OCaml is *fast*. The native-code compiler produces binaries
that run within a small constant factor of C for most workloads.
The garbage collector is incremental and concurrent in recent
versions. There is no virtual machine, no JIT warmup, no
interpretation overhead. When you write a tight loop in OCaml and
compile it to native code, you get something close to what you
would get from a C compiler. Functional programming has picked up
a reputation in some circles for being slow, often by association
with interpreted languages that happen to support functional
idioms; OCaml is the counterexample.

:::slide

## Why OCaml?

- **Functional-first**, with a serious type system.
- **Practical:**
  - Jane Street, Bloomberg, Meta (Hack, Flow), Docker,
    Tarides, Ahrefs, Semgrep.
  - WebAssembly reference interpreter
  - CompCert verified C compiler
  - Rust's first compiler was written in OCaml.
- **Fast:** native code close to C; GC; no UB in the safe fragment.
- **Great teaching language:** ideas reappear in Rust, Scala,
  Haskell, Swift, Kotlin, TypeScript.

:::

A fourth reason worth listing separately: OCaml is *small*. The core
language fits in a long afternoon: a handful of expression forms, a
handful of type constructors, a module system, a few sugar
constructs. Larger industrial languages (C++ is the classic example,
but Scala and modern Java are not far behind) accumulate so many
features over time that the surface area for surprise grows with
them. OCaml's smallness lets us spend lecture time on *why* things
are the way they are, rather than on enumerating syntax.

You will also be re-using almost everything you learn here in other
languages. Type inference, sum types (also called variants or
algebraic data types or "enums" in Rust and Swift), pattern matching,
higher-order functions, generics with parametric polymorphism, the
`Option` type as a replacement for null, immutability by default,
the `Result` type for error handling: every one of these has crossed
over into the mainstream of language design. OCaml is the language
where you can see them in their natural habitat, where they were
designed together as a coherent set rather than added later as
features.

## The course book

There is no separate textbook to buy or download. Every lecture in
this course is also a page on the course website at
**<https://fplaunchpad.org/ocaml_nptel>**, and the slides you see in
the videos are excerpts from those pages. The website is the book:
the same material, expanded into prose, with the examples runnable
in place and the quizzes interactive. Open it in any browser; no
login, no install, nothing to download.

:::slide

## The course book

- Lectures live at **<https://fplaunchpad.org/ocaml_nptel>**
- Slides are excerpts; the website carries the full prose.
- Runnable examples and inline quizzes are on the same page.
- No login, no install: open in any browser.

:::

:::notes
Point at the URL on screen. Emphasise that the website *is* the
textbook for this course; there is no PDF to chase, no separate
chapter to read. The same page you read also runs the code.
:::

## Run code right in this page

Before we get to the syllabus and grading, let me show you how the
course infrastructure works, because it shapes what you can do with
the lecture pages.

Every lecture has runnable OCaml cells embedded in it. Like this:

```ocaml
let greeting who = "hello, " ^ who
let () = print_endline (greeting "NPTEL")
```

If you are reading this in a browser, you should see a "Run" button
near the top right of the code block above. Click it. The OCaml
toplevel runs *in your browser* (no server, no install, the bytes
never leave your machine) and the output appears below the cell.
The first run takes a few seconds while the OCaml runtime loads
into your browser; subsequent runs are fast.

The toplevel embedded in these pages is **OCaml 5.4.0**, the
current stable release at the time of writing. If you decide to
install OCaml locally and follow along on the command line, use
[`opam`](https://opam.ocaml.org) (the OCaml package manager) to
create a `5.4.0` switch; everything in the lectures is checked
against that version.

You can edit the code. Try changing `"NPTEL"` to your own name and
clicking Run again. If you make a syntax mistake, you will see the
compiler error inline; fix it and run again.

:::slide

## Run code right in this page

- Every lecture has **runnable OCaml cells.**
- Click **Run**; output appears inline.
- Edit any cell, Run again.
- Nothing to install.
- Toplevel is **OCaml 5.4.0**; matches a local `opam` 5.4.0 switch.

```ocaml
let greeting who = "hello, " ^ who
let () = print_endline (greeting "NPTEL")
```

:::

:::notes
Click Run live so the audience sees [hello, NPTEL] appear inline. If
they ask: the OCaml toplevel runs in their browser via [x-ocaml]; no
server, no install, everything stays on their machine.
:::

The little ↺ button next to Run resets the cell back to its original
source if you have edited it. Your edits are saved in your browser's
local storage, so if you close the tab and come back, your code is
still there. This is meant to be a notebook, not a one-shot demo.

A useful feature you might not discover by yourself: hover the
mouse over an expression in any cell and the editor shows its
inferred type as a tooltip. This is the same information the
toplevel prints as `val name : type = value` after a Run, but you
get it inline without running anything. When you are reading
unfamiliar code, the hover is the fastest way to find out what a
particular sub-expression has type.

## A full machine for the second half

The cells you have just seen are the light tier of the course
infrastructure: an OCaml toplevel compiled to JavaScript, perfect
for trying out an expression or a small definition without leaving
the page. The functional-programming half of the course lives almost
entirely in cells like these.

The secure-systems half needs more than a toplevel. To run a test
suite, measure coverage, compile and run a C program, or build and
boot an operating system, you need a real project on a real machine:
`dune`, several source files, a test runner, a C compiler. So the
later lectures embed a *full Linux machine* that also boots inside
your browser tab. The promise is the same as the cells: nothing is
installed on your computer and nothing runs on a server; the entire
machine runs in the page. It is heavier than a cell (it boots on a
click and takes a few seconds to come up), so we bring it out only
where a real build matters: [Module
9](M09-L03-test-design.html) runs test suites and coverage reports,
[Module 10](M10-L01-memory-safety-and-security.html) compiles and
runs the C programs whose memory bugs we study, and [Module
12](M12-L03-mirageos.html) builds and boots a MirageOS unikernel.

Here is one now, as a taste of what is coming. Click to boot it; you
land in a small `dune` project called `hello`. Run `dune exec
./hello.exe` to build and run it, edit `hello.ml` with `nano`, and
run it again.

:::slide

## A full machine for the second half

- The toplevel cells are the **light tier**: one expression, instant.
- Later modules need a real project: `dune`, several files, a test
  runner, a C compiler.
- So they embed a **full Linux machine**, also booted in your
  browser tab (Modules 9, 10, 12).
- Boots on a click; same promise: nothing installed, nothing on a
  server.

:::vm-terminal dir=/root/hello
:::

:::

:::notes
Click Boot live so the audience sees a real shell come up, then
`dune exec ./hello.exe`. Stress that this is the same "nothing
leaves your machine" promise as the cells, just a whole Linux box
instead of a toplevel. Don't dwell: it is a teaser for the
secure-systems half, not a `dune` tutorial.
:::

## Anonymous quiz analytics

A small operational note. The site records *anonymous* responses to
the inline quizzes, so I can see which questions are hardest and
revise the surrounding material. No personal data is collected; no
account exists; no IP address is retained. A random reader
identifier is stored in your browser to associate your answers with
each other (so I can tell two responses came from the same reader)
and that identifier is the only thing tying responses together. The
methodology mirrors the [Brown PLT TRPL quiz study](https://rust-book.cs.brown.edu/)
that motivated the inline-quiz design.

If you would prefer to opt out, the [Privacy page](privacy.html) has
a one-click toggle and a "delete my data" button that scrubs every
response associated with your browser. The toggle is per-device, so
turning it off on your laptop does not affect your phone. Opting
out has no effect on grading or on your ability to use the cells
and quizzes locally.

Below the cell, look for inline quizzes (which I will show you in
later lectures). They come in two flavours: multiple-choice questions
with explanations, and code-completion challenges where you fill in
a function and click *Check* to run a set of tests against your
solution. Both are optional but recommended; they're the difference
between thinking you understood a chapter and actually understanding
it.

## A taste of OCaml

Here is something you will be able to write yourself by Week 6. Don't
worry about understanding the syntax now. Just click Run and look at
what comes out.

:::slide

## A taste: primes from a list

```ocaml
let rec sieve = function
  | [] -> []
  | p :: rest ->
      p :: sieve (List.filter (fun n -> n mod p <> 0) rest)

let rec range a b = if a > b then [] else a :: range (a + 1) b
let nums = range 2 50
let _ = sieve nums
```

Press **Run.** Output: the primes up to 50.

- Try `range 2 100`, `range 2 1000`.
- First argument stays at 2 (sieve assumes the head is prime).
- You will write this from scratch by Week 6.

:::

:::notes
This is the teaching sieve, not the efficient one. It's quadratic in
the number of primes and allocates a fresh list at every step. Worth
mentioning offhand if anyone asks; do not labour it. The point is
"five lines, runnable, OCaml", not algorithmic efficiency.
:::

The output is a list of integers, in OCaml notation: `[2; 3; 5; 7;
11; 13; 17; 19; 23; 29; 31; 37; 41; 43; 47]`. Those are the primes
up to 50, computed by a version of the
[Sieve of Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes)
that fits in five lines. Without explaining anything yet, notice
a few things.

There is no loop in this code. There is no mutable counter, no
`++`, no array index. The function `sieve` is *recursive*: it calls
itself on a smaller input. The function `range` does the same. This
is how you express iteration in OCaml.

The line `| p :: rest -> ...` is [*pattern matching*](M05-L01-basic-patterns.html):
it says "if the input list has a first element `p` followed by some
rest, do the following." If you have written `switch` in C or Java,
pattern matching is like that but on the *structure* of values, not
just on their tags.

The expression `fun n -> n mod p <> 0` is an *anonymous function*: a
function with no name, defined inline. We pass it as an argument to
[`List.filter`](M06-L03-filter.html). Passing functions around like
this is normal in OCaml and central to what makes the language
compact. We will spend [Module 6](M06-L01-functions-revisited.html)
on this idea alone.

The point of showing you this in lecture one is not to teach the
syntax. It's to set the bar: in twelve weeks, you will look at this
five-line program and read it as easily as you would read a `for`
loop today. That is the destination. The route there is the rest of
the course.

## How the course is graded

NPTEL courses follow a standard grading structure that I do not
get to change. The split is 25% weekly assignments, 75% final
certification exam, with a 40% overall threshold to receive a
certificate.

:::slide

## How the course is graded

- **25%** weekly assignments (one per week).
- **75%** final certification exam (proctored, in person at NPTEL exam centres).
- **40%** overall to receive a certificate.

:::

A few details worth knowing. Assignments are released on the same
weekly cadence as the videos and are submitted through the SWAYAM
portal. Submission deadlines are strict: the portal closes at the
deadline. NPTEL does not allow late submissions and I cannot make
exceptions. The exact format of each assignment (how much OCaml
you write, how much is multiple-choice, how it is auto-graded) is
finalised closer to release; treat the assignment page as the
authoritative source for that week.

The final exam is conducted in person by NPTEL at their proctored
exam centres across India. NPTEL sets the exam format; details will
be confirmed on the SWAYAM platform before the exam window. Whatever
the format, the questions will test real understanding of the course
material rather than memorised syntax.

The 40% threshold for a certificate is the standard NPTEL pass mark.
Most students who follow along weekly comfortably clear it. The
distribution of marks in past iterations of similar courses has
been wide; serious engagement gets you well above 40%.

## The structure of each week

Every week of the course follows the same shape, so you can plan
your time once and then run on autopilot.

:::slide

## The structure of each week

Every week of the course follows the same shape:

- **5 to 7 short videos**, 20 to 30 minutes each. One concept per video.
- **A tutorial video** at the end of the week that walks through
  problems of the same flavour as that week's assignment.
- **One assignment** released alongside the videos.
- **A discussion forum** on the NPTEL platform; monitored by
  the TAs and me through the week.

:::

The videos are deliberately short. Past experience with longer lecture
videos shows that engagement falls off sharply past 30 minutes, so I
have broken each topic into bite-sized pieces. You can watch one a
day over the working week and finish the week's content without ever
sitting down to a long session. The chapter pages (these documents
you are reading) elaborate on each video and are meant as the
read-after-watching companion.

The tutorial video at the end of each week is important. It is
not a walkthrough of that week's assignment; instead, it works
through 2-3 problems that exercise the same ideas, with me
deriving the solutions on the fly. If you find an assignment
problem hard, the tutorial is the first place to look: the
techniques you need will have been demonstrated there.

The discussion forum is your main channel for questions. The
teaching assistants and I monitor it through the week. Use it.
Asking questions
in public also helps the other students who had the same question
but were too shy to ask.

## What this course is not

There are several large topics that this course *does not* cover,
and a student who came in expecting them would be disappointed.

:::slide

## What is *not* in this course

- **Not** building a production system from scratch.
- **Not** surveying every OCaml feature; just the load-bearing
  subset.
- **Not** pure type theory; we use a little where it helps.

Follow-on reading:
[CS3110](https://cs3110.github.io/textbook/),
[Real World OCaml](https://dev.realworldocaml.org/).

:::

We will not build a production system from scratch. That is a real
software-engineering course, and a worthwhile one, but not this
course. The longest piece of code you will write in this course
fits on one screen.

We will not survey every feature of OCaml. The language has many
corners: objects and classes (rarely used in modern code), ppx
syntax extensions (a tooling topic of its own), polymorphic variants (mostly
specialised), first-class modules (advanced),
[GADTs](M08-L04-gadts-basics.html) (we touch them briefly), effect
handlers (a Multicore OCaml feature we leave for a follow-on
course). I have picked the subset that will be most useful to you in
the largest number of future situations.

We will not do pure type theory. This is a programming course, not
a programming-languages-theory course. I will use type-theoretic
language ("polymorphism", "parametricity", "soundness") where it
helps explain something, and I will not when it does not. If you
do want the theory companion, [Pierce's *Types and Programming
Languages*](https://www.cis.upenn.edu/~bcpierce/tapl/) is the
standard reference, and
[*Software Foundations*](https://softwarefoundations.cis.upenn.edu/)
(Pierce et al., free online) takes you through the same material
mechanised in Rocq (formerly Coq).

## A quick checkpoint

Before we move on, a small comprehension check on what we just
covered. Use it to see whether the logistics are clear.

:::quiz mcq id=M01-L01-q1
The certificate grade for this course is computed as:

- [ ] 50% weekly assignments + 50% final exam
- [x] 25% weekly assignments + 75% final exam
- [ ] 100% final exam (assignments don't count)
- [ ] 75% weekly assignments + 25% final exam

**Why this matters:** the final exam is the bigger lever, but
weekly assignments are still 25% of your grade and a much easier
way to bank marks. The students who miss assignments and then try
to make it up in the final usually struggle: 75% is high but you
have to clear it from a cold start. Doing weekly assignments also
teaches the material; the final exam tests that you learned.
:::

:::quiz mcq id=M01-L01-q2
How is the course split across the 12 modules?

- [ ] 12 modules on functional programming
- [ ] 6 modules on FP, 6 on secure systems
- [x] 8 modules on FP, then 4 on secure systems
- [ ] 4 modules on FP, then 8 on language theory

**Why:** Modules 1-8 are functional programming proper
(expressions, functions, data types, pattern matching,
higher-order functions, side effects, modules, monadic
abstractions). Modules 9-12 turn the type-safety story toward
secure systems: testing (OUnit2, QCheck) for what types miss,
memory safety as a security story, OxCaml's mode system, and
MirageOS unikernels. The two halves are connected: the safety
claims in weeks 9-12 only make sense once you know what the
types in weeks 1-8 actually guarantee.
:::

:::quiz mcq id=M01-L01-q3
What does it mean that the OCaml toplevel "runs in your browser"
on the lecture pages?

- [ ] The page sends your code to a remote server, which runs it
      and returns the output.
- [x] The OCaml runtime is loaded into the browser; your code
      runs locally and never leaves your machine.
- [ ] You need to install OCaml first; the page just shows the
      source code.
- [ ] Only the instructor can edit and run the cells.

**Why:** every lecture's Run button starts an OCaml toplevel
that has been compiled to JavaScript and loaded into the page.
Code you type into a cell executes in your browser tab, so
there is no server to talk to, nothing to install, and your
edits stay on your device (saved in the browser's local
storage). The first run takes a few seconds while the runtime
loads; subsequent runs are fast.
:::

## What's next

Next video: [**why functional programming?**](M01-L02-why-fp.html)
The case for FP given that you can already write programs in
imperative languages. We will start by looking at a one-instruction
programming language (yes, really) and noticing what makes it hard
to read, then look at how functional programming makes programs
easier to read instead.

:::slide

## What's next

- Next video: **why functional programming?**
- The case for it, given that you can already write programs.

:::

## Reading

- The OCaml language home page: <https://ocaml.org/>. Install
  instructions, the [language manual](https://ocaml.org/manual/),
  and a tour of the ecosystem live here.
- Cornell **CS3110** textbook, Preface and Chapter 1:
  <https://cs3110.github.io/textbook/>
- **Real World OCaml**, Prologue:
  <https://dev.realworldocaml.org/prologue.html>
- The NPTEL course page (you're already there).
- John Whitington, *OCaml from the Very Beginning* (book): a
  gentler pace, useful as a parallel read if you find this course
  moving too quickly.
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
