---
title: "Data races are undefined behaviour"
lecture_no: 3
week: 10
duration_target_min: 24
concepts: [data race, undefined behaviour, domains, parallelism, memory model, happens-before, DRF-SC, local DRF, Atomic, Mutex, memory safety]
keywords: [OCaml, data race, undefined behaviour, Domain, parallelism, memory model, happens-before, DRF-SC, local DRF, bounded in space and time, Atomic, Mutex, multicore, C, C++]
activity_question: "What makes a pair of memory accesses a data race; how a racy program differs between C and OCaml; what a race on one ref can do to an unrelated ref; and rewriting a shared counter to use Atomic."
think_about_this: "The same racy program prints the right answer on one machine and the wrong answer on another, and the wrong answer changes from run to run. If a test passed yesterday, what does that tell you about whether the race is gone?"
reading:
  - title: "OCaml manual, The memory model for the multicore runtime"
    url: https://ocaml.org/manual/5.4/memorymodel.html
  - title: "Bounding Data Races in Space and Time (PLDI 2018)"
    url: https://kcsrk.info/papers/pldi18-memory.pdf
  - title: "OCaml manual, Module Atomic"
    url: https://ocaml.org/manual/5.4/api/Atomic.html
---

# Data races are undefined behaviour


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Data races are undefined behaviour</h2>
<p class="title-slide-label">Module 10 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The first lecture listed four categories of undefined behaviour in
C, and we have spent two lectures on the memory and lifetime
categories. This short lecture takes the one we have so far only
named: the *concurrency* category, and specifically *data races*,
the bugs that appear when a program runs on more than one core at
once.

Almost all the code in this course has been single-threaded: one
sequence of steps, one at a time. Real systems are not like that.
A web server handles thousands of connections; a build tool
compiles many files; a renderer paints many tiles. To use the
cores a modern machine has, the program must do several things *at
the same time*, and the moment two of those things touch the same
piece of memory, we have to ask what happens.

The answer in C and C++ is stark: a data race is undefined
behaviour, with all the consequences the first lecture described.
The answer in OCaml is different and much safer, and the difference
is exactly the kind of guarantee a later module builds on. This
lecture keeps to the essentials: what a race is, *precisely*; what
C says; what OCaml says; and how to fix one. The precision is not
pedantry. Every guarantee in this story is a guarantee about
programs "without data races," and such a guarantee is only as
sharp as the definition of a data race it rests on.

:::slide

## Framing

- So far: single-threaded code, one step at a time.
- Real systems use many cores at once.
- What happens when two cores touch the same memory?
  - in C/C++: undefined behaviour.
  - in OCaml: weaker than sequential, but still memory-safe.
- First job: define a *data race* precisely.
  - every guarantee below is only as sharp as this definition.

:::

## What a data race is

A *data race* is a precise thing, not just "concurrency went
wrong." Two threads race when they make two memory accesses (each a
read or a write) such that:

- the accesses target the **same location**,
- at least **one of them is a write**, and
- **no synchronisation** orders one access before the other.

The third condition is the precise version of "at the same time."
Nothing in the program (a lock, a join, an atomic operation) decides
which access goes first, so on any given run either might. Two reads
racing is fine: neither changes anything, so the order does not
matter. A read racing with a write, or two writes racing, is the
problem: the result depends on who got there first, and nothing in
the program decided who that was.

In C, the smallest racy program is two threads, one writing a
location, one reading it, with nothing ordering the two accesses:

```c
long x = 0;                 /* condition 1: the same location, x */

void *t1(void *_) { x = 1;      return NULL; }  /* 2: one is a write */
void *t2(void *_) { long r = x; return NULL; }  /* ... one reads     */

/* main starts t1 and t2 together; no lock, no join between
   the accesses: condition 3, nothing orders them */
```

:::slide

## What a data race is

```c
long x = 0;                 /* condition 1: the same location, x */

void *t1(void *_) { x = 1;      return NULL; }  /* 2: one is a write */
void *t2(void *_) { long r = x; return NULL; }  /* ... one reads     */

/* main starts t1 and t2 together; no lock, no join between
   the accesses: condition 3, nothing orders them */
```

- Same location, at least one write, no synchronisation ordering
  the two.
  - "no synchronisation" is the precise "at the same time".
- Two reads racing is fine; a write in the mix is the problem.

:::

## In C and C++, a data race is undefined behaviour

The C and C++ standards place a data race squarely in the undefined
category. A program with a data race has no defined meaning at all,
exactly like an out-of-bounds write or a use-after-free. Note the
scope of that sentence: it is the *whole program* that loses its
meaning, not just the racy line. A concurrent C program containing a
single data race, anywhere, can do anything at all. The optimiser is
allowed to assume races do not happen and to transform code on that
assumption, and the transformations are not confined to the racy
location: a race on one variable can make two reads of a completely
unrelated variable disagree, with no concurrent write to that
variable anywhere in the program. We will return to this point on
the OCaml side, because it is exactly the failure OCaml's memory
model rules out.

The most visible everyday symptom is *lost updates*. Here is a
small C program: two threads each add `1` to the same counter a
million times, with no lock. The arithmetic says the total should
be two million. It is not, and it changes from run to run, because
`counter++` is really three steps (read, add one, write back) and
the two threads interleave those steps and overwrite each other.

```c
#include <pthread.h>
#include <stdio.h>

static long counter = 0;          /* shared, unsynchronised */
void *bump(void *_) {
    for (int i = 0; i < 1000000; i++)
        counter++;                /* read + add + write: RACE */
    return NULL;
}

int main(void) {
    pthread_t first, second;
    pthread_create(&first, NULL, bump, NULL);   /* start thread 1 */
    pthread_create(&second, NULL, bump, NULL);  /* start thread 2 */
    pthread_join(first, NULL);                  /* wait for both */
    pthread_join(second, NULL);
    printf("expected 2000000, got %ld\n", counter);
}
```

The two `pthread_create` calls are the missing concurrency: both
threads execute `bump` against the same global `counter`. The two
`pthread_join` calls wait until they finish before printing. There is
no lock between the read and write inside `counter++`, so the accesses
race.

On a multi-core machine the lost updates are plain (the in-browser
VM has a single emulated core, so it cannot reproduce them, which
is itself a lesson: a race can hide entirely depending on the
hardware and the schedule):

```text
$ cc -O0 -o race race.c -lpthread && ./race
expected 2000000, got 1002878
$ ./race
expected 2000000, got 1018160
```

That is the *benign* face of the bug. The malign face is that,
because the race is UB, the optimiser may do far worse than lose a
few updates: it can cache the counter in a register, reorder the
writes, or delete code it "proves" is unreachable. As with every
other UB, "it printed the right number on my machine" is not
evidence that the race is gone.

:::slide

## C/C++: a data race is undefined behaviour

```c
pthread_create(&first, NULL, bump, NULL);
pthread_create(&second, NULL, bump, NULL);
/* both threads run: counter++;  no lock */
```

```text
$ ./race
expected 2000000, got 1002878
$ ./race
expected 2000000, got 1018160
```

- `counter++` is read, add, write: the threads interleave and lose
  updates.
- It is UB: the optimiser may do far worse than lose updates.
  - one race, anywhere, and the *whole program* can do anything.
- The total changes run to run; a passing test proves nothing.

:::

## OCaml 5 runs in parallel: domains

To talk about what OCaml does, we need the one parallelism
primitive this course uses: the *domain*. A domain is a unit of
parallel execution that runs on its own core. `Domain.spawn f`
starts a new domain running the function `f`, and `Domain.join`
waits for it to finish and collects its result.

That is the whole of the API we need. Two domains running at the
same time, each doing its own work, rejoining at the end. We are
not building a concurrency library; we just need two things running
at once so we can ask what happens when they share memory.

:::slide

## OCaml 5 runs in parallel: domains

<img src="/assets/diagrams/M10-domains.svg" alt="Domain.spawn and Domain.join timeline" style="height: 440px;">

- `Domain.spawn f` runs `f` on another core.
- `Domain.join d` waits for it and returns its result.
- That is all the API we need: two things running at once.

:::

## A racy OCaml counter

Now the same shape as the C program, in OCaml: a shared `int ref`,
two domains each incrementing it a million times, no
synchronisation.

```text
let counter = ref 0
let bump () =
  for _ = 1 to 1_000_000 do
    incr counter
  done
let () =
  let d1 = Domain.spawn bump in
  let d2 = Domain.spawn bump in
  Domain.join d1; Domain.join d2;
  Printf.printf "expected 2000000, got %d\n" !counter
```

Run on a multi-core machine:

```text
$ ocaml race.ml
expected 2000000, got 1039996
$ ocaml race.ml
expected 2000000, got 992593
```

The same lost updates as the C version: `incr counter` is read,
add, write, and the two domains interleave. But notice what did
*not* happen: the program did not segfault, did not read an
operating-system secret, did not corrupt the heap. It returned a
wrong-but-bounded integer. That difference is the whole point of
this lecture.

:::slide

## A racy OCaml counter

```text
let bump () =
  for _ = 1 to 1_000_000 do
    incr counter
  done
(* two domains run bump on the shared `counter` ref *)
```

```text
$ ocaml race.ml
expected 2000000, got 1039996
$ ocaml race.ml
expected 2000000, got 992593
```

- Same lost updates as C: `incr` is read, add, write.
- But **no segfault, no heap corruption, no OS-secret leak**.
- A wrong-but-bounded integer, not undefined behaviour.

:::

## OCaml's position: defined, and bounded

OCaml 5's memory model (the manual devotes a chapter to it) starts
from the same definition we gave. The locations are the mutable
ones: ref cells, array elements, mutable record fields. The
synchronisation that orders accesses comes from the operations
built for the purpose: `Domain.spawn` orders everything before the
spawn ahead of the new domain's first step; `Domain.join` orders
the joined domain's last step ahead of everything after the join;
locking a `Mutex` and operations on an `Atomic.t` cell create order
the same way. Two accesses to the same mutable location, at least
one a write, ordered by none of these: a data race, the same three
conditions as in C. The shared definition is the point. C and OCaml
agree on what a race *is*; they part company on what a race *does*.

The first half of OCaml's answer is summarised by the initials
*DRF-SC*. The *SC* is *sequential consistency*: a program is
sequentially consistent when it behaves exactly as if all the steps
of all its domains were interleaved into a single global order. That
is the single-threaded intuition you already have, lifted to many
cores; it is the behaviour you would *want*. *DRF-SC* is then the
guarantee that *data-race-free programs are sequentially consistent*:
if your program has no data races, you get that global-order
behaviour and need not think about reorderings at all. C and C++
promise this much too. That is the case to aim for, and the
synchronisation tools below get you there.

The second half is where the languages part. If your program *does*
have a race, OCaml still makes a promise that C and C++ refuse to
make: the behaviour is *weakly defined but bounded*, and the
program stays **memory-safe**. A racy read of an `int` returns some
value that was actually written to that location at some point, not
a random bit pattern. A racy read of a boxed value (a record or
array) may observe an earlier or a partially updated state, but
never a wild pointer into unmapped memory. There is no path from an
OCaml data race to a use-after-free or an out-of-bounds read. The
four-bug zoo stays closed even under races.

The promise is in fact sharper than "memory-safe," and sharp enough
to have a name: in OCaml, data races are *bounded in space and
time*. Bounded in space: a race on one location cannot affect any
other location. Bounded in time: a race cannot reach into the
race-free stretches of the run before or after it. Together, every
data-race-free *part* of the program keeps its sequential meaning,
even while some other part is racing; the property is called *local
DRF* (local data-race freedom). One concrete consequence: if a
domain reads the same ref twice and nothing writes that ref
concurrently, the two reads agree, whatever races are raging
elsewhere in the program. That is exactly the guarantee we saw the
C optimiser break. Java's memory model, for comparison, bounds
races in space but not in time. And the stronger promise is cheap:
the sequential cost of providing it is zero on x86 and under a
percent on ARM.

:::slide

## Sequential consistency, and DRF-SC

- **Sequential consistency (SC)**: all domains' steps interleave
  into one global order.
  - the single-threaded intuition, lifted to many cores.
- **DRF-SC**: a data-race-free program is sequentially consistent.
  - C, C++, and OCaml all promise this.
- With a race, the languages part:
  - C / C++: **undefined behaviour**.
  - OCaml: **weakly defined but bounded**, still memory-safe.
- Under a race OCaml keeps **type safety**, hence memory safety.
  - a racy read returns a value really written, never a wild pointer.

:::

:::slide

## Bounded in space and time

<img src="/assets/diagrams/M10-bounded-races.svg" alt="A race confined to one location and one stretch of the run; other locations and times keep their sequential meaning" style="height: 400px;">

- Every race-free *part* keeps its sequential meaning ("local DRF").
- Read a ref twice, no concurrent writes: both reads agree.
  - in C/C++, a race on an *unrelated* variable can break this.

:::

:::slide

## C UB vs OCaml bounded

| | C / C++ | OCaml 5 |
| --- | --- | --- |
| Race-free program | sequentially consistent | sequentially consistent |
| Racy program | **undefined behaviour** | weakly defined but **bounded** |
| Can a race segfault or leak OS memory? | yes | no |
| Can a race on `x` corrupt `y`? | yes | no: bounded in **space** |
| Can a race corrupt the race-free rest of the run? | yes | no: bounded in **time** |

OCaml's racy programs give *surprising values*; C's racy programs
give *anything at all*.

:::

## The fix: synchronisation

The cure for a data race is the same in every language: knock out
the third condition of the definition. Introduce synchronisation
that orders one access before the other, and the pair no longer
races. OCaml's standard library gives two everyday tools.

For a single shared counter or flag, use `Atomic`. An `Atomic.t`
wraps a value so that `Atomic.incr`, `Atomic.get`, and friends are
indivisible: no other domain can interleave inside one of them.
Swapping `ref`/`incr` for `Atomic.make`/`Atomic.incr` removes the
race:

```ocaml
let counter = Atomic.make 0

let bump () =
  for _ = 1 to 1_000_000 do
    Atomic.incr counter
  done

let () =
  let d1 = Domain.spawn bump in
  let d2 = Domain.spawn bump in
  Domain.join d1;
  Domain.join d2;
  Printf.printf "expected 2000000, got %d\n" (Atomic.get counter)
```

Now each increment is one indivisible operation. Another domain may
run before or after it, but cannot slip a read or write into its middle.
Running the program therefore prints the same total every time:

```text
$ ocaml atomic.ml
expected 2000000, got 2000000
$ ocaml atomic.ml
expected 2000000, got 2000000
```

For anything more than a single word (updating two fields together,
a list, a hash table), wrap the shared state in a `Mutex`: take the
lock, do the update, release the lock, so only one domain is inside
the critical section at a time. `Atomic` for one cell, `Mutex` for
compound state, is the whole rule of thumb.

:::slide

## The fix: synchronisation

- `Atomic` for one cell: `Atomic.incr`, `Atomic.get` are
  indivisible.
- `Mutex` for compound state: lock, update, unlock.

```ocaml
let counter = Atomic.make 0
let bump () =
  for _ = 1 to 1_000_000 do
    Atomic.incr counter
  done
```

- Synchronisation orders the accesses: the third condition falls,
  the race is gone.

:::

## Activity

:::quiz mcq id=M10-L03-q1
Which of the following pairs of accesses is a *data race*?

- [ ] Two domains reading the same `int ref`, with no writes.
- [x] One domain writes a ref while another reads it, with no
  synchronisation.
- [ ] One domain writes a ref, a `Domain.join` completes, and then
  another domain reads it.
- [ ] Two domains write separate refs, so no location is shared.

**Why:** a data race needs the same location, no synchronisation,
and at least one write. Two reads do not race (neither changes
anything). Separate locations do not race. A write followed by
`Domain.join` and then a read *is* synchronised: the `join`
orders the write before the read. The only racing pair is the
unsynchronised write-and-read of the same location.
:::

:::quiz mcq id=M10-L03-q2
A program has a data race on a shared `int ref`. How do C and
OCaml differ in what can happen?

- [ ] Both are undefined behaviour; there is no difference.
- [x] In C the program has undefined behaviour (it may crash, leak
  memory, or be miscompiled); in OCaml the read returns a
  surprising but bounded value and the program stays memory-safe.
- [ ] In OCaml the program fails to compile because the race is
  detected statically.
- [ ] In C the value is always the last one written; in OCaml it
  is always zero.

**Why:** C and C++ classify any data race as undefined behaviour,
so the optimiser may assume it away and the program may do
anything, including crash or leak. OCaml's memory model keeps a
racy program memory-safe: reads return values that were genuinely
written at some point, never wild pointers or OS secrets, and the
damage is bounded in space and time (local DRF). OCaml
does not detect races at compile time today (that is the kind of
guarantee a later module works toward), and the racy value is
"surprising," not a fixed constant.
:::

:::quiz mcq id=M10-L03-q4
Two domains race on a ref `x`. A third domain, meanwhile, runs
`y := 1` and then reads `!y`, and no other part of the program
touches `y`. What does the read of `!y` give?

- [x] In OCaml, `1`, guaranteed: races are bounded in space, so
  the race on `x` cannot affect `y`. In C, no guarantee: one race
  anywhere strips the whole program of defined meaning.
- [ ] `1` in both languages: `y` is not involved in the race.
- [ ] In OCaml, `1` only if `y` is made an `Atomic.t`.
- [ ] In neither language is anything guaranteed once any race
  exists.

**Why:** this is local DRF at work. OCaml bounds a race in space
(locations other than `x` are unaffected) and in time (race-free
stretches keep their sequential meaning), so the race-free
write-then-read of `y` returns `1`. In C and C++ a single data race
anywhere makes the whole program undefined; the optimiser may
transform code touching `y` on the assumption that no race exists
(we saw a race on one variable corrupt reads of another). No
atomicity is needed for `y`, because nothing races on `y`.
:::

:::quiz code id=M10-L03-q3
Rewrite the counter to use an atomic. Write
`add_n : int Atomic.t -> int -> unit` that increments the atomic
`n` times with `Atomic.incr`. (Two domains calling it concurrently
would then not lose updates; here we just check it counts.)

```ocaml
let add_n c n =
  failwith "not implemented"
```

```ocaml skip
let () =
  let c = Atomic.make 0 in
  add_n c 5;
  assert (Atomic.get c = 5);
  add_n c 3;
  assert (Atomic.get c = 8);
  print_endline "all tests passed"
```
:::

:::solution

A reference solution loops `n` times, incrementing the atomic:

```ocaml
let add_n c n =
  for _ = 1 to n do Atomic.incr c done
```

`Atomic.incr` is indivisible, so even when two domains call `add_n`
on the same counter at once, no increment is lost.

:::

## What's next

We have now seen all four UB categories from the first lecture, and
how OCaml handles each. The
[next lecture](M10-L04-where-ocaml-has-ub.html) turns the lens on
OCaml itself: the small set of escape hatches where the language
*does* admit undefined behaviour, and the safety of resources
beyond memory (file descriptors, sockets). The
[tutorial](M10-L05-tutorial.html) then walks one real CVE end to
end. The data-race story here is also the baseline a later module
improves on, turning data-race-freedom from a runtime hope into
something the type checker can help guarantee. A checker can only
enforce a property that has a precise definition; that is why this
lecture insisted on one.

:::slide

## What's next

- Next: where OCaml itself has UB, and resource safety beyond
  memory.
- Then: walk Heartbleed end to end.
- A later module turns data-race-freedom into a type-level
  guarantee.
  - a checker needs the precise definition we started from.

:::

## Reading

- **OCaml manual**, *The memory model for the multicore runtime*:
  <https://ocaml.org/manual/5.4/memorymodel.html>
- **Dolan, Sivaramakrishnan, Madhavapeddy**, *Bounding Data Races
  in Space and Time* (PLDI 2018), the paper behind OCaml's memory
  model: <https://kcsrk.info/papers/pldi18-memory.pdf>
- **OCaml manual**, *Module `Atomic`*:
  <https://ocaml.org/manual/5.4/api/Atomic.html>

## Sources

This lecture's prose, C and OCaml examples, captured transcripts,
and quizzes are original to this course. The data-race definition
and the happens-before reading follow the OCaml manual's
memory-model chapter; the bounded-in-space-and-time (local DRF)
treatment follows *Bounding Data Races in Space and Time* (Dolan,
Sivaramakrishnan, Madhavapeddy, PLDI 2018), the paper behind that
chapter. The transcripts were captured from real multi-core runs of
the programs shown. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
