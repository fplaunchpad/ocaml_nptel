---
title: "Monad laws, the list monad, and the result monad"
lecture_no: 2
week: 8
duration_target_min: 26
concepts: [monad laws, list monad, non-determinism, result monad, Result.bind, error propagation]
keywords: [OCaml, monad laws, list monad, concat_map, result, Result.bind, let*]
activity_question: "Use the list monad's non-determinism to return every Pythagorean triple [a*a + b*b = c*c] with [a < b] and [a], [b], [c] each in [1..30], as [(a, b, c)]."
think_about_this: "The option, list, and result monads share one [let*]. What is different about what [let*] *means* in each?"
reading:
  - title: "Cornell CS3110, Monads"
    url: https://cs3110.github.io/textbook/chapters/conc/monads.html
---

# Monad laws, the list monad, and the result monad


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Monad laws, the list monad, and the result monad</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 2</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

[The previous lecture](M08-L01-option-monad.html) built the option
monad and the `let*` notation. We said a monad is "a type plus `return` and
`bind`". That is not quite the whole story: a *lawful* monad's
`return` and `bind` also satisfy three equations, the *monad laws*.
This lecture states them quickly, then spends its time where the
payoff is: showing the same `let*` driving two very different
shapes. The *list monad* (`'a list`) models many values at once;
the *result monad* (`('a, 'e) result`) is option with an
informative failure.

:::slide

## This lecture

- The three **monad laws** (left identity, right identity,
  associativity), and why they let you refactor `let*` chains
  safely.
- The **list monad**: `bind = List.concat_map`, for computations
  with *many* results (non-determinism).
- The **result monad**: like `option`, but failure carries
  information.
- One `let*`, three very different behaviours.

:::

## The monad laws

The three laws are the "good behaviour" contract that lets you
trust and refactor monadic code without reasoning about each `let*`
from scratch. They are equations about *observable behaviour*, not
just about types: both sides already type-check, and the law says they
must produce the same result and effects for every value and function.

:::slide

## The three laws

```text
left identity   | bind (return x) f  ===  f x
right identity  | bind m return      ===  m
associativity   | bind (bind m f) g  ===
                  bind m (fun x -> bind (f x) g)
```

- Left and right identity fence `return` in: it can only wrap, do
  nothing else.
- Associativity says nested `bind`s regroup freely
  - A `let*` chain reads as a flat sequence
  - You can refactor a sub-chain into a helper without changing the result.
- They hold for every monad in this course (option, list, result,
  state).
  - OCaml's type system cannot enforce equalities.
  - You check them on paper, once, per monad.

:::

The same three laws read more intuitively in the `let*` notation
students actually use:

:::slide

## The laws in `let*` form

```text
left identity    | let* x = return v in f x ===
                   f v
right identity   | let* x = m in return x ===
                   m
associativity    | let* y = (let* x = m in f x) in g y ===
                   let* x = m in let* y = f x in g y
```

- Left identity: wrap `v`, then immediately unwrap it and feed it
  to `f`; the same as just `f v`.
- Right identity: binding only to `return` changes nothing.
- Associativity: nested and flat `let*` chains agree.

:::

The identity laws say that `return` contributes no computational
behaviour of its own. On the left it may wrap a fresh value before
the next step; on the right it may wrap the final value; either wrapper
can be erased. Associativity says that only the *order of steps* matters,
not how nested calls are parenthesised. It does **not** permit swapping
`f` and `g`; it permits regrouping `m` then `f` then `g`. This is why a
three-line `let*` chain can be split into a helper and later inlined
again without changing what it does.

A worked check of left identity on `option`, with concrete values:

:::slide

## Checking a law

```ocaml
let ( let* ) = Option.bind
let f x = if x > 0 then Some (x * 10) else None

let lhs = let* x = Some 5 in f x   (* = Some 50 *)
let rhs = f 5                       (* = Some 50 *)
let _ = (lhs = rhs)                 (* = true: left identity holds *)
```

- `return 5` for `option` is `Some 5`; binding it into `f` equals
  calling `f 5` directly.
- The other two laws check the same way. Nothing states them as
  OCaml types, so the check is a one-time paper proof per monad,
  not something the compiler does for you.

:::

We will not enforce or test the laws. They are worth recognising
(they are why category theorists like monads), but day-to-day OCaml
rarely turns on them. The one to remember is associativity: it is
why `let* a in let* b in let* c in ...` is unambiguous and why
carving a sub-chain into a helper is always safe.

## A different shape: the list monad

So far our monads have been about one value or none. The list monad
is about *many* values. `'a list` has the right shape: `return x`
is `[x]`, and `bind` runs the continuation on *every* element and
flattens the results:

:::slide

## The list monad: definition

```ocaml
let return x = [x]
let bind xs f = List.concat_map f xs
let ( let* ) = bind

let _ = bind [1; 2; 3] (fun x -> [x; x * 10])  (* = [1; 10; 2; 20; 3; 30] *)
let _ = return 7                                (* = [7] *)
```

- The list monad models a computation with *many* results at once.
- `bind xs f` maps `f` across `xs` and concatenates: that is
  exactly `List.concat_map` (`flat_map` in other languages).
- `return x = [x]`: one value, lifted to a one-element list.

:::

The list monad models *non-determinism*: a computation that may
produce several values, with the next step running on each one.
`let*` becomes "for every value in the previous step's output, do
the next step":

:::slide

## Non-determinism: a Cartesian product

```ocaml
let ( let* ) xs f = List.concat_map f xs

let pairs =
  let* x = [1; 2; 3] in
  let* y = ["a"; "b"] in
  [(x, y)]

let _ = pairs
(* = [(1, "a"); (1, "b"); (2, "a"); (2, "b"); (3, "a"); (3, "b")] *)
```

- Six pairs: every `x` paired with every `y`.
- Each `let*` adds one dimension to the search.

:::

The same `let*` that meant "short-circuit on failure" for `option`
now means "consider every combination" for lists. The notation
did not change; the monad did. Search problems fall out of this
directly, using the empty list as a filter:

:::slide

## Filtering with the empty list

```ocaml
let ( let* ) xs f = List.concat_map f xs

let ordered_pairs =
  let* x = [1; 2; 3] in
  let* y = [1; 2; 3; 4] in
  if x < y then [(x, y)] else []

let _ = ordered_pairs
(* = [(1, 2); (1, 3); (1, 4); (2, 3); (2, 4); (3, 4)] *)
```

- `[]` at a step drops that branch (`concat_map` of `[]` adds
  nothing); a singleton keeps it.
- "Filter via empty list" is how you write guards in the list
  monad.

:::

## The result monad: failure with information

[`option`](M04-L04-recursive-types.html#the-option-type) says
"maybe a value". [`result`](M04-L04-recursive-types.html#the-result-type)
says "either a value, or an error with a payload". Both carry a
value on success; only `result` carries information on failure. The
plumbing is identical to the option monad; only the failure type
changes.

:::slide

## `result`'s `bind`, and the steps

```ocaml
(* Result.bind = option's bind, with Ok/Error for Some/None *)
let bind r f = match r with Ok x -> f x | Error e -> Error e
let ( let* ) = bind

let parse_int_msg s =
  match int_of_string_opt s with
  | Some n -> Ok n
  | None -> Error ("not an int: " ^ s)

let double_r x =
  if x > max_int / 2 then Error "overflow" else Ok (x * 2)

let small_r x = if x < 100 then Ok x else Error "too big"
let print_num_r x = print_endline (string_of_int x); Ok ()
```

- `bind` is `option`'s `bind` with `Ok`/`Error` for `Some`/`None`;
  the stdlib ships exactly this as `Result.bind`.
- `double_r` guards overflow with an informative `Error`, just as
  `double` used `None` in the previous lecture.

:::

:::slide

## `Result.bind`: the pipeline

```ocaml
let demo s =
  let* x = parse_int_msg s in
  let* y = double_r x in
  let* z = small_r y in
  print_num_r z

let _ = demo "5"      (* prints 10; = Ok () *)
let _ = demo "frog"   (* = Error "not an int: frog" *)
let _ = demo "200"    (* = Error "too big" *)
```

- Same shape as the option-monad demo; failure now names *why*.
- The first `Error` to fire is returned; later steps do not run.

:::

The structure is identical to the option-monad demo from the
previous lecture. `let*` still means "unwrap the success, or
short-circuit"; the only visible change is that the failure case
carries a payload. (That payload can be anything, a `string` or a
[variant](M04-L03-variants.html) when callers must tell failures
apart; the monad behaves the same whatever it is.)

Like the option monad, `result` short-circuits on the *first*
`Error`: subsequent steps do not run, and the origin of failure is
what you get back. That is usually what you want from sequential
code. (If instead you want to collect *all* errors, as when
validating a form, that is the *applicative* or *validation*
pattern, a sibling shape we do not pursue here.) The rule of thumb:
use `option` when "no value" is the whole story, and `result` when
the failure deserves a reason, typically at module boundaries and
user-facing APIs.

## One interface for every monad

Three monads, one `let*`. That repetition is not a coincidence:
`option`, `list`, and `result` all expose the same two operations
over their own type. Module 7 gives us the tool to write that
shared interface down as a
[module type](M07-L07-signatures.html):

:::slide

## One interface: `module type MONAD`

```ocaml
module type MONAD = sig
  type 'a t
  val return : 'a -> 'a t
  val bind   : 'a t -> ('a -> 'b t) -> 'b t
end
```

- `type 'a t` is the monad's shape, left abstract: `option`,
  `list`, `result`, ... each fills it in.
- Every monad in this course provides exactly these two values, and
  `let*` is always just `bind` renamed.

:::

Each monad we built *ascribes* to `MONAD`, using a *sharing
constraint* `with type 'a t = ...` to keep its concrete carrier
visible. That part earns its keep: without it `'a t` stays
abstract, and you could not even pass a plain `int list` to
`List_monad.bind`, which is exactly what the activity below does.

:::slide

## Two instances of `MONAD`

```ocaml
module Option_monad : MONAD with type 'a t = 'a option = struct
  type 'a t = 'a option
  let return x = Some x
  let bind o f = match o with None -> None | Some x -> f x
end

module List_monad : MONAD with type 'a t = 'a list = struct
  type 'a t = 'a list
  let return x = [x]
  let bind xs f = List.concat_map f xs
end
```

- Same two operations, different carriers; each `bind` is the one
  we wrote for that monad above.
- `with type 'a t = ...` is the *sharing constraint*: it keeps the
  carrier visible, so a plain `int list` still counts as a
  `List_monad.t`.

:::

:::slide

## ...and `result`

```ocaml
module Result_monad :
  MONAD with type 'a t = ('a, string) result = struct
  type 'a t = ('a, string) result
  let return x = Ok x
  let bind r f = match r with Ok x -> f x | Error e -> Error e
end
```

- `result` settles on `string` for its error so that `'a t` takes a
  single parameter, like every other monad here.
- One `MONAD`, three implementations: that is why a single `let*`
  serves all of them.

:::

This is the precise version of the claim from
[the previous lecture](M08-L01-option-monad.html) that `return` and
`bind` form an *interface*: each monad in this course is one
concrete implementation of the same `MONAD`.

## A quick check

:::quiz mcq id=M08-L02-q2
Given `let pipeline () = let* _ = (Error "first") in let* _ =
(Error "second") in Ok 42` (with `let*` bound to `Result.bind`),
what does `pipeline ()` evaluate to?

- [ ] `Ok 42`.
- [x] `Error "first"`.
- [ ] `Error "second"`.
- [ ] `Error "first; second"`.

**Why:** `Result.bind` short-circuits on the first `Error`. The
second and third lines never run; the `Error "first"` is returned
unchanged. Collecting all errors requires the validation pattern,
not the monad.
:::

:::quiz mcq id=M08-L02-q3
Which law guarantees that you can refactor part of a `let*` chain
into a helper function without changing the result?

- [ ] Left identity.
- [ ] Right identity.
- [x] Associativity.
- [ ] None of them; refactoring monadic code is risky.

**Why:** associativity says nested `bind`s can be reassociated.
Extracting a sub-chain into a helper is exactly reassociating those
`bind`s. Left and right identity govern `return`, not the shape of
long chains.
:::

:::slide

## Activity

Use the **list monad**'s non-determinism to find every Pythagorean
triple `a*a + b*b = c*c` with `a < b` and `a`, `b`, `c` each in
`1..30` (the `a < b` is the standard convention, so each triple is
listed once). Take each of `a`, `b`, `c` from `List.init 30 succ`
with `let*`, reusing the `List_monad` from above, and use the
empty-list guard to keep only the matching triples, as `(a, b, c)`.

:::

:::solution

:::slide

## Activity solution

```ocaml
let ( let* ) = List_monad.bind   (* reuse the module from above *)

let triples =
  let* c = List.init 30 succ in   (* [1; 2; ...; 30] *)
  let* a = List.init 30 succ in
  let* b = List.init 30 succ in
  if a < b && a * a + b * b = c * c then [(a, b, c)] else []

let _ = List.length triples   (* = 11 *)
```

- This typechecks *only* because the sharing constraint exposed
  `List_monad.t` as `'a list`, so `List.init 30 succ` (an `int
  list`) is accepted by `List_monad.bind`.
- Three `let*`s search all `a, b, c` in `1..30`; the guard keeps
  the matches with `a < b` (the standard form, no `(4,3,5)`-style
  swaps) and `else []` drops the rest, giving 11 triples.

:::

:::

A code quiz on the list monad:

:::quiz code id=M08-L02-q1
Use the list monad to write `divisors_of_each : int list -> int
list` that returns every pair of integers whose product is in the
input list, reported as `a * b` to confirm. (For input `[6]`, valid
pairs include `(1, 6)`, `(2, 3)`, `(3, 2)`, `(6, 1)`.)

```ocaml
let ( let* ) xs f = List.concat_map f xs

let divisors_of_each xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  let r = divisors_of_each [6] in
  check (List.length r >= 4) "at least four factor pairs of 6";
  check (List.for_all (fun n -> n = 6) r) "every entry should equal 6";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let ( let* ) xs f = List.concat_map f xs

let divisors_of_each xs =
  let* n = xs in
  let* a = List.init n (fun i -> i + 1) in
  let* b = List.init n (fun i -> i + 1) in
  if a * b = n then [a * b] else []
```

Three `let*`s, one per dimension of the search: pick an `n` from
the input, pick `a` and `b` from `1..n`, keep only the pairs whose
product equals `n`. The list monad makes the nested search read
like ordinary sequential code.

:::

## What is next

:::slide

## What is next

Lecture 3: the **state monad** and parameterised state.

- Thread hidden state through a chain *without* mutation.
- A third monad shape, the same `let*` notation.
- Parameterised state: when the state's *type* changes per step.

:::

We have now seen three monads with one notation: `option` and
`result` for failure, `list` for non-determinism. The
[next lecture](M08-L03-state-monad.html) adds a fourth flavour, the
state monad, which threads ambient state through a chain of pure
computations, and then lets the state's type itself change from
step to step, a first bridge toward GADTs.

## Reading

- **Cornell CS3110**, *Monads*:
  <https://cs3110.github.io/textbook/chapters/conc/monads.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. The list-monad framing and the monad-laws layout draw
on the author's CS3100 monads notebook, used here as a private
structural reference; the surface code, comments, and explanations
are written from scratch. Cornell CS3110 and Real
World OCaml are CC BY-NC-ND-licensed and have not been derivatively
reused. See
[`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
