---
title: "MirageOS Basics"
lecture_no: 3
week: 12
duration_target_min: 30
concepts: [MirageOS, unikernel, mirage configure, Solo5, mirage-skeleton, OCaml libraries for networking, OCaml TLS, Fiat-Crypto, functor graphs, Robur, Unikraft, Bitcoin Pinata, hardware-assisted unikernels, Shakti FIDES, mixed-language memory safety]
keywords: [OCaml, MirageOS, unikernel, mirage, Solo5, TLS, OCaml-TLS, Fiat-Crypto, KVM, ELF, dune build, Robur, dnsvizor, Unikraft, Firecracker, VPNKit, NetHSM, Shakti FIDES, CHERI, AsiaCCS]
activity_question: "If a MirageOS unikernel is a single statically-compiled ELF binary that contains its own OS, what file system, network stack, and TLS library does it use? Where does that code come from, and what is the trust story for it?"
think_about_this: "The course began with `let x = 1` and ends with an entire operating system written in the same language. What stayed true across those eleven modules of distance, and what changed?"
reading:
  - title: "MirageOS: A programming framework for building type-safe, modular systems"
    url: https://mirage.io/
  - title: "mirage-skeleton: example MirageOS unikernels"
    url: https://github.com/mirage/mirage-skeleton
  - title: "Kaloper-Meršinjak, Mehnert, Madhavapeddy, Sewell: Not-quite-so-broken TLS"
    url: https://www.usenix.org/system/files/conference/usenixsecurity15/sec15-paper-kaloper-mersinjak.pdf
---

# MirageOS Basics


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">MirageOS Basics</h2>
<p class="title-slide-label">Module 12 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

We have the three ingredients now.
[The background lecture](M12-L02-unikernel-background.html)
shrank the kernel into a set of libraries, used a hypervisor to
put a strong protection boundary between guest images, and chose
OCaml as the implementation language so that the inside of each
image is memory-safe without needing the MMU. This lecture puts
the three ingredients together. MirageOS is the result.

A real MirageOS image is statically compiled to an ELF binary
that boots inside a VM, so the full build does not run in the
browser; the lecture walks the pipeline (what does the build
actually do?), looks at the catalogue of libraries that ship with
MirageOS, looks at one specific case study (the OCaml TLS
implementation, whose engineering quality is the strongest single
argument for the whole approach), and then steps back over the
course's safety story. The one thing that *does* run live here is
the heart of the whole mechanism: the retargeting functor, in two
cells, midway through.

This lecture has five parts. First, the synthesis ("here is what
MirageOS *is*"). Second, the build pipeline (`config.ml` to `mirage
configure` to a static binary). Third, the library catalogue
(networking, storage, security, crypto, data structures). Fourth,
TLS as a case study and a pointer to hardware-assisted unikernels.
Fifth, a recap of where the course has been and where the safety
stack lands.

:::slide

## Where we are

:::cols
:::col 52%
- M12-L01 named the problem (kernel TCB is huge).
- M12-L02 prepped the three ingredients:
  - library OS, virtualisation, OCaml.
- **This lecture: the synthesis.**
  - the ingredients, tossed: the salad.
:::
:::col 48%
<img src="/assets/m12/figures/slide-27-salad.jpg"
     alt="A tossed salad in a serving bowl: the three ingredients
     combined">
:::
:::

:::

## What MirageOS is

The one-line definition: **MirageOS is a library OS plus a compiler
that builds specialised images.** The images it produces are called
*unikernels*: a unikernel is a single statically-linked binary that
contains both an application and the operating-system pieces it
needs (network stack, storage, scheduling, crypto), bundled
together so there is no separate kernel underneath. The "uni" in
*unikernel* is the single image: one binary, one address space,
one OS-and-application combined unit.

The library OS part is exactly the background lecture's story: a
collection of
OCaml libraries that, between them, implement the functionality
that used to be in the kernel. The compiler part is the
interesting addition: MirageOS has its own build tool, `mirage`,
that takes a high-level description of the unikernel you want and
orchestrates the OCaml compiler, the package manager, and `dune`
into producing the final ELF binary.

A few properties of the resulting image are worth knowing up front:

- It is a **statically-compiled ELF binary**. No shared libraries.
  No dynamic loader. Everything the unikernel needs is in the
  binary.
- It is typically **a few megabytes**: the mirage.io HTTPS web
  server is about 10 MiB total.
- It **boots in milliseconds** when started under Solo5 on KVM.
- It uses **a few megabytes of RAM** for minimal workloads.
- It runs as **a VM** in production (Solo5-hvt on KVM, Solo5-xen on
  Xen, Solo5-spt as a seccomp-sandboxed Linux process) and can also
  run as a **plain Unix process** for debugging.

That millisecond boot time is not just a smaller number than a
Linux VM's; it enables a different deployment model. An early
MirageOS research system, Jitsu (*Just-In-Time Summoning of
Unikernels*, Madhavapeddy et al., NSDI 2015), booted a unikernel on
demand in response to an incoming network request, fast enough that
the image could be started when the request arrived and torn down
afterwards. It is the unikernel version of serverless cold-start,
except the cold start is tens of milliseconds rather than seconds.

Drawn as a layer diagram: the host has hardware at the bottom, a
hypervisor above it, and several side-by-side unikernels on top.
Each unikernel is one tall column: at the very bottom of the column
is the Mirage Runtime (the bits of the OCaml runtime plus the Solo5
host interface). Above that is the application code. There is
nothing else. No syscall layer. No Linux. No `init`. No libc, in the
sense that any of you have used libc before; just the small set of
C bindings the OCaml runtime and the crypto libraries actually need.

:::slide

## MirageOS unikernel

<img src="/assets/diagrams/M12-unikernel-stack.svg"
     alt="Two unikernels side by side, each an application over a
     Mirage runtime in one image, on a hypervisor (KVM via Solo5),
     on hardware"
     style="max-width: 78%; height: auto;">

- A unikernel = **one statically-compiled ELF binary**.
- A few MiB on disk, a few MiB of RAM, boot in milliseconds.
- Side-by-side unikernels, **hypervisor-isolated**.

:::

The shape of this picture is what an *operating system written in
OCaml* looks like when you take the M01-to-M11 program seriously and
push it down to the lowest layer.

## The build pipeline

Building a MirageOS unikernel is a multi-stage pipeline. It is
worth walking step by step, because the same pipeline is what
delivers the "specialisation" property that gives unikernels their
small footprint.

The starting point is a small OCaml file called `config.ml`. This is
*not* the application; it is a *manifest* that describes which
libraries the unikernel needs and how they should be wired together.
The manifest uses combinators from the `mirage` package. The
manifest for an HTTP service might say "a network stack on the
default network device, an HTTP server on top, hand the result to
my application functor" (the next lecture writes exactly that
manifest).

You then run `mirage configure -t <target>`. The target picks the
backend: `unix` for a plain Unix process, `hvt` for Solo5 on KVM,
`xen` for Solo5 on Xen, and so on. The `mirage configure` command
reads `config.ml`, decides which OCaml packages this configuration
needs, and generates the build context:

- A **`Makefile`** and the **dune build files**, at the project
  root.
- A **`mirage/` directory** holding the generated pieces: a
  **`main.ml`** that ties the application module to the chosen
  backend implementations (generated; you do not write it), and an
  **opam file** named for the configuration, e.g.
  `hello-hvt.opam`, listing the packages this target needs.

The next stage is `make depend`, which locks and fetches those
packages (MirageOS builds vendor their dependencies into the
project), and then `make`, which runs `dune build`. The
`dune build` is where the OCaml compiler does its real work: it
compiles the application source, the generated `main.ml`, and every
library, links them all into one image, and runs the OCaml linker's
dead-code elimination pass. The result is a statically-linked binary
in `dist/<name>`.

Picture the pipeline as boxes connected by arrows. Far left: a green
`config.ml`. An arrow labelled `mirage configure` points at a stack
of generated files: `Makefile`, the opam file, `main.ml`, and the
backend wiring. The paths converge: `make depend` fetches the
target's packages, `dune build` runs the compile-and-link, and the
output is a blue box
labelled `image`. Off to the side, a green `unikernel.ml` (the
application code you actually wrote) also feeds into the dune build.

![MirageOS compiler pipeline diagram: config.ml feeds into mirage
configure, which generates the Makefile and dune files plus
mirage/main.ml and the per-target opam file; make depend fetches
the packages into duniverse, and dune build combines them with the
user's unikernel.ml to produce a single image (ELF
binary).](/assets/diagrams/M12-pipeline.svg)

:::slide

## MirageOS multi-stage pipeline

<img src="/assets/diagrams/M12-pipeline.svg"
     alt="config.ml through mirage configure to the generated build
     context; make depend fetches packages; dune build links
     unikernel.ml and main.ml into one ELF image"
     style="max-height: 46vh; width: auto;">

- `config.ml` is a **manifest**, not the application.
- The pipeline generates the wiring; you write `unikernel.ml`.
- `make depend` fetches the target's packages.
- `dune build` produces a single statically-linked ELF.

:::

Two things are interesting about this pipeline that we did not see in
ordinary OCaml development. First, the **specialisation** happens at
build time: the same `unikernel.ml` can be configured for `unix` or
`hvt` or `xen`, and each configuration gets a different set of
backend libraries linked into the image. The application code does
not change; the wiring underneath does. Second, the OCaml linker
performs **whole-program dead-code elimination**: any function that
no path through the application reaches is stripped out of the
binary. This is why the resulting image is only a few megabytes
despite linking entire network and storage stacks; only the parts
those stacks actually exercise survive.

:::slide

## Specialisation by configuration

- `unikernel.ml` is the application.
- `config.ml` is the manifest.
- `mirage configure -t <target>` picks the backend at build time.
- `dune build` plus the OCaml linker's **dead-code elimination**
  strips everything the application does not reach.
- Result: the mirage.io HTTPS server is **10 MiB**.
  - Boots in **a few ms**; runtime fits in **a few MiB of RAM**.

:::

## What ships with MirageOS

A MirageOS unikernel does not call into any Linux. Every piece of
functionality the application needs has to come from an OCaml library
inside the binary. The MirageOS ecosystem is large enough that this
is feasible for many real applications.

Roughly catalogued, the available libraries are:

- **Network.** Ethernet, IP (v4 and v6), UDP, TCP, HTTP 1.0 / 1.1 /
  2.0, ALPN, DNS, ARP, DHCP, SMTP, IRC, Cap'n Proto, email parsing.
  Pure-OCaml implementations of each layer, composable through
  module signatures.
- **Storage.** Block-device drivers, RAM disks, the QCow virtual-
  disk format, B-trees, VHD, Zlib, gzip, lzo, git, tar, FAT32.
- **Data structures.** LRU caches, Rabin's fingerprint, Bloom
  filters, adaptive radix trees, discrete interval encoding trees.
- **Security.** X.509 certificate parsing, ASN.1, TLS, SSH.
- **Crypto.** Hashes and checksums (SHA-1, SHA-2, SHA-3, MD5,
  Blake2), ciphers (AES, 3DES, RC4, ChaCha20/Poly1305), AEAD
  primitives (AES-GCM, AES-CCM), public-key (RSA, DSA, DH), the
  Fortuna PRNG.

Almost all of this is **reimplemented in OCaml**. The few exceptions
are performance-critical low-level routines (constant-time AES, for
example) which are either written in carefully audited C, or
extracted from formally verified Rocq (formerly Coq) sources
(we'll come to that in a
moment). For an application like a HTTPS web server, *every layer
from the Ethernet frame parser up to the HTTP response writer is
OCaml*. There is no `libssl`. There is no `libcurl`. There is no
glibc.

:::slide

## Available libraries: the OCaml OS catalogue

| Area | Libraries |
| --- | --- |
| **Network** | Ethernet, IP, UDP, TCP, HTTP/1.x and HTTP/2, ALPN, DNS, ARP, DHCP, SMTP, IRC, Cap'n Proto, emails |
| **Storage** | block device, ramdisk, qcow, B-trees, VHD, zlib, gzip, lzo, git, tar, FAT32 |
| **Data structures** | LRU, Rabin's fingerprint, bloom filters, ART trees, DIET trees |
| **Security** | x.509, ASN.1, TLS, SSH |
| **Crypto** | hashes, AES/3DES/RC4/ChaCha20, AES-GCM/CCM, RSA/DSA/DH, Fortuna |

**All in OCaml.** No libssl. No libc.

:::

## TLS as rigorous engineering

Of all the libraries on that list, the one that best illustrates the
ambition of the MirageOS project is the TLS implementation. TLS is
notoriously hard to implement correctly: the specifications are
sprawling, the state machine is intricate, the cryptographic
primitives are unforgiving, and a single bug can compromise the
confidentiality and integrity of every connection. OpenSSL's CVE
history is one long, painful demonstration of how much can go wrong.

The MirageOS TLS implementation was published at USENIX Security in
2015 by David Kaloper-Meršinjak, Hannes Mehnert, Anil Madhavapeddy,
and Peter Sewell, under the title *Not-quite-so-broken TLS: lessons
in re-engineering a security protocol specification and
implementation*. The paper's contributions are technical, but the
*engineering* approach is what is worth describing here.

Three properties of the OCaml-TLS stack stand out (the first and
third are from the paper; the second has been strengthened since):

1. **Same pure code generates test oracles, verifies against
   real-world TLS traces, and serves as the real implementation.**
   In the conventional setup, the production implementation is one
   codebase and the testing infrastructure is another; mismatches
   between the two are how the production code drifts away from
   the spec. In OCaml-TLS, the state-machine code is purely
   functional, and the same functions are used to (a) drive the
   production server, (b) generate test inputs, and (c) validate
   against recorded traces from other TLS stacks. The lack of
   side effects in the core makes this consolidation possible.
2. **A clean-slate crypto stack, now with machine-checked
   primitives.** The 2015 paper built on `nocrypto`, a
   from-scratch OCaml cryptography library written for this
   stack. Its successor, **mirage-crypto**, is what MirageOS
   ships today, and it raises the bar. The constant-time
   arithmetic that underpins elliptic-curve operations is
   notoriously fiddly: subtle side-channel leaks have produced
   multiple CVEs in mainstream implementations. Fiat-Crypto is a
   project that *proves*, in the Rocq proof assistant, that the
   code implementing these primitives matches a mathematical
   specification, and then *extracts* the verified C
   automatically. mirage-crypto uses these extracted primitives
   for its elliptic curves. The trust story for that core is no
   longer "we audited the C very carefully"; it is "we have a
   machine-checked proof."
3. **Strong types track state-machine validity.** TLS has a state
   machine with dozens of states and constrained transitions. In
   OCaml-TLS, those states are encoded as variant types, and the
   compiler refuses to let the implementation enter an invalid
   state. Whole categories of "state confusion" CVEs (a category
   that has affected OpenSSL multiple times) cannot occur.

The combined picture is that OCaml-TLS is what you get when you
take the engineering principles of this whole course (memory
safety, exhaustive pattern matching, pure functions, strong types,
verified critical pieces) and apply them to the production
implementation of a security protocol. The result is a TLS
implementation small enough to audit and structured well enough that
audit means something.

:::slide

## OCaml TLS: rigorous engineering

<img src="/assets/m12/figures/slide-29-tls-paper.png"
     alt="Title block: Not-quite-so-broken TLS, Kaloper-Mersinjak,
     Mehnert, Madhavapeddy, Sewell, University of Cambridge,
     USENIX Security 2015"
     style="max-width: 55%;">

- **Same pure OCaml code** drives the server, generates test
  oracles, and validates against real-world TLS traces.
- **Clean-slate crypto**: `nocrypto` in the 2015 paper.
  - today's `mirage-crypto` extracts its elliptic curves from
    machine-checked Rocq proofs (Fiat-Crypto).
- **Variant types encode the state machine**: invalid transitions
  are unrepresentable.
- The course's safety toolkit, applied to a security protocol.

:::

## Hello Unikernel

Worth seeing the code for one concrete example. The simplest
MirageOS unikernel is something that, every second, logs the word
"hello" and exits after a few iterations. The actual `unikernel.ml`
looks like this, and the `open Lwt.Syntax` at the top should ring
a loud bell: it brings `let*` into scope, the binding operator you
defined for [the option monad](M08-L01-option-monad.html) and
[the state monad](M08-L03-state-monad.html). Lwt is a third
instance of the same pattern: a **concurrency monad**. An
`'a Lwt.t` is a computation that will eventually deliver an `'a`,
`Lwt.return` wraps a value, and `let* () = e in ...` reads "wait
for `e` to finish, then continue."

```text
open Lwt.Syntax

let start () =
  let rec loop = function
    | 0 -> Lwt.return_unit
    | n ->
        Logs.info (fun f -> f "hello");
        let* () = Mirage_sleep.ns (Duration.of_sec 1) in
        loop (n - 1)
  in
  loop 4
```

(That is the current `mirage-skeleton` hello, for mirage 4.9 and
later.) A few things worth noticing, even without running it:

- `Mirage_sleep.ns` is a platform service. The application calls
  one name; *which implementation* answers (the Unix one, the
  Solo5 one) is decided by which backend packages
  `mirage configure -t <target>` selects, and resolved when the
  image is linked. For simple ambient services like time, clocks,
  and randomness, MirageOS wires the backend in at link time;
  nothing in the application changes between targets.
- The body uses `Lwt`, the cooperative-concurrency library, and
  `Logs`, the structured logging library. Both are normal OCaml
  packages; in a Linux process they would do the same thing they
  do here. (In the wild you will also see Lwt's bind written as
  the infix `>>=` from `Lwt.Infix`, the same shape as the
  QCheck-generator `>>=` in
  [property-based testing](M09-L05-property-based-testing.html);
  `let*` is the binding form of the same operator.)
- The entry point is a `start` function. The build pipeline (via
  the generated `main.ml`) calls it.
- There is no `main`. There is no `printf` to stdout. There is no
  Unix shell waiting for the binary's exit status. The image is
  the program, and `start` is the only entry point.

Hello is too small to show the *functor* side of MirageOS: it
consumes no real device. The moment an application takes a device
worth abstracting (an HTTP server, a key-value store, a network
stack), it is written as a functor over that device's signature,
and `mirage configure` picks the implementation. The next lecture's
HTTP unikernel is exactly that shape, and the section after this
one shows the functor graphs of a full website doing it at scale.

Configured for the **Unix backend** (`mirage configure -t unix`),
the build produces a `dist/hello` executable. Running it on a Linux
host gives output like:

```text
2024-11-25T17:04:16+05:30: [INFO] [application] hello
2024-11-25T17:04:17+05:30: [INFO] [application] hello
2024-11-25T17:04:18+05:30: [INFO] [application] hello
2024-11-25T17:04:19+05:30: [INFO] [application] hello
```

That is the unikernel running as a plain Linux process. Convenient
for development; useful for debugging; not the production target.

Configured for the **hvt** backend (`mirage configure -t hvt`),
the build produces `dist/hello.hvt`, which is a Solo5 image. You
run it with `solo5-hvt -- dist/hello.hvt`, and the output is:

```text
            |      ___|
  __|   _ \  |  _ \ __ \
\__ \  (    | (    |   |
____/ \___/ _|\___/____/
Solo5: Bindings version v0.9.0
Solo5: Memory map: 512 MB addressable:
Solo5:   reserved @ (0x0 - 0xfffff)
Solo5:       text @ (0x100000 - 0x1c4fff)
Solo5:     rodata @ (0x1c5000 - 0x1f5fff)
Solo5:       data @ (0x1f6000 - 0x289fff)
Solo5:       heap >= 0x28a000 < stack < 0x20000000
2024-11-25T11:47:10-00:00: [INFO] [application] hello
2024-11-25T11:47:11-00:00: [INFO] [application] hello
2024-11-25T11:47:12-00:00: [INFO] [application] hello
2024-11-25T11:47:13-00:00: [INFO] [application] hello
Solo5: solo5_exit(0) called
```

Same `unikernel.ml`. Same `config.ml` source. Different `mirage
configure` invocation. The first runs as a Linux process; the second
runs as a VM on KVM, with no Linux guest inside it.

:::slide

## Hello Unikernel (`unikernel.ml`)

```text
open Lwt.Syntax

let start () =
  let rec loop = function
    | 0 -> Lwt.return_unit
    | n ->
        Logs.info (fun f -> f "hello");
        let* () = Mirage_sleep.ns (Duration.of_sec 1) in
        loop (n - 1)
  in
  loop 4
```

- `let*` is bind, as in the option and state monads.
- It sequences `Lwt`, a **concurrency monad**.
- `Mirage_sleep.ns`: one name, backend chosen at link time.
- Same source: `-t unix` a process, `-t hvt` a VM.

:::

You do not have to take the pipeline on faith: the course's
in-browser VM now carries the `mirage` tool and this exact hello
project, pre-configured for `-t unix` with its dependencies
already vendored (the VM has no network, so the `make depend`
step was done when the image was built; everything after it is
yours). The loop a MirageOS developer lives in fits in the
terminal below: open `unikernel.ml` in `nano`, change what it
logs, `make build` to relink the unikernel (about 40 seconds in
the emulated machine), and run it. You are rebuilding and booting
an operating system image, in a browser tab.

:::slide

## Edit it, rebuild it, run it

```text
nano unikernel.ml    # change what hello logs
make build           # dune relinks the image (~40 s here)
./dist/hello         # run it: a unikernel as a unix process
```

:::vm-terminal dir=/root/m12/hello
:::

:::

To do the same on your own machine: the skeleton (a
`dune-project`, `config.ml`, and `unikernel.ml`) is bundled as
`/assets/m12/hello-mirage.tar.gz`. Untar, `opam install mirage`,
then `mirage configure -t unix`, `make depend`, `make`, and
`./dist/hello`. (To run the Solo5 backends you need KVM on Linux,
or one of the Solo5 alternatives; the `-t unix` loop works
anywhere opam does.)

## The module system is the OS

Hello is a toy, so it is worth seeing what the wiring
mechanism looks like at full scale. The `mirage` tool can draw the
graph of modules it assembles, and for a real unikernel that graph
*is* the operating system's architecture diagram. Every box below
is an OCaml module; every arrow is a functor application; the
whole picture is computed by `mirage configure` from the manifest.
This is the course's module-system material (signatures, functors,
sealing) doing literal OS construction.

Take the mirage.io website, a full HTTPS server. Configured with
`mirage configure -t unix --net=host`, the network is provided by
the host's sockets, and the assembled graph is already a real
system: the unikernel functor applied to certificate stores, key
stores, a DNS client, happy-eyeballs connection logic, clocks, and
a socket-backed TCP/IP stack:

<img src="/assets/m12/figures/slide-36-mirage-io-host-functors.png"
     alt="Functor dependency graph of the mirage.io unikernel with
     net=host: about twenty modules, with the unikernel functor
     applied to certificates, keys, DNS client, happy-eyeballs and
     a socket-backed TCP/IP stack"
     style="max-width: 100%; height: auto;">

Now change one flag: `--net=direct`. The *same* `unikernel.ml`,
re-wired against MirageOS's own network stack instead of the
host's sockets. The graph grows by exactly the OS code that just
entered the image: Ethernet, ARP, IPv4, IPv6, ICMP, UDP, TCP, all
as functor applications:

<img src="/assets/m12/figures/slide-37-mirage-io-direct-functors.png"
     alt="Functor dependency graph of the same unikernel with
     net=direct: around thirty modules, now including Ethernet,
     ARP, IPv4, IPv6, ICMP, UDP and TCP functors"
     style="max-width: 100%; height: auto;">

Zooming into the lower half of that graph shows the TCP/IP stack
being assembled module by module, down to the network interface:

<img src="/assets/m12/figures/slide-38-mirage-io-direct-zoom.png"
     alt="Zoom into the direct-stack graph: Tcpip_stack_direct
     applied to UDP, TCP flow, ICMPv4, static IPv4, IPv6, ARP,
     Ethernet and Netif modules"
     style="max-width: 100%; height: auto;">

Pause on what this means. In the modules material you sealed a
two-list queue behind a signature and parameterised code with a
functor. Here the *entire operating system* is built the same way:
`Tcpip_stack_direct.MakeV4V6` is a functor over an Ethernet
module, which is a functor over a network interface, and so on
down to the device. Swapping the host's sockets for a from-scratch
TCP/IP stack is not a port; it is a different functor application,
chosen by one flag in the manifest. That is the precise sense in
which MirageOS is "what you can do with the language": the module
system you learned for code organisation turns out to be an OS
construction kit.

(One dating note: these graphs were generated with mirage 4.8.
Since mirage 4.9 the small ambient services, the clock and time
nodes in the corners, are wired at link time instead and drop out
of the picture; the network-stack functors, the substance of the
graphs, are unchanged.)

:::slide

## The module system is the OS

<img src="/assets/m12/figures/slide-36-mirage-io-host-functors.png"
     alt="mirage.io unikernel functor graph with the host socket
     stack"
     style="max-height: 50vh; width: auto;">

- The mirage.io HTTPS server, `-t unix --net=host`.
- Every box is a **module**; every arrow a **functor
  application**.
- `mirage configure` computes this graph from the manifest.

:::

:::slide

## One flag later: the OS enters the image

<img src="/assets/m12/figures/slide-37-mirage-io-direct-functors.png"
     alt="mirage.io unikernel functor graph with net=direct: the
     full OCaml TCP/IP stack appears"
     style="max-height: 50vh; width: auto;">

- Same `unikernel.ml`, configured `--net=direct`.
- The growth is exactly the OS: Ethernet, ARP, IPv4/v6, ICMP,
  UDP, TCP.

:::

:::slide

## Zoom: the TCP/IP stack as functor applications

<img src="/assets/m12/figures/slide-38-mirage-io-direct-zoom.png"
     alt="Zoom of the direct stack: Tcpip_stack_direct down to
     Ethernet and Netif"
     style="max-height: 50vh; width: auto;">

- `Tcpip_stack_direct.MakeV4V6` over UDP, TCP, ICMP, IP, ARP,
  Ethernet, Netif.
- The sealed-module discipline from the FP half, building an OS.

:::

## Retargeting in miniature

The graphs make the claim; the mechanism is small enough to hold
in two cells. Strip everything else away and the trick under
`mirage configure -t` is a single functor application. First the
ingredients: a signature for a platform service, two
implementations standing in for the host kernel's clock and the
hypervisor's clock, and an application functor that cannot tell
which one it will be given.

```ocaml
module type TIME = sig val now : unit -> string end

module Unix_time : TIME = struct
  let now () = "12:00, host kernel clock"
end
module Solo5_time : TIME = struct
  let now () = "12:00, hypervisor clock"
end

module App (T : TIME) = struct
  let start () = print_endline ("hello at " ^ T.now ())
end
```

The body of `App` is written once and never names an operating
system; the signature is all it can see. Now apply it twice:

```ocaml
module Unix_app = App (Unix_time)  (* mirage configure -t unix *)
module Hvt_app = App (Solo5_time)  (* mirage configure -t hvt  *)
let () = Unix_app.start (); Hvt_app.start ()
(* prints:
   hello at 12:00, host kernel clock
   hello at 12:00, hypervisor clock *)
```

These two module bindings are the unikernel build in miniature:
`mirage configure -t unix` makes the first choice when it
generates the real `main.ml`, `-t hvt` makes the second, and the
same application functor is reapplied. When you sealed the
two-list queue behind a signature, this was the skill you were
building; mirage applies it with an operating system on the far
side of the signature. Swap the implementation, rerun the cell,
and you have retargeted a (toy) system without touching its
application code.

:::slide

## Retargeting in miniature

```ocaml
module type TIME = sig val now : unit -> string end

module Unix_time : TIME = struct
  let now () = "12:00, host kernel clock"
end
module Solo5_time : TIME = struct
  let now () = "12:00, hypervisor clock"
end

module App (T : TIME) = struct
  let start () = print_endline ("hello at " ^ T.now ())
end
```

- `App` never names an OS; the signature hides the platform.

:::

:::slide

## One functor, two systems

```ocaml
module Unix_app = App (Unix_time)  (* mirage configure -t unix *)
module Hvt_app = App (Solo5_time)  (* mirage configure -t hvt  *)
let () = Unix_app.start (); Hvt_app.start ()
(* prints:
   hello at 12:00, host kernel clock
   hello at 12:00, hypervisor clock *)
```

- The two bindings are `-t unix` / `-t hvt`, in miniature.
- Same application body; the OS is chosen by the functor
  argument.
- Swap the implementation and rerun: a retarget with no
  application change.

:::

## MirageOS in 2026

MirageOS is an active project, and the 2025-2026 releases moved it
forward on three fronts worth knowing about.

**OCaml 5.** MirageOS runs on OCaml 5 (the ocaml-solo5 1.0 release,
February 2025, moved the Solo5 backends to OCaml 5.2). Solo5
itself remains single-core, so unikernels get OCaml 5's effects
machinery but not parallelism yet.

**New targets: Unikraft, QEMU, and Firecracker.** Since mirage
4.10 (September 2025), the tool has `unikraft-qemu` and
`unikraft-firecracker` targets, built on an OCaml cross-compiler
to Unikraft, a CNCF library-OS project (announced by Tarides,
November 2025). This brings MirageOS to two new VMMs (plain QEMU
and AWS's Firecracker), to arm64 as well as x86_64, and, as
Unikraft's multicore support matures, opens a path to true
multicore OCaml unikernels. The backend is young, but it is the
direction of travel.

**A swappable TCP stack.** mirage 4.11 (May 2026) added `--utcp`,
which swaps the classic mirage-tcpip stack for uTCP, Robur's
from-scratch TCP implementation informed by a formal TCP
specification. One flag in the manifest, exactly like `--net`
above: the module graph re-wires, the application code does not
change.

:::slide

## MirageOS in 2026

- **OCaml 5** under every unikernel (ocaml-solo5 1.0, Feb 2025).
  - effects yes; multicore not yet (Solo5 is single-core).
- **Unikraft targets** since mirage 4.10 (Sep 2025).
  - `-t unikraft-qemu`, `-t unikraft-firecracker`.
  - QEMU + Firecracker, x86_64 + arm64; a path to multicore.
- **`--utcp`** since mirage 4.11 (May 2026).
  - Robur's spec-informed TCP, swapped in by one manifest flag.

:::

## Who runs unikernels in production

MirageOS is not vapourware, and the clearest evidence in 2026 is
**Robur**, a worker-owned cooperative that runs its infrastructure
on MirageOS and ships production unikernels:

- **dnsvizor**: a DNS resolver and DHCP server in one unikernel, a
  drop-in replacement for dnsmasq and Pi-hole, with DNSSEC,
  DNS-over-TLS/HTTPS, ad-blocklists, and a web UI (all landed in
  2025, EU NGI-funded).
- **miragevpn**: an OpenVPN-compatible VPN client and server,
  including a QubesOS client.
- **albatross** and **mollymawk**: the operations layer; a daemon
  that deploys and monitors fleets of unikernels, and its web UI.
  Unikernels grew an ops story: consoles, metrics, DHCP
  auto-configuration, multi-server fleets.
- **ptt**: an email stack; since 2026 a real public mailing list
  runs on it in production.
- **builds.robur.coop**: reproducible binary builds of all of the
  above, plus **opam-mirror**, a unikernel that mirrors the opam
  package archive.

Beyond Robur: **qubes-mirage-firewall** is the standard-bearer
deployment (the firewall VM many QubesOS users run, maintained
since 2015); **mirage.io** serves its own website. (Tezos, the
OCaml blockchain, funded experiments in packaging its nodes as
MirageOS unikernels; that work stayed experimental.) And the
container
world is meeting unikernels halfway: **urunc** (from the
background lecture) launches solo5 unikernels under
Kubernetes.

The niche is clear: long-running network services where the
operational benefits (small attack surface, fast restart,
reproducible builds, predictable resource use) pay for the
narrower library ecosystem.

:::slide

## Who runs unikernels in production

- **Robur** (cooperative, runs on MirageOS):
  - **dnsvizor**: dnsmasq/Pi-hole replacement; DNSSEC, DoH,
    blocklists.
  - **miragevpn**: OpenVPN-compatible client and server.
  - **albatross + mollymawk**: fleet deployment and monitoring.
  - **ptt**: a production mailing list, run as unikernels.
  - **builds.robur.coop**: reproducible builds; opam-mirror.
- **qubes-mirage-firewall**: the QubesOS firewall VM.
- **mirage.io** serves itself; **urunc** brings unikernels to
  Kubernetes.

:::

## Three stories

Three short stories make the safety-and-footprint argument
concrete; each was a real deployment.

**The Bitcoin Pinata.** In 2015 the OCaml-TLS authors put their
money where their stack was: an 8.2 MB MirageOS unikernel holding
the private key to 10 bitcoins (peak value around ₹1.3 crore then;
over ₹6 crore at today's prices).
Anyone who could break the TLS stack, the unikernel, or the
hypervisor isolation could take the coins; the attack surface and
the bounty were both public. It ran from 2015 to 2018: over half a
million visits, more than 150,000 connection attempts at the
bounty. The bitcoins were never taken. As a security argument this
is stronger than any benchmark: a standing, funded, public bounty
against precisely the stack this lecture describes.

:::cols
:::col 55%
**Nitrokey NetHSM.** A commercial hardware security module (the
appliance that guards an organisation's cryptographic keys) whose
entire software stack is a MirageOS unikernel running on the Muen
separation kernel, the high-assurance Solo5 backend from the
background lecture. Open source, auditable end to end, and
sold as a product: unikernels passing a commercial-credibility
test.
:::
:::col 45%
<img src="/assets/m12/figures/slide-42-nethsm.png"
     alt="Nitrokey NetHSM rack appliance">
:::
:::

:::cols
:::col 55%
**Docker for Mac.** The widest deployment of MirageOS code is one
most users never saw: for years, Docker Desktop's VM-to-host
networking layer was VPNKit, the component that
translates between the Linux VM's Ethernet packets and macOS's
network calls, built from MirageOS networking libraries. The
functor-assembled network stack from the graphs above shipped
on millions of developer laptops. (Docker Desktop swapped in a
gVisor-based stack in 2023; VPNKit is still maintained and used
elsewhere.)
:::
:::col 45%
<img src="/assets/m12/figures/slide-43-docker-for-mac.png"
     alt="Docker for Mac about box and its open-source license list
     crediting the MirageOS tcpip library">
:::
:::

:::slide

## The Bitcoin Pinata: a funded, public bounty

:::cols
:::col 55%
- An **8.2 MB unikernel** holding the key to **10 bitcoins**
  (peak value about ₹1.3 crore then; over ₹6 crore today).
- Break the TLS stack, the unikernel, or the isolation: keep the
  coins.
- Ran 2015 to 2018: 500k visits, **150k+ bounty attempts**.
- **The bitcoins were safe.**
:::
:::col 45%
<img src="/assets/m12/figures/slide-41-bitcoin-pinata.png"
     alt="Bitcoin Pinata logo: a pinata drawn as a burst star">
:::
:::

:::

:::slide

## NetHSM and Docker for Mac

:::cols
:::col 50%
<img src="/assets/m12/figures/slide-42-nethsm.png"
     alt="Nitrokey NetHSM appliance"
     style="max-height: 34vh; width: auto;">

- A commercial HSM: MirageOS on the **Muen** separation kernel.
- Open source, auditable end to end.
:::
:::col 50%
<img src="/assets/m12/figures/slide-43-docker-for-mac.png"
     alt="Docker for Mac credits the MirageOS tcpip library"
     style="max-height: 40vh; width: auto;">

- Docker Desktop's **VPNKit**: MirageOS networking code.
  - shipped on millions of laptops; replaced by a gVisor stack
    in 2023.
:::
:::

:::

## Advanced topic: hardware-assisted unikernels

A unikernel is not pure OCaml. The image links the OCaml runtime,
which is C, plus any C stubs the application reaches through the
foreign-function interface. As the memory-safety module argued,
OCaml's guarantees stop exactly at that boundary: a bug in the C is
unconstrained, and inside a unikernel there is a single address
space with no kernel underneath to contain it, so corrupt C can
scribble over the OCaml heap and everything else. Pushing the OS
into a safe language shrinks the unsafe surface down to the runtime
and the stubs; it does not erase it.

There is an active research direction in *hardware-assisted
unikernels* that uses CPU features to contain that residual C.
Memory-safety hardware (CHERI capabilities, and Shakti FIDES on the
Indian Shakti RISC-V processor) compartmentalises the C so that a
bug in it cannot reach the OCaml heap or escape its compartment.
Suresh the Stationmaster, written in OCaml over a runtime whose C is
fenced in by the hardware, is the picture FIDES draws: it runs
bare-metal MirageOS unikernels with OCaml and C side by side, each
in its own hardware-enforced compartment.

The hypervisor is a second piece of the trusted base. KVM is
hundreds of thousands of lines of C, also in the TCB of every
unikernel on the host. A separate line of CPU features (Intel TDX,
AMD SEV-SNP, ARM CCA) reduces or eliminates the trust placed in the
hypervisor: the vision there is a unikernel whose memory the
hypervisor cannot read and whose execution it cannot tamper with.

KC Sivaramakrishnan's November 2024 talk *Securing the foundations*
at the Centre for Artificial Intelligence and Robotics (CAIR / DRDO)
covers the threat model and the hardware, and the FIDES paper
(*FIDES: End-to-end Compartments for Mixed-language Systems*,
AsiaCCS 2026) is the detailed treatment of the mixed-OCaml-and-C
case. We do not cover this material in the course; these are the
right starting points for the curious.

## The course, end to end

We are one lecture from the end of the course, and the safety
story has come a long way since `let x = 1`.

In [M01](M01-L02-why-fp.html) we argued that values and types are
the unit of reasoning in OCaml. In M02 to M08 we built the core
language: literals, bindings, functions, pattern matching, modules.
By the end of M08 you had a complete functional language and the
discipline to use it well.

In [Module 9](M09-L01-why-test-typed-code.html) we said that types catch type
errors but not behaviour, and added testing; especially property-
based testing, which works particularly well because pure functions
are properties.

In [Module 10](M10-L01-memory-safety-and-security.html) we made the
*memory-safety* claim precise. Use-after-free, buffer overflow,
uninitialised reads, double-frees: all ruled out by construction.
The numbers (70 percent of CVEs are memory-safety bugs) made the
argument concrete.

In [Module 11](M11-L01-locality.html) we pushed safety into
new territory with OxCaml's modes: locality made stack allocation
safe; uniqueness ruled out use-after-free at the type level;
linearity made a second use of a consumed handle unwritable; and
portability with contention delivered compile-time data-race
freedom. Types tracking *how* a value is used, not just *what*
it is.

In Module 12 we have taken the whole apparatus and pushed it down
into the operating system itself. MirageOS is what the safety
toolkit looks like when you apply it to the runtime your application
sits on. Library OS removes the kernel boundary; virtualisation
gives back the inter-application isolation; OCaml gives back the
intra-application safety. The result is a small, fast, auditable
platform.

That is the course, end to end. Twelve modules of lectures,
runnable cells, and quizzes: all of it adds up to one idea, that
safety is something you can *build into* your software at every
level if you take the language seriously.

:::slide

## Where the course has been

- M01-M08: the core language. Types, functions, pattern matching,
  modules.
- M09: tests catch what types do not. Properties as first-class.
- M10: memory safety as a property of the language. Categories of
  CVEs OCaml rules out.
- M11: modes track *how* values are used. Locality, uniqueness,
  linearity, portability, contention.
- **M12: the OS itself, in OCaml.** Safety, all the way down.

:::

## Activity

:::quiz mcq id=M12-L03-q1
A MirageOS unikernel is built by running `mirage configure -t hvt`,
then `make`. What is the *output* of this build, and what runs it?

- [ ] A Linux kernel module loaded into the host's running kernel.
- [x] A statically-compiled ELF binary that runs as a VM under
  Solo5 on KVM.
- [ ] A Docker container that runs on the host kernel.
- [ ] A bytecode file interpreted by the OCaml toplevel.

**Why:** `-t hvt` targets the Solo5 hardware-virtualisation tender
on KVM. The build produces an ELF image (`dist/<name>.hvt`); you
run it with `solo5-hvt -- dist/<name>.hvt`, which starts a KVM VM
whose only contents are this unikernel. There is no Linux guest
inside the VM; the unikernel *is* the OS. Containers share the host
kernel and would not give us the isolation guarantees the
background lecture established; bytecode plays no role in the
pipeline, since even the development backend
(`mirage configure -t unix`) is a native-compiled Unix executable.
:::

:::quiz mcq id=M12-L03-q2
Why is the OCaml-TLS implementation considered "rigorous engineering"
in a way that conventional TLS libraries typically are not?

- [ ] It runs ten times faster than OpenSSL.
- [ ] It implements only modern cipher suites and rejects every legacy TLS record format.
- [x] Types encode the TLS state machine; tests reuse the implementation.
- [ ] It is written by a different vendor from OpenSSL.

**Why:** those two engineering moves are what the USENIX
Security 2015 paper documents (its crypto provider was `nocrypto`,
a clean-slate OCaml library); the Rocq-extracted primitives came
later, in the successor mirage-crypto stack. The result is a stack
whose correctness story is fundamentally different from "we wrote
it carefully": it is "we built the abstractions so the bugs cannot
occur." Speed and size are secondary; the safety argument is the
news.
:::

:::solution

Q1: `mirage configure -t hvt && make` produces a statically-linked
ELF that runs as a KVM VM via Solo5.

Q2: OCaml-TLS's rigorous engineering: the same pure code drives
production, test-oracle generation, and trace validation; variant
types encode the state machine so invalid transitions are
unrepresentable; and today's mirage-crypto extracts its
elliptic-curve primitives from machine-checked Rocq proofs.

:::

## Common pitfalls

**Pitfall 1: "Unikernels replace Linux."** Not for general-purpose
computing. They replace Linux in *deployment niches*: long-running
network services, security-sensitive infrastructure, cloud workloads
where the per-instance footprint matters. Your developer workstation
is still going to run a conventional OS.

**Pitfall 2: "You have to write the whole OS yourself."** The
library catalogue we walked through covers most of what a typical
service needs. You write the application; the libraries supply the
rest. The MirageOS skeletons (`mirage-skeleton` on GitHub) are
good starting points.

**Pitfall 3: "If it crashes, what happens?"** The unikernel exits.
That is it. There is no kernel panic, no rescue shell, no
`systemd` restart logic inside the image. The host's
deployment system (`systemd`, `kubernetes`, `nomad`, whatever you
use) restarts the unikernel from scratch. The boot time is small
enough that this is operationally acceptable for most services.

**Pitfall 4: "There's no way to log in."** Right; there is no shell.
For observability, the unikernel logs via the `Logs` library to
stdout (in the Unix backend) or via Solo5's console output (in the
hvt backend). Production deployments capture those logs the same
way they capture any container's stdout.

## What's next

The final lecture is the hands-on companion to this one: **Suresh
the Stationmaster**, one small HTTP unikernel walked end to end. You
will see the two files you actually write (`unikernel.ml` and
`config.ml`), the artefacts `mirage configure` generates, the
`dune build` that links the static ELF, the `solo5-hvt` boot, a
`curl` against the running VM, and the footprint numbers that
fall out.

:::slide

## What's next

- Lecture 4: **Suresh the Stationmaster**, one unikernel end to end.
  - `unikernel.ml` + `config.ml`: the two files you write.
  - `mirage configure -t hvt`, `make`: the build.
  - `solo5-hvt`: boot it, `curl` it, measure it.

:::

## Reading

- **MirageOS project home**: <https://mirage.io/>
- **mirage-skeleton**, the canonical starter projects:
  <https://github.com/mirage/mirage-skeleton>
- **Solo5**: <https://github.com/Solo5/solo5>
- **Kaloper-Meršinjak, Mehnert, Madhavapeddy, Sewell**, *Not-quite-
  so-broken TLS: lessons in re-engineering a security protocol
  specification and implementation*, USENIX Security 2015:
  <https://www.usenix.org/system/files/conference/usenixsecurity15/sec15-paper-kaloper-mersinjak.pdf>
- **Robur**, a non-profit deploying MirageOS in production:
  <https://robur.coop/>
- **Fiat-Crypto** (Rocq-extracted cryptographic primitives, used
  by mirage-crypto for its elliptic curves):
  <https://github.com/mit-plv/fiat-crypto>
- KC Sivaramakrishnan, *Securing the foundations* (CAIR / DRDO,
  Nov 2024), for the hardware-assisted-unikernels pointer.
- Sai Venkata Krishnan, Arjun Menon, Chester Rebeiro, KC
  Sivaramakrishnan, *FIDES: End-to-end Compartments for
  Mixed-language Systems*, AsiaCCS 2026:
  <https://kcsrk.info/papers/fides_asiaccs_2026.pdf>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The MirageOS narrative (synthesis, multi-stage pipeline
diagram, available-libraries catalogue, hello-unikernel example,
TLS-as-rigorous-engineering framing) follows KC Sivaramakrishnan's
January 2025 IIT Madras talk *Towards smaller, safer, bespoke OSes
with Unikernels*, slides 27 to 35. The pointer to hardware-assisted
unikernels follows KC's CAIR / DRDO November 2024 talk *Securing the
foundations* and the FIDES paper (Krishnan, Menon, Rebeiro,
Sivaramakrishnan, *FIDES: End-to-end Compartments for Mixed-language
Systems*, AsiaCCS 2026), whose intra-process compartmentalisation on
the Shakti RISC-V processor is the source for the in-unikernel
C-memory-safety framing. The TLS paper (Kaloper-Meršinjak et al., USENIX
Security 2015) is the standard academic anchor for the OCaml-TLS
story, and its title block is reproduced as a citation, as are the
Bitcoin Pinata, NetHSM, and Docker for Mac images that identify
those deployments. The 2026 ecosystem facts (mirage 4.10/4.11,
ocaml-solo5 1.0, the Unikraft targets, Robur's fleet) are from the
projects' own release notes and announcements. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
