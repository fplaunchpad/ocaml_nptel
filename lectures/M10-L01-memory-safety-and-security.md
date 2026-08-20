---
title: "What memory safety is, and why it is a security story"
lecture_no: 1
week: 10
duration_target_min: 26
concepts: [undefined behaviour, memory safety, use-after-free, buffer overflow, double-free, uninitialised read, exploit, memory-safe roadmap]
keywords: [OCaml, undefined behaviour, UB, memory safety, CVE, security, C, Heartbleed, ASLR, ROP, White House, CISA]
activity_question: "A C signed-overflow check at -O2; which memory bug is impossible in safe OCaml; and the order of the use-after-free exploit pipeline."
think_about_this: "If a C program has undefined behaviour on some input, the compiler is allowed to assume that input never occurs and optimise accordingly. What does that mean for code that worked yesterday and miscompiles tomorrow?"
reading:
  - title: "John Regehr, A Guide to Undefined Behavior in C and C++"
    url: https://blog.regehr.org/archives/213
  - title: "Microsoft Security Response Center, A proactive approach to more secure code"
    url: https://msrc.microsoft.com/blog/2019/07/a-proactive-approach-to-more-secure-code/
  - title: "Chromium project, Memory safety"
    url: https://www.chromium.org/Home/chromium-security/memory-safety/
  - title: "Google security blog, Memory Safe Languages in Android 13 (December 2022)"
    url: https://security.googleblog.com/2022/12/memory-safe-languages-in-android-13.html
  - title: "Google Project Zero, The More You Know, The More You Know You Don't Know (review of 0-days exploited in 2021)"
    url: https://projectzero.google/2022/04/the-more-you-know-more-you-know-you.html
  - title: "CISA, NSA, FBI et al., The Case for Memory Safe Roadmaps (December 2023)"
    url: https://www.cisa.gov/resources-tools/resources/case-memory-safe-roadmaps
  - title: "White House ONCD, Future Software Should Be Memory Safe (February 2024)"
    url: https://bidenwhitehouse.archives.gov/oncd/briefing-room/2024/02/26/press-release-technical-report/
---

# What memory safety is, and why it is a security story


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">What memory safety is, and why it is a security story</h2>
<p class="title-slide-label">Module 10 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Nine modules of OCaml have built up an intuition that, when your
program type-checks, certain whole classes of bugs simply cannot
happen. You have not seen a segmentation fault. You have not seen a
"use-after-free." You have not seen a buffer overflow. That is not
because we were careful; it is because the language rules them out
by construction.

This module asks the question that intuition leaves open: *what
exactly are those classes of bugs, and what are they worth?* To
answer the first half honestly, we have to look at the canonical
unsafe language, which is C, and survey the family of memory bugs
that real C programs write every day and ship to production. To
answer the second half, we look at what those bugs cost the world:
the security incidents, the industry numbers, and the national
policy that has grown up around them.

This lecture is deliberately C-heavy, and the C is runnable. There
is a terminal embedded in the page with a small Linux machine and a
C compiler; you can build each buggy program and watch it
misbehave. That is the point of the module: to see, concretely,
what OCaml's design is contrasting against.

:::slide

## Where we are

- Eight modules of OCaml: types catch type errors; matching forces
  case-handling; the GC removes lifetime questions.
- Now ask the two questions that leaves open:
  - *what exactly* does OCaml rule out?
  - *what is it worth* to rule those out?
- To answer, look at the canonical unsafe language, **C**.

:::

:::slide

## What this module covers (5 lectures)

- **L1** *(this one)*: what memory safety is, and why it is a
  security story.
- **L2**: how OCaml rules the bugs out by construction.
  GC, bounds checks, value representation.
- **L3**: data races are undefined behaviour.
- **L4**: where OCaml itself has UB, and resource safety beyond
  memory.
- **L5**: tutorial. Walking Heartbleed end to end.

:::

## What "undefined" means

The C standard distinguishes three related but importantly different
kinds of "we are not telling you exactly what this does":

1. **Unspecified behaviour.** The standard lists several possible
   behaviours and lets the implementation pick one, without
   requiring documentation. Example: the order of evaluation of
   subexpressions inside `f(g(), h())` is unspecified; the compiler
   may call `g` before `h` or `h` before `g`, and either is legal.
2. **Implementation-defined behaviour.** The implementation must
   pick a behaviour from a documented set, and document its choice.
   Example: the size of `int`, or whether right-shift of a negative
   integer is arithmetic or logical, is implementation-defined.
3. **Undefined behaviour.** The standard places *no* requirement on
   what the program does. The program is said to have no defined
   meaning at all.

The first two are awkward but manageable: a portable C program
avoids relying on unspecified order, and consults the
implementation manual where it must depend on
implementation-defined choices. The third, undefined behaviour, is
qualitatively different. It is the dangerous one.

:::slide

## Three flavours of "this is not quite specified"

| Flavour | What the standard requires | Example |
| --- | --- | --- |
| **Unspecified** | Pick from a list, no documentation | Order of args in `f(g(), h())` |
| **Implementation-defined** | Pick from a list, **document it** | `sizeof(int)`, signedness of `char` |
| **Undefined** | *No requirement at all* | Null deref, signed overflow, use-after-free |

**Only the third one is the real problem.**

:::

The reason undefined behaviour is qualitatively different is that
the compiler is allowed to *assume* it does not happen. A modern C
compiler does not check, at runtime, "did you just trigger UB?"
because the standard says you cannot. Instead, the compiler
*propagates* this assumption backwards through its optimisation
passes, frequently in ways the programmer did not anticipate.

A famous category of jokes goes: "if your program has undefined
behaviour, the compiler is allowed to format your hard drive or
summon nasal demons." That is funny but slightly misleading; in
practice the compiler does not actively try to misbehave. What it
does is subtler: it optimises code on the *assumption* that UB
never occurs, and the resulting program then does something the
programmer did not intend. From the perspective of someone
debugging the failure, it looks like the compiler "misbehaving";
the compiler's defence is that the source program was already
broken.

## A concrete UB-driven miscompile

Consider this C function, simplified from a real Linux kernel
patch:

```c
struct sock *tun = ...;
struct sock *sk = tun->sk;
if (!tun) return POLLERR;
return POLLIN;
```

A C programmer reads this as: read `tun->sk` into `sk`, then check
whether `tun` is null; if it is null, return an error, otherwise
return the OK code. The intent is defensive.

Now read what the *compiler* sees. On line 2 the code dereferences
`tun` (to read `tun->sk`). Dereferencing a null pointer is
undefined behaviour. The compiler concludes that, since the program
is well-defined, `tun` *cannot have been null* at line 2. Working
backwards, by line 3 `tun` is *known to be non-null*. Therefore the
test `if (!tun)` is dead code: it can never be true. The compiler
removes the check.

The defensive null check is silently deleted. The bug appears later,
when an attacker arranges for `tun` to actually be null. This was
[CVE-2009-1897](https://nvd.nist.gov/vuln/detail/CVE-2009-1897), a
real Linux kernel vulnerability. The bug is *not* a compiler bug:
the C standard makes this legal. The bug is the source code's
reliance on UB, a check written *after* the dereference that the
standard reads as a promise the check is unnecessary.

The smaller, self-contained version of the same effect is an
overflow check. Signed-integer overflow is also undefined, so the
compiler may assume `x + 100` never wraps below `x`, and delete a
guard written that way. Here is the whole program, `deleted_check.c`:

```c
#include <stdio.h>
#include <limits.h>

/* Returns 1 if adding 100 to x would "overflow" (wrap negative). */
int will_overflow(int x) {
    return (x + 100) < x;          /* UB when x is near INT_MAX */
}

int main(void) {
    int x = INT_MAX - 50;
    if (will_overflow(x))
        printf("guard fired: %d + 100 would overflow\n", x);
    else
        printf("no overflow reported for %d + 100\n", x);
    return 0;
}
```

`will_overflow` is the guard a careful C programmer might write: if
`x + 100` comes out *smaller* than `x`, the addition must have
wrapped around, so report it. With `x = INT_MAX - 50`, the sum
genuinely does wrap to a negative number at runtime, so the guard
*should* fire. But `x + 100 < x` can only be true if signed
overflow happened, and signed overflow is undefined, so the compiler
is entitled to assume it never does, concludes `x + 100 < x` is
always false, and deletes the whole `if`. You can watch it happen in
the terminal below. Compiled normally the guard is gone and the
message never prints; compiled with `-fwrapv`, which tells the
compiler to *define* signed overflow as wraparound, the UB
assumption is gone, the guard can be true, and it fires. Both builds
use `-O2`; the only difference is whether overflow is undefined.

The names below come from the preinstalled `Makefile`: `check_ub`
means “compile with ordinary C overflow rules,” while `check_safe`
means “compile with `-fwrapv`.” `make` prints the exact `cc` command it
runs. A following command such as `./check_ub` executes that compiled
binary; the lines after it are the program's output, not more commands.

```text
ocaml-vm:~/m10# make check_ub check_safe
cc -O2 -o check_ub deleted_check.c
cc -O2 -fwrapv -o check_safe deleted_check.c
ocaml-vm:~/m10# ./check_ub
no overflow reported for 2147483597 + 100
ocaml-vm:~/m10# ./check_safe
guard fired: 2147483597 + 100 would overflow
```

Same source, same input, opposite behaviour. The default build is
not wrong by the standard: the program promised, by writing the
overflow, that the overflow never happens.

:::slide

## "Defensive" code, miscompiled

```c
struct sock *tun = ...;
struct sock *sk  = tun->sk;     // dereferences tun
if (!tun) return POLLERR;       // dead code per the compiler
return POLLIN;
```

- From the **Linux kernel** `tun` driver (CVE-2009-1897).
- Deref on line 2 is UB if `tun` is null.
- Compiler deduces `tun` cannot be null, so the check cannot fire.
- Compiler **deletes the check**.
- The bug is in the source, not the compiler.

:::

:::slide

## Live: the optimiser deletes a check

- `deleted_check.c`: a signed-overflow guard `if (x + 100 < x)`.
- Default: the compiler assumes overflow never happens, deletes it.
- `-fwrapv` (overflow defined as wraparound): the guard fires.

```text
ocaml-vm:~/m10# ./check_ub
no overflow reported for 2147483597 + 100
ocaml-vm:~/m10# ./check_safe
guard fired: 2147483597 + 100 would overflow
```

:::

:::slide

## Try it: build and run the C demos

- Boots a tiny Linux machine in this page, in `/root/m10`.
- `make check_ub check_safe` then `./check_ub` and `./check_safe`.
- Also there: `make uaf && ./uaf`, `overflow`, `uninit`,
  `heartbleed`.

:::vm-terminal dir=/root/m10
:::

:::

## Why compilers cling to UB

If undefined behaviour is dangerous, why does the C standard have it
at all? Two reasons.

First, *performance*. C was designed to be a thin layer over the
hardware. Many CPU operations behave differently on different
platforms: integer overflow wraps on x86 but traps on some embedded
chips; unaligned loads are fast on x86 but illegal on older ARM. If
the standard demanded one specific behaviour everywhere, the
compiler would have to insert checks, or emulate the "wrong"
behaviour, on every platform where the hardware disagreed. By
calling these cases *undefined*, the standard tells the compiler
"do whatever the hardware does, insert no checks, optimise hard."

Second, *optimisation*. Dead-code elimination, loop unrolling, and
pointer-aliasing assumptions all rely on knowing what the program is
and is not allowed to do. UB carves out the cases the optimiser can
assume away. A compiler that took every "could this be UB?"
question at face value would generate much slower code.

These are real reasons. C earned its place partly because it runs
nearly as fast as hand-written assembly. The price is that the
language gives you many ways to write code with no defined meaning,
and the compiler will silently optimise on the assumption that you
did not.

## The categories of UB that matter

The C standard lists hundreds of specific UB cases. They cluster
into four broad categories:

1. **Memory.** Reading or writing memory the program does not own.
   This is the category that becomes most of the world's CVEs.
2. **Integer and arithmetic.** Signed-integer overflow, division by
   zero, shifts by negative or oversized amounts.
3. **Aliasing and concurrency.** Reading a value through a pointer
   of the wrong type, and data races (two threads touching the same
   memory without synchronisation; the subject of a later lecture).
4. **Lifetime.** Using a pointer after the memory it points to has
   been freed, or after a stack frame has been destroyed.

This module's primary target is the first and the fourth. The
named memory bugs we survey next live there.

:::slide

## Four UB categories

- **Memory.** Read or write memory you do not own. *Most CVEs.*
- **Integer and arithmetic.** Signed overflow, divide by zero.
- **Aliasing and concurrency.** Wrong-type reads; data races.
- **Lifetime.** Use-after-free, dangling pointers.

**Categories 1 and 4 host the four named bugs we survey next.**

:::

## The memory-safety zoo

Within the memory-and-lifetime cluster, four named bugs come up
again and again in real systems. They split cleanly along two axes:
is the access in the wrong *place* (spatial) or at the wrong *time*
(temporal)?

:::slide

## The four canonical memory bugs

<img src="/assets/diagrams/M10-zoo-quadrants.svg" alt="The four memory bugs by spatial vs temporal" style="height: 440px;">

- Each is **undefined behaviour**; each has produced thousands of
  CVEs.

:::

### Use-after-free (temporal)

In C, the programmer requests memory with `malloc` and returns it
with `free`. Once you `free` a block, the allocator may hand it to
the next `malloc`. If you keep using the original pointer after
that, you are reading bytes the program no longer owns. The pointer
is to a valid address; that address simply no longer belongs to you.

The program `uaf.c` shows the shape: fill a heap-allocated record,
free it, then read it again through the old pointer.

```c
struct session { int user_id; char role[16]; };

struct session *s = malloc(sizeof *s);
s->user_id = 1001;
strcpy(s->role, "guest");
printf("before free: id=%d role=%s\n", s->user_id, s->role);

free(s);                       /* the block goes back to the heap */

/* s is now a DANGLING pointer: reading through it is UB. */
printf("after free:  id=%d role=%s\n", s->user_id, s->role);
```

After `free(s)`, the allocator may hand that block to the next
`malloc`, but `s` still holds its address. The second `printf`
reads through that dangling pointer. Run it in the terminal:

```text
ocaml-vm:~/m10# make uaf && ./uaf
before free: id=1001 role=guest
after free:  id=1001 role=guest
```

The read after `free` still returns `1001`: the bytes are still
there, and nothing crashed. That silence is what makes
use-after-free dangerous. The block is now on the allocator's free
list; the next allocation of that size may hand it out, and *then*
the same read returns someone else's data. What happens depends on
the C library, the load, and, in an attack, the attacker, which is
the heap-spray step in the exploit pipeline below.

**Real-world incident.** The Chromium team reported in 2020 that
[70 percent of high-severity Chrome bugs were memory-safety issues,
and the largest single category, about 36 percent, was
use-after-free](https://www.chromium.org/Home/chromium-security/memory-safety/).

:::slide

## Use-after-free: it does not crash

```text
ocaml-vm:~/m10# make uaf && ./uaf
before free: id=1001 role=guest
after free:  id=1001 role=guest
```

- The read after `free` still returns `1001`: the bytes linger.
- Nothing crashes. *That* silence is the danger.
- When the allocator reuses the block, the same read returns
  someone else's data.

:::

### Buffer overflow (spatial)

In C, arrays do not carry their length at runtime. A copy into a
buffer trusts the caller to pass a length that fits; if the length
is wrong (or attacker-controlled), the copy walks past the buffer's
end and overwrites whatever was next in memory. `overflow.c` copies
its argument into a 16-byte buffer with `strcpy`, which does no
bounds check, and keeps a marker value (`canary`) just past it:

```c
volatile int canary = 0x600d;  /* sits just past `buf` */
char buf[16];

strcpy(buf, argv[1]);          /* no bounds check: copies verbatim */

printf("buf    = %s\n", buf);
printf("canary = 0x%x (expected 0x600d)\n", canary);
```

A short argument fits and the canary reads back `0x600d`. A long
argument runs past the 16 bytes and overwrites the neighbouring
`canary` (and, further out, the return address), so the program
prints a corrupted canary and then crashes:

```text
ocaml-vm:~/m10# ./overflow hello
buf    = hello
canary = 0x600d (expected 0x600d)
ocaml-vm:~/m10# ./overflow AAAAAAAAAAAAAAAAAAAAAAAAAAAA
buf    = AAAAAAAAAAAAAAAAAAAAAAAAAAAA
canary = 0x41414141 (expected 0x600d)
Segmentation fault
```

The `0x41414141` is four `A`s (`0x41`) sitting where the canary
used to be: the write went straight off the end of `buf`.

**Real-world incident.** This bug class is as old as the networked
internet. The 1988 Morris worm, one of the first internet worms,
spread in part by smashing a fixed stack buffer in the BSD `finger`
daemon: the daemon read a request with `gets`, which has no length
argument and no bounds check, so an over-long request ran off the
end and overwrote the return address. It disrupted a large fraction
of the machines then on the internet and led directly to the
founding of the first CERT. The canonical CVE on the *read* side of
buffer overflow (an out-of-bounds read, or over-read) is
**Heartbleed** (CVE-2014-0160) in OpenSSL, where a length field was
used to copy bytes from a buffer without checking it against the
buffer's real size. We walk it end to end in the tutorial that
closes this module. Thirty-six years separate the two; the bug is
the same.

:::slide

## Buffer overflow: off the end

```text
ocaml-vm:~/m10# ./overflow hello
canary = 0x600d (expected 0x600d)
ocaml-vm:~/m10# ./overflow AAAAAAAAAAAAAAAAAAAAAAAAAAAA
canary = 0x41414141 (expected 0x600d)
Segmentation fault
```

- `strcpy` into a 16-byte buffer does no bounds check.
- A long argument overwrites the neighbour (`0x41` = `A`), then
  crashes.

:::

### Uninitialised read (spatial)

A C local, when allocated, holds whatever bytes were last at that
location. Reading it before writing returns those leftover bytes.
This does not crash and does not corrupt anything; it just leaks.
Of the four, this is the one that fits the spatial/temporal split
least well: the access is in bounds and the memory is alive, so it
is neither out-of-bounds (spatial) nor out-of-lifetime (temporal).
It is really a *read before write*; we group it under spatial only
because it reads bytes that are physically present but not logically
yours. If the bytes encode a secret (a key, a password, an address
that defeats ASLR), the read leaks the secret. `uninit.c` writes a
recognisable pattern into a buffer in one function, then reads a
*different*, never-written buffer over the same stack slot in the
next:

The bug itself is only these two lines:

```c
char leak[8];       /* storage allocated, contents unspecified */
putchar(leak[0]);   /* BUG: read before any write */
```

The longer demonstration below adds `stash_secret` and a loop only so
that the otherwise unpredictable leftover bytes become recognisable in
the output; they are not additional ingredients of the bug.

```c
void stash_secret(void) {
    char secret[32];
    for (int i = 0; i < 32; i++)
        secret[i] = "DEADBEEF"[i % 8];   /* leave a pattern behind */
}

void read_uninitialised(void) {
    char leak[32];                        /* never written to */
    for (int i = 0; i < 16; i++) putchar(leak[i]);
    putchar('\n');
}
```

`stash_secret` returns, but its stack bytes are not wiped;
`read_uninitialised` declares `leak` over the same slot and reads it
before writing, so it prints the leftover pattern:

```text
ocaml-vm:~/m10# make uninit && ./uninit
uninitialised buffer: DEADBEEFDEADBEEF
```

In a real program the leftover bytes are not a friendly string;
they are whatever the last caller left there, which is exactly how
kernel info-leaks expose secrets.

**Real-world incident.** Uninitialised reads in Linux kernel
networking code leaked kernel-stack bytes to userspace through
packet padding; for example
[CVE-2017-7472](https://nvd.nist.gov/vuln/detail/CVE-2017-7472).

:::slide

## Uninitialised read: leftover bytes

```text
ocaml-vm:~/m10# make uninit && ./uninit
uninitialised buffer: DEADBEEFDEADBEEF
```

- Reading a local before writing it returns the stack's old bytes.
- Here a friendly pattern; in a kernel, someone else's secret.
- The loose fit in the 2x2: in bounds and alive, really a
  read-before-write; filed under spatial for convenience.

:::

### Double-free (temporal)

A program frees the same block twice:

```c
char *buf = malloc(64);
free(buf);
free(buf);   /* UB: the block is already on the free list */
```

The second `free` corrupts the allocator's bookkeeping, often in
ways an attacker can steer to make a future `malloc` return a
pointer they chose. CVE-2021-3711, a double-free in OpenSSL's SM2
decryption, is a recent example.

:::slide

## Double-free

```c
char *buf = malloc(64);
free(buf);
free(buf);   /* UB: the block is already on the free list */
```

- Freeing twice corrupts the allocator's bookkeeping.
- No `free` at all in OCaml, so the whole family closes together.

:::

## So what? The industry numbers

A memory bug, in isolation, sounds like a reliability problem: a
crash, some garbage printed. The reason the industry treats these as
a strategic risk is the scale at which they occur, and what an
attacker can do with one. First the scale.

For most of the 2010s there was an argument about whether
memory-safety bugs were really *that* dominant in shipping software.
It ended around 2019, when several large vendors independently
published the same number from their own internal data.

Microsoft's Security Response Center reported that *roughly 70
percent of the high-severity bugs Microsoft assigned a CVE to were
memory-safety issues*, with twelve years of data and the proportion
flat, despite hundreds of millions of dollars spent on C tooling.
Chromium reported the same 70 percent. The lesson everyone drew:
"be more careful" had been tried, at enormous expense, and the
proportion had not moved.

:::slide

## The industry numbers

<img src="/assets/diagrams/M10-industry-numbers.svg" alt="Memory-safety share of severe bugs across four studies" style="height: 380px;">

- Each bar: the share of *severe* bugs that are memory-safety bugs.
- ~70% at Microsoft (2019) and Chrome (2020); 86% of Android's
  critical-severity bugs (2022); 67% of in-the-wild 0-days
  (Project Zero, 2021).
- Flat at Microsoft for over a decade despite heavy C tooling:
  "be more careful" does not scale.

:::

### Same team, two languages

The cleanest evidence is Google's Android team. Android ships a
large layer of *managed* code (Java, Kotlin) over a lower layer of
*native* code (C and C++), and from 2019 the team began moving new
code to memory-safe languages, with Rust entering the native
layer. Their report *Memory Safe Languages in Android 13* (Google
security blog, 2022) shows what happened: memory-safety bugs
dropped from *76 percent of Android's vulnerabilities in 2019 to
35 percent in 2022*, tracking the fall in new C and C++ code, and
the team had found *zero* memory-safety vulnerabilities in
Android's Rust code. Same product, same team, same release
process. The variable that explains the difference is the
language, not the discipline. The bugs that remain are still the
worst ones: in 2022, memory-safety issues were a minority of
Android's bugs but *86 percent of its critical-severity
vulnerabilities*.

A fourth data point comes from Google's Project Zero, which tracks
zero-day exploits detected in actual use. Its review of 2021 (*The
More You Know, The More You Know You Don't Know*, 2022) found that
39 of the 58 in-the-wild 0-days that year, *about 67 percent*,
were memory-corruption bugs. That is a different selection: these
are the bugs attackers actually chose to invest in. They keep
choosing memory-safety bugs because they keep working.

:::slide

## Same team, two languages

- Android: managed (Java / Kotlin) over native (C / C++); from
  2019, new code shifts to memory-safe languages, Rust in native.
- Google, *Memory Safe Languages in Android 13* (2022):
  - memory-safety bugs: 76% of Android's vulnerabilities (2019)
    down to 35% (2022).
  - zero memory-safety bugs found in Android's Rust code.
  - still 86% of 2022's **critical**-severity vulnerabilities.
- Same team, same culture, same release process.
- In-the-wild 0-days: 67% memory corruption (Project Zero, 2021).
- *The language is the variable.*

:::

## From a memory bug to arbitrary code execution

The other half of "so what" is that a memory bug is rarely just a
crash. With modest attacker effort it becomes *arbitrary code
execution*: the attacker gets your program to run code of their
choosing, with your program's privileges. Once that happens, every
other security boundary is bypassed.

The chain has a stable five-step shape, using a use-after-free as
the example. It does not require writing any exploit code to
understand.

A `free` leaves a dangling pointer (the bug). The attacker
*heap-sprays*, forcing many allocations whose bytes they control, so
the freed slot refills with their data. The program's next access
through the dangling pointer reads those bytes as the original type
(*type confusion*), typically following an attacker-chosen function
pointer. To run on a system that marks data non-executable, the
attacker uses *return-oriented programming*: a chain of addresses
into existing code fragments, each ending in `ret`, assembled into
the computation they want. The final *payload* runs.

Mitigations exist (address randomisation, non-executable data,
stack canaries, control-flow integrity) and each makes this harder,
but none close the class: the attacker pays the engineering cost
once and exploits thousands of installations, while the defender
pays the runtime cost everywhere, forever. After three decades of
layered mitigations, Microsoft's 70 percent line has not moved.

:::slide

## One bug becomes code execution

<img src="/assets/diagrams/M10-exploit-flow.svg" alt="Five-step exploit pipeline from free to payload" style="height: 230px;">

- One ordinary bug (a freed pointer, an overflow) is the whole
  foothold.
- The turn is **type confusion**: attacker bytes get used as a
  function pointer, so control flow goes where they choose.
- **ROP** sidesteps non-executable data by reusing the program's own
  code fragments.
- End state: attacker code runs **with your privileges**; mitigations
  (ASLR, DEP, CFI) raise the cost, not close the class.

:::

## The policy turn

This is why memory safety is no longer only a technical argument.
In December 2023, five national cyber agencies (the US CISA, NSA,
and FBI, with the UK, Australia, Canada, and New Zealand) published
[*The Case for Memory Safe
Roadmaps*](https://www.cisa.gov/resources-tools/resources/case-memory-safe-roadmaps),
urging vendors to publish dated plans for moving components to
memory-safe languages. Its named list of memory-safe languages
includes Rust, Go, Java, C#, Swift, Python, JavaScript, and *the ML
family, including OCaml*. Two months later the White House Office of
the National Cyber Director published [*Future Software Should Be
Memory
Safe*](https://bidenwhitehouse.archives.gov/oncd/briefing-room/2024/02/26/press-release-technical-report/),
making the same case from the altitude of the largest single
customer of commercial software in the world. Neither document
hedges: they name the language choice as the highest-leverage
intervention available.

This is the context in which an OCaml course talks about memory
safety. The course's job here is to make the mechanism precise, so
you can read those reports and know exactly what guarantee you are
buying.

:::slide

## The policy turn (2023-2024)

- **CISA / NSA / FBI** + UK, AU, CA, NZ, Dec 2023:
  *The Case for Memory Safe Roadmaps.*
  - Named safe languages include Rust, Go, Java, C#, Swift,
    **the ML family (OCaml)**.
- **White House ONCD**, Feb 2024:
  *Future Software Should Be Memory Safe.*
- Neither hedges: language choice is the highest-leverage
  intervention.

:::

## How OCaml stands, and safety by design

Every bug in this lecture is impossible in safe OCaml, by
construction. There is no `free`, so use-after-free and double-free
cannot be written. Indexing a `string`, `bytes`, or `array` is
bounds-checked and raises `Invalid_argument` rather than walking off
the end. Every binding is initialised at the point of binding, so
there is no uninitialised read. The next lecture makes each of these
precise and shows where in the runtime the rule is enforced.

This is the security-flavoured version of the argument from the
[earlier "why functional programming" lecture](M01-L02-why-fp.html):
pure functions and immutable data eliminate whole categories of bugs
not by being careful but by removing the means to write them. Here
we eliminate UAF by removing `free`, overflow by mandating a bounds
check, uninitialised reads by requiring binding-time initialisation.
We do not need to be careful; we need the unsafe operation to be
un-writable.

:::slide

## Safety by design

- No `free` &rArr; no use-after-free, no double-free.
- Mandatory bounds check &rArr; no buffer overflow.
- Binding-time initialisation &rArr; no uninitialised read.
- The earlier "why FP" lecture, in a security key: remove the
  *means* to write the bug, do not rely on care.

:::

## Rust as a different answer

OCaml is not the only language that rules out the four bugs by
construction. *Rust* does it without a garbage collector, using a
*borrow checker*: a static analysis in the type system that tracks
ownership and borrowing. Each value has one owner; you may borrow it
immutably many times or mutably once, not both; when the owner goes
out of scope, the value is freed. This is a compile-time discipline
with no runtime machinery, but the cost moves to the programmer, who
must structure the program so ownership is statically expressible.
Cyclic or shared structures need extra machinery (`Rc`, `RefCell`,
`Arc`, `Mutex`).

The trade-off in one line: OCaml has a small constant runtime
overhead and no proof obligation on the programmer; Rust has no
runtime overhead and a proof obligation the borrow checker must
accept. A later module returns to this, adding a type-level
discipline on top of OCaml's GC.

:::slide

## Rust: another answer

| Property | OCaml | Rust |
| --- | --- | --- |
| Discipline | GC + runtime checks | borrow checker (compile-time) |
| Runtime cost | small constant | none for the safety story |
| Proof obligation | none | borrow checker must accept your code |
| Cyclic / shared structures | natural | extra machinery (`Rc`, `Arc`) |

Both rule out the four-bug zoo. Different *placement* of the
discipline: OCaml at runtime, Rust at type-check time.

:::

## Activity

:::quiz mcq id=M10-L01-q1
A C program contains this code, where `x` is a `signed int`:

```c
if (x + 1 < x) {
  printf("overflow happened!\n");
}
```

On a typical optimising compiler with `-O2`, what happens?

- [ ] The `printf` runs whenever `x` is `INT_MAX`.
- [x] The compiler removes the `printf` call entirely; it is never reached.
- [ ] The program crashes with an overflow error.
- [ ] The `printf` runs whenever `x` is `INT_MIN`.

**Why:** signed-integer overflow is undefined behaviour in C. The
compiler may assume it never occurs. Under that assumption
`x + 1 > x` is always true, so `x + 1 < x` is always false, the body
is dead code, and the compiler removes it. The terminal demo
(`deleted_check.c`) shows exactly this: the guard is deleted by
default and reappears only under `-fwrapv`, which defines overflow
and removes the UB assumption. The correct way to write the check is
to compare against `INT_MAX - 1` *before* adding.
:::

:::quiz mcq id=M10-L01-q2
Which of the following bugs is *impossible* in safe OCaml?

- [ ] Forgetting to handle the empty-list case of a function.
- [x] Reading from memory that has already been freed.
- [ ] An infinite loop.
- [ ] Returning the wrong answer because of a typo in the code.

**Why:** OCaml's GC eliminates the lifetime question: memory is
freed only when nothing reachable refers to it, so "reading from
freed memory" cannot occur in safe code. The other three are bugs
the type system does *not* catch: non-exhaustive matching warns but
can be opted out of; infinite loops are undecidable in general;
typos that type-check are exactly what testing (the previous module)
is for.
:::

:::quiz mcq id=M10-L01-q3
The exploit pipeline for a use-after-free typically involves several
conceptual steps. Which ordering is correct?

- [ ] heap spray, type confusion, free, ROP, payload
- [x] free (pointer lingers), heap spray, type confusion, ROP, payload
- [ ] free, ROP, heap spray, type confusion, payload
- [ ] free, payload, heap spray, type confusion, ROP

**Why:** the chain starts with a `free` that leaves a dangling
pointer (the bug). The attacker *heap-sprays* to fill the freed slot
with controlled bytes; the next access reads them as the original
type (*type confusion*), often following an attacker-chosen function
pointer; *return-oriented programming* assembles execution from
existing code on a non-executable-data system; the *payload* then
runs.
:::

## Common pitfalls

**"UB is a compiler bug."** It is not. The standard explicitly
permits the compiler to do anything when UB is triggered. The bug is
in the source program.

**"If it works on my machine, it has no UB."** Many UB-driven bugs
are input- or timing-sensitive, and a line that "works" on one
compiler version can miscompile on the next as the optimiser gets
smarter. The `deleted_check.c` demo is exactly this: same source,
two optimisation levels, opposite behaviour.

**"Memory-safe languages are slow."** OCaml's native compiler is
typically within a small constant factor of C, and the GC adds a
fraction of a percent in most workloads. The performance argument
for C is real but small; the safety argument against it is large.

**"Just be careful when writing C."** Decades of trying, at the cost
of hundreds of millions of dollars, did not move Microsoft's 70
percent. "Be more careful" is not a working mitigation at scale.

**"Memory safety means secure."** It does not; it closes one large
class, not all of them. Log4Shell (CVE-2021-44228), the 2021
remote-code-execution flaw in the ubiquitous Java logger Log4j, was
not a memory bug at all: a crafted log string triggered a JNDI
lookup that fetched and ran attacker-controlled code, in a fully
memory-safe language. The 70 percent that memory safety removes is
the highest-leverage single intervention, but the other 30 percent,
injection, logic errors, misused crypto, is still yours to get
right.

## What's next

We now have a precise catalogue of the bugs and a sense of what they
cost. The
[next lecture](M10-L02-memory-safety-by-construction.html) makes the
OCaml side precise: which language construct rules out which bug,
where in the runtime the rule lives, and what it costs. That is
where the 63-bit-int aside from the
[literals lecture](M02-L01-literals.html) finally pays off: tagged
pointers, block headers, and the GC's job.

:::slide

## What's next

- Next: **memory safety by construction.** GC for
  lifetimes, bounds checks for overflow, binding-time
  initialisation, no `free`. The runtime sketch.
- Then: data races as undefined behaviour.
- Then: where OCaml itself has UB, and resource safety.
- Finally: walk Heartbleed end to end.

:::

## Reading

- **John Regehr**, *A Guide to Undefined Behavior in C and C++*:
  <https://blog.regehr.org/archives/213>
- **Microsoft Security Response Center**, *A proactive approach to
  more secure code* (the 70% report):
  <https://msrc.microsoft.com/blog/2019/07/a-proactive-approach-to-more-secure-code/>
- **The Chromium project**, *Memory safety*:
  <https://www.chromium.org/Home/chromium-security/memory-safety/>
- **Google security blog**, *Memory Safe Languages in Android 13*
  (December 2022):
  <https://security.googleblog.com/2022/12/memory-safe-languages-in-android-13.html>
- **Google Project Zero**, *The More You Know, The More You Know
  You Don't Know* (review of 0-days exploited in 2021, April 2022):
  <https://projectzero.google/2022/04/the-more-you-know-more-you-know-you.html>
- **CISA / NSA / FBI et al.**, *The Case for Memory Safe Roadmaps*
  (December 2023):
  <https://www.cisa.gov/resources-tools/resources/case-memory-safe-roadmaps>
- **White House ONCD**, *Future Software Should Be Memory Safe*
  (February 2024):
  <https://bidenwhitehouse.archives.gov/oncd/briefing-room/2024/02/26/press-release-technical-report/>
- **Heartbleed** (CVE-2014-0160): <https://heartbleed.com/>

## Sources

This lecture's prose, worked examples, C demos, and quizzes are
original to this course. The industry reports (Microsoft MSRC,
Chromium, Google Android, Google Project Zero) and government
memoranda (White House ONCD, the CISA/NSA/FBI joint publication)
are public documents
authored by their respective agencies and vendors; we quote and link
to them rather than reproducing them. The exploit description is
deliberately conceptual and includes no working exploit code. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
