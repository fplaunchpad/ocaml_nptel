---
title: "Tutorial: walking Heartbleed end to end"
lecture_no: 5
week: 10
duration_target_min: 23
concepts: [Heartbleed, CVE-2014-0160, TLS heartbeat, buffer over-read, bounds checking, Bytes.sub, Cstruct, structural impossibility]
keywords: [OCaml, Heartbleed, CVE-2014-0160, OpenSSL, TLS, heartbeat, buffer over-read, memory safety, bounds check, Cstruct]
activity_question: "If a TLS heartbeat handler is given a request with a payload of 1 byte but a length field claiming 65535 bytes, what should it do? What does the OpenSSL code in 2014 do, and what does the OCaml equivalent do?"
think_about_this: "Heartbleed leaked roughly 64 KB of server memory per request. What kind of data could an attacker recover from a TLS server's working memory, and why was the cleanup so expensive?"
reading:
  - title: "Heartbleed, the canonical writeup"
    url: https://heartbleed.com/
  - title: "CVE-2014-0160 in the National Vulnerability Database"
    url: https://nvd.nist.gov/vuln/detail/CVE-2014-0160
  - title: "Netcraft, Half a million widely trusted websites vulnerable to Heartbleed bug (April 2014)"
    url: https://www.netcraft.com/blog/half-a-million-widely-trusted-websites-vulnerable-to-heartbleed-bug
  - title: "OpenSSL commit 96db9023, the Heartbleed fix"
    url: https://github.com/openssl/openssl/commit/96db9023b881d7cd9f379b0c154650d6c108e9a3
  - title: "Cstruct, type-safe byte buffer slicing in OCaml"
    url: https://github.com/mirage/ocaml-cstruct
---

# Tutorial: walking Heartbleed end to end


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Tutorial: walking Heartbleed end to end</h2>
<p class="title-slide-label">Module 10 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

The lectures so far built the safety picture in generality: the
categories of memory bugs and why they matter, how OCaml rules them
out by construction, data races, and the honest boundary where OCaml
itself admits UB. This tutorial lands all of it on one concrete,
exhaustively-documented case study: **Heartbleed**, CVE-2014-0160,
the 2014 OpenSSL bug. OpenSSL ran on roughly two-thirds of the
web's servers at the time, and the vulnerable releases (1.0.1
through 1.0.1f) exposed an estimated 17 percent of TLS-enabled web
servers, around half a million machines (Netcraft, April 2014).

The choice is deliberate: it is the best-documented memory-safety
incident in computing history. The bug is two lines of code, the
exploit is one paragraph, the fix is a single length comparison, and
the OCaml equivalent of the same handler, written with the standard
`Bytes` API, is *structurally incapable* of the same bug. The bounds
check is mandatory; the out-of-bounds bytes are never read.

:::slide

## Roadmap

- The TLS heartbeat extension, what it is supposed to do.
- The OpenSSL bug: the actual code, the actual mistake.
- The exploit: read up to 64 KB of server memory per request.
- The fix: one length comparison.
- The OCaml equivalent: same shape, bug class impossible.

:::

## The TLS heartbeat extension

TLS is the protocol behind every HTTPS URL. In 2012 the standards
committee added a *heartbeat* extension (RFC 6520): long-lived TLS
connections sometimes go quiet, and middleboxes drop them during the
silence, so either side may send a small message asking the peer to
echo it back, as a liveness check. A heartbeat *request* carries a
type byte, a two-byte *payload length*, the *payload* of that length,
and at least 16 bytes of padding; the *response* echoes the payload.
The whole exchange runs inside the existing encrypted channel. The
spec is two pages. The trouble was in how it was implemented.

:::slide

## TLS heartbeat (RFC 6520)

<img src="/assets/diagrams/M10-heartbeat-message.svg" alt="Heartbeat request fields and the echoed response" style="height: 440px;">

- A liveness check inside an established TLS connection.
- The response echoes the payload back.

:::

## The OpenSSL code, abbreviated

OpenSSL implements TLS for most of the internet's HTTPS servers. The
2012 heartbeat handler looked, in essence, like this (simplified; the
relevant lines are these):

You do not need to know C pointer syntax to follow it. Read the names
as a four-step recipe: `p` is the cursor in the incoming request;
`payload` is a number supplied by the peer; `pl` remembers where the
actual payload bytes start; and `bp` is the cursor in the outgoing
response. The helper `n2s` reads a two-byte number, `s2n` writes one,
and `memcpy(destination, source, count)` copies exactly `count` bytes.

```c
hbtype = *p++;
n2s(p, payload);                            /* read 2-byte length */
pl = p;                                     /* pointer to payload */

unsigned char *buffer = OPENSSL_malloc(1 + 2 + payload + padding);
unsigned char *bp = buffer;
*bp++ = TLS1_HB_RESPONSE;
s2n(payload, bp);                           /* write 2-byte length */
memcpy(bp, pl, payload);                    /* copy payload bytes */
```

Trace the data flow. The handler reads the two-byte `payload` length,
allocates a response of that size, and copies `payload` bytes from
the incoming record into it. The bug is in the `memcpy`: it uses the
peer-controlled `payload` value as the copy length *without checking
that the incoming record actually contains that many bytes*. The
`payload` field is a 16-bit number chosen by the peer, 0 to 65535;
the record's real size is whatever the peer sent, which can be far
smaller.

If the attacker sends one byte of payload but declares `payload =
65535`, the `memcpy` reads 65535 bytes starting at `pl`: the first
from the legitimate payload, the next 65534 from whatever lives in
memory after the record. That is the server's working memory:
session keys, the certificate's private key, other connections'
data, log buffers. The handler then sends the whole buffer back.

:::slide

## The OpenSSL handler

```c
hbtype = *p++;
n2s(p, payload);            /* read 2-byte peer length, 0..65535 */
pl = p;                     /* pointer to the payload */

bp = OPENSSL_malloc(1 + 2 + payload + padding);
*bp++ = TLS1_HB_RESPONSE;
s2n(payload, bp);           /* write the length back */
memcpy(bp, pl, payload);    /* copy payload bytes from the record */
```

- Read the 2-byte `payload` length.
  - peer-controlled: 0 to 65535.
- Allocate the response, then `memcpy` `payload` bytes from the
  record.
- The record's real size is never compared to `payload`.

:::

:::slide

## The bug, in two lines

```c
n2s(p, payload);          /* peer-controlled length, 0..65535 */
memcpy(bp, pl, payload);  /* copies payload bytes from the record */
```

- No check that the incoming record is at least `payload` bytes.
- Attacker sends 1 byte of payload, declares length 65535.
- `memcpy` reads 65535 bytes: 1 legitimate, the rest adjacent server
  memory.
- The server sends those bytes back to the attacker.

:::

The over-read, drawn out: a tiny real payload, a huge claimed length,
and the copy scooping up everything next door.

:::slide

## The over-read, visually

<img src="/assets/diagrams/M10-heartbleed-overread.svg" alt="Two real bytes, a huge claimed length, adjacent memory copied out" style="height: 440px;">

- 2 bytes received, 65535 claimed.
- The copy runs past the payload into keys, tokens, passwords.

:::

The bug is an *out-of-bounds read* (the read side of buffer
overflow), CWE-126. It shipped in OpenSSL 1.0.1 through 1.0.1f, was
disclosed on 7 April 2014, and by that evening every public TLS
server was running it. Recovery (patching, rotating keys, reissuing
certificates) ran for months.

## We can build the same over-read

The exploit needs nothing exotic. The miniature C program
`heartbleed_mini.c` mirrors the structure of the real handler: a
`receive_heartbeat` function reads a request buffer, interprets it as
a heartbeat (a type byte, a two-byte length, then the payload), and
echoes `payload_len` bytes back, never checking that the request
actually carried that many:

```c
unsigned char *receive_heartbeat(unsigned char *request, int received,
                                 int *resp_len) {
  unsigned char *server_mem = malloc(64);
  memcpy(server_mem, request, received);              /* the request */
  strcpy((char *)server_mem + 16, "TLS-PRIVATE-KEY"); /* server's secret, nearby */

  int payload_len = n2s(server_mem + 1);   /* attacker-controlled */
  /* THE BUG: payload_len is never checked against `received`. */
  unsigned char *response = malloc(payload_len);
  memcpy(response, server_mem + 3, payload_len); /* reads past the request */
  *resp_len = payload_len;
  return response;
}
```

The attacker sends a tiny request: a type byte, a length field
claiming 48, and one real payload byte (`'h'`). The secret is not in
the request; it lives in the *server's* memory, next to where the
request landed. `memcpy` copies all 48 claimed bytes: the one real
byte, then whatever sits next to it on the server. `response`, sent
back to the attacker, now carries the secret. The real bug read up to
64 KB across whatever the allocator had placed nearby; the bytes
after the payload are arbitrary server memory, and here they happen
to spell a secret, but the point is that *whatever* is adjacent is
transmitted. Run it:

```text
ocaml-vm:~/m10# make heartbleed && ./heartbleed_mini
request carried 1 real payload byte, claimed 48
echoed back: h............TLS-PRIVATE-KEY....................
```

:::slide

## Try it: the over-read in miniature

```text
ocaml-vm:~/m10# make heartbleed && ./heartbleed_mini
request carried 1 real payload byte, claimed 48
echoed back: h............TLS-PRIVATE-KEY....................
```

- `receive_heartbeat` trusts the claimed length (48), not the 1 byte
  received.
- The copy reads past the payload; adjacent memory is echoed back.

:::vm-terminal dir=/root/m10
:::

:::

## The exploit, and the fix

The real exploit: open a legitimate TLS connection, send a heartbeat
with `payload = 65535` and one real byte, receive ~64 KB of server
memory, repeat. Observed leaks included TLS private keys (with which
an attacker can decrypt captured traffic and impersonate the server),
session tokens, passwords, and log buffers. The attacker did not
choose what they got; they got whatever was adjacent, and over
millions of requests that is a lot.

The official fix (OpenSSL commit 96db9023) was a length comparison:

```c
if (1 + 2 + payload + 16 > s->s3->rrec.length)
    return 0;   /* discard the malformed request */
```

One line. It checks that the incoming record is at least big enough
to hold what the length field claims; if not, the handler refuses.
The out-of-bounds read never happens.

:::slide

## The exploit and the one-line fix

- Exploit: legitimate connection, `payload = 65535`, 1 real byte,
  ~64 KB back per request. Leaks: keys, tokens, passwords.

```c
if (1 + 2 + payload + 16 > s->s3->rrec.length)
    return 0;
```

- The fix is one length comparison.

:::

This is the part most often misread. "OpenSSL is too complicated";
"the developers should have been more careful." The bug was a missing
length check on a hot path in a 250,000-line library that hundreds of
contributors had reviewed. *In C, every memory access needs a length
check, every check is the programmer's responsibility, and any one
can be forgotten on any line.* The fix is one comparison; preventing
the *next* Heartbleed needs a language that does not let the
comparison be omitted.

:::slide

## Why this keeps happening

- Not "OpenSSL is sloppy": 250,000 lines, hundreds of reviewers.
- In C, *every* memory access needs a length check.
  - every check is the programmer's responsibility;
  - any one can be forgotten, on any line.
- The fix is one comparison.
  - preventing the *next* one needs a language that won't let the
    check be omitted.

:::

## The OCaml equivalent: bug class impossible

Now the same handler in OCaml, using `Bytes` (the safe-fragment
equivalent of a C `unsigned char *`):

```ocaml
let handle_heartbeat (record : bytes) : bytes =
  let hbtype = Bytes.get record 0 in
  let payload_len =
    (Char.code (Bytes.get record 1) lsl 8)
    lor Char.code (Bytes.get record 2)
  in
  let payload = Bytes.sub record 3 payload_len in
  let response = Bytes.create (3 + payload_len + 16) in
  Bytes.set response 0 hbtype;
  Bytes.set response 1 (Char.chr (payload_len lsr 8));
  Bytes.set response 2 (Char.chr (payload_len land 0xff));
  Bytes.blit payload 0 response 3 payload_len;
  response
```

We never wrote a length check. We just asked for `Bytes.sub record 3
payload_len`. So what happens when `payload_len = 65535` but the
record is 4 bytes long? The answer is in `Bytes.sub`'s contract: it
raises `Invalid_argument` if `pos` and `len` do not designate a valid
range. The bounds check is *part of the API*, not optional, not a
performance opt-in, not a thing a programmer can forget. The function
refuses at the call site, before any out-of-bounds byte is touched.

```text
record = "type | 0xff | 0xff | one_byte"   (* only 4 bytes long *)

Bytes.sub record 3 65535
  -> Invalid_argument   (* raised before any byte is read *)
```

The exception propagates to the handler's caller, which closes the
connection. The attacker gets a connection close, not 64 KB of memory.
The C code needed a programmer to *remember* a length check; the OCaml
code needs a programmer to *opt out* of one, and there is no opt-out
in the safe fragment.

:::slide

## The OCaml equivalent

```ocaml
let handle_heartbeat (record : bytes) : bytes =
  let hbtype = Bytes.get record 0 in
  let payload_len =
    (Char.code (Bytes.get record 1) lsl 8)
    lor Char.code (Bytes.get record 2)
  in
  let payload = Bytes.sub record 3 payload_len in
  let response = Bytes.create (3 + payload_len + 16) in
  Bytes.set response 0 hbtype;
  Bytes.blit payload 0 response 3 payload_len;
  response
```

- Same shape as the C handler: read length, slice, allocate, copy.
- We wrote no length check anywhere.

:::

:::slide

## The bounds check fires

```ocaml skip
(* a 4-byte record claiming a 65535-byte payload *)
let record = Bytes.of_string "\001\255\255A"
let _ = handle_heartbeat record
(* Invalid_argument, raised before any byte is read *)
```

- `Bytes.sub` is bounds-checked: in the contract, not optional.
- It raises *before* any out-of-bounds byte is read.
- The caller closes the connection; no memory disclosed.
- C: remember the check. OCaml: there is no way to opt out.

:::

## A refinement: `Cstruct` and `ocaml-tls`

The OCaml ecosystem has `Cstruct` for typed slicing of binary
buffers; `Cstruct.sub` has the same bounds-check semantics as
`Bytes.sub`. The production OCaml TLS implementation, `ocaml-tls`,
uses `Cstruct` throughout. It has not had Heartbleed-class bugs, and
cannot, because the underlying APIs do not permit them. (A later
module returns to this stack.)

:::slide

## `Cstruct` and `ocaml-tls`

- `Cstruct` gives typed binary slicing; `Cstruct.sub` is
  bounds-checked like `Bytes.sub`.
- The production OCaml TLS library, `ocaml-tls`, is built on it.
- It has not had Heartbleed-class bugs. It cannot have them.

:::

## At the FFI boundary

Most OCaml programs that talk TLS either use the pure-OCaml stack or
call OpenSSL through the FFI. The bounds-check safety holds on the
OCaml side; at the FFI boundary it is only as good as the wrapper. A
binding that hands an unchecked length to a C `memcpy` has the
original Heartbleed bug on the C side. The defence is to slice on the
OCaml side (`Bytes.sub`, which checks) *before* the call, so the C
side receives a buffer that is already the right size. This is the
honest-boundary point from the previous lecture, applied to TLS.

:::slide

## At the FFI boundary

- OCaml-side `Bytes.sub` is checked; the C side is not.
- A wrapper that passes an unchecked length to C `memcpy` has the
  Heartbleed bug again.
- Defence: slice on the OCaml side *before* crossing into C.

:::

## Leak bugs vs corruption bugs

Heartbleed is a *corruption* bug: one request, 64 KB exfiltrated,
immediate and detectable per request. Contrast the *resource-leak*
bugs from the previous lecture: a leaked file descriptor exfiltrates
nothing, but ten thousand of them over a week of uptime exhaust the
limit and the server refuses every new connection. The failure looks
like "stopped accepting connections," not "leaking secrets," and
arrives through slow accumulation, not one malformed request. Both
are safety-relevant; the corruption class is closed by bounds checks,
the leak class by the resource combinators.

:::slide

## Leak bugs vs corruption bugs

| Property | Heartbleed (corruption) | fd leak (resource) |
| --- | --- | --- |
| Per-request effect | 64 KB exfiltrated | one fd retained |
| Latency to harm | immediate | days of uptime |
| Detection | per-request | only at exhaustion |
| Closed by | bounds checks | resource combinators |

Both are safety bugs; different shapes, different defences.

:::

## The big picture

This tutorial is the whole module in one example:

- the **bug catalogue**: Heartbleed is a buffer over-read, one of
  the four canonical memory bugs.
- the **security cost**: it leaked TLS private keys, session tokens,
  and passwords; the cost to the internet ran to hundreds of millions.
- the **safety mechanism**: bounds checking, mandatory on every
  `Bytes` access, eliminates the bug class structurally.
- the **honest boundary**: this holds in the safe fragment; it would
  not hold if the handler called into C without preserving the check.
- the **resource cousin**: leak / double-close / use-after-close,
  whose defence is the combinator pattern, not the GC.

The module in one sentence:

> *OCaml's safety is not magic; it is GC + types + exhaustive
> matching + bounds-checked stdlib, applied consistently.*

The pieces are individually unremarkable. The OCaml story is that
they are applied *consistently*: no escape hatch on the hot path, no
unchecked-array option for performance. The safety is the floor, not
a feature.

:::slide

## The big picture

- Bounds checks: mandatory.
- GC: lifetimes are not the programmer's job.
- Types: the value is what the type says, in the safe fragment.
- Exhaustive matching: cases are handled.
- *Applied consistently across the whole standard library.*

**That is what "memory-safe by default" buys you.**

:::

## Activity

:::quiz mcq id=M10-L05-q1
What was the immediate technical cause of the Heartbleed bug?

- [ ] The TLS protocol design itself was broken.
- [ ] An attacker had to break the encryption first.
- [x] It trusted an unchecked, attacker-supplied payload length.
- [ ] OpenSSL was using outdated cryptographic primitives.

**Why:** Heartbleed is a *missing length check*. The 16-bit `payload`
field is attacker-controlled; the handler `memcpy`d that many bytes
without verifying the request contained them. Sending `payload =
65535` with a one-byte request copied ~64 KB of whatever was next in
memory. The cryptography was fine; the bounds check was missing.
:::

:::quiz mcq id=M10-L05-q2
Why does the OCaml handler not have the bug, even though it also
writes no explicit length check?

- [ ] The compiler statically proves `payload_len` fits in `record`.
- [ ] The GC reclaims out-of-bounds reads before they reach the
  attacker.
- [x] `Bytes.sub` checks bounds before reading.
- [ ] OCaml's `Bytes` are immutable, so a read cannot exfiltrate.

**Why:** the property is *runtime*, not static. OCaml cannot prove the
attacker's `payload_len` is in range, but `Bytes.sub` checks at call
time and raises if not. The check is in the contract, with no opt-out;
the exception propagates and the connection closes. Every `Bytes`
access goes through this same discipline.
:::

:::quiz code id=M10-L05-q3
Write `safe_sub : bytes -> int -> int -> bytes option` that returns
`Some (Bytes.sub b pos len)` when `[pos, pos + len)` lies entirely
inside `b`, and `None` otherwise. It must never raise, even for
negative or past-the-end arguments. Hint: check `pos >= 0`,
`len >= 0`, and `pos + len <= Bytes.length b` first.

```ocaml
let safe_sub b pos len =
  failwith "not implemented"
```

```ocaml skip
let mk s = Bytes.of_string s
let () =
  assert (safe_sub (mk "hello") 0 5 = Some (mk "hello"));
  assert (safe_sub (mk "hello") 1 3 = Some (mk "ell"));
  assert (safe_sub (mk "hello") 5 0 = Some (mk ""));
  assert (safe_sub (mk "hello") 0 6 = None);
  assert (safe_sub (mk "hello") 3 3 = None);
  assert (safe_sub (mk "hello") (-1) 1 = None);
  assert (safe_sub (mk "hello") 0 (-1) = None);
  assert (safe_sub Bytes.empty 0 0 = Some Bytes.empty);
  print_endline "all tests passed"
```
:::

:::solution

A reference solution checks the three preconditions, then slices:

```ocaml
let safe_sub b pos len =
  if pos < 0 || len < 0 || pos + len > Bytes.length b
  then None
  else Some (Bytes.sub b pos len)
```

The check happens before `Bytes.sub`, and the caller sees `None`
instead of catching an exception. The handler can then be exhaustive:

```text
match safe_sub record 3 payload_len with
| None -> close_connection ()
| Some payload -> build_response payload
```

The malformed-request case is a pattern-match branch the type system
forces you to handle, not an exception waiting to be forgotten.

:::

## What's next

Module 10 is complete. The next modules pick up the safety story at
the type level (extending what the type checker can guarantee on its
own) and then apply the whole stack to building real systems in
OCaml. Module 10 has established the foundation: types, GC, exhaustive
matching, and a bounds-checked standard library, applied
consistently.

:::slide

## What's next

- The next module extends safety into the type system itself.
- The one after applies the whole stack to building systems in
  OCaml.
- The foundation is set: types + GC + exhaustive matching +
  bounds-checked stdlib.

:::

## Reading

- **Heartbleed**, the canonical writeup: <https://heartbleed.com/>
- **Netcraft**, *Half a million widely trusted websites vulnerable
  to Heartbleed bug* (April 2014):
  <https://www.netcraft.com/blog/half-a-million-widely-trusted-websites-vulnerable-to-heartbleed-bug>
- **CVE-2014-0160** in the NVD:
  <https://nvd.nist.gov/vuln/detail/CVE-2014-0160>
- **OpenSSL fix commit**:
  <https://github.com/openssl/openssl/commit/96db9023b881d7cd9f379b0c154650d6c108e9a3>
- **RFC 6520**, the TLS heartbeat extension:
  <https://www.rfc-editor.org/rfc/rfc6520>
- **`Cstruct`**: <https://github.com/mirage/ocaml-cstruct>
- **`ocaml-tls`**: <https://github.com/mirleft/ocaml-tls>

## Sources

This lecture's prose, code examples, C demo, and exercises are
original to this course. The OpenSSL code excerpt is reproduced for
educational purposes from the public OpenSSL source tree under the
fair-use exemption for critical commentary and teaching. The
Heartbleed writeup, the Netcraft survey, the NVD CVE entry, and the
OpenSSL fix commit are public documents; the `Bytes.sub` contract is from the OCaml manual.
See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
