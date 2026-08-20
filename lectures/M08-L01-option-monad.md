---
title: "The option monad and `let*`"
lecture_no: 1
week: 8
duration_target_min: 26
concepts: [pyramid of doom, bind, return, option monad, let-operators, Option.bind, Option.map]
keywords: [OCaml, monad, sequencing, bind, option, let*]
activity_question: "Using the [bind] we wrote in this lecture, define [add_opt : int option -> int option -> int option] that returns [Some (x + y)] when both inputs are present and [None] otherwise. Do not re-derive [bind]; use it."
think_about_this: "What other shapes besides 'maybe a value' might want the same kind of sequencing helper? List three."
reading:
  - title: "Cornell CS3110, Monads"
    url: https://cs3110.github.io/textbook/chapters/conc/monads.html
---

# The option monad and `let*`


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">The option monad and `let*`</h2>
<p class="title-slide-label">Module 8 &middot; Lecture 1</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

Module 8 is about two ideas that recur all over real OCaml code.
The first, which occupies this lecture and the next two, is the
*monad*: a small design pattern for *sequencing computations of a
particular shape* without writing the plumbing by hand. The second,
which the module turns to after the monads, is *GADTs*, a
type-system feature for giving variants more precise types. The two
come together in the closing tutorial.

The word *monad* sounds scarier than it is. The mathematical
machinery lives in [category
theory](https://en.wikipedia.org/wiki/Category_theory), which is a
deep field in its own right but not what we are doing here. For
programming, a monad is just a *type* plus two operations (`return`
and `bind`) that let you chain computations of one shape cleanly. This
lecture builds that pattern from a concrete pain point and lands on
OCaml's `let*` syntax for it.

The pattern has an unusually clean paper trail. Eugenio Moggi, a
semanticist, showed in 1989 that a single categorical structure
could describe computational effects (exceptions, state, I/O) in
a uniform way. Philip Wadler read the mathematics and saw a
programming technique: his 1992 paper
[*The essence of functional programming*](https://dl.acm.org/doi/10.1145/143165.143169)
showed working interpreters where adding error handling or state
meant changing a few lines around an unchanged core, and monads
jumped from category theory into Haskell, then into every
functional language. What you will build in this lecture is
Wadler's move, replayed on OCaml's `option`.

:::slide

## Module 8 roadmap

- **Monads** (this lecture and the next two): a pattern for
  sequencing.
  - L1: the **option monad** and `let*` (you are here).
  - L2: the monad **laws**, the **list** monad, the **result**
    monad.
  - L3: the **state** monad and parameterised state.
- **GADTs** (L4-L6): variants that carry type-level information.
- **L7 tutorial**: a tiny well-typed evaluator combining both.
- **L8 practice**: stretch problems on monads and GADTs.

:::

## A motivating problem

We ended the [Module 5 tutorial](M05-L06-tutorial.html) with a
little expression evaluator built out of nested `match`es on
`option`: every
sub-result was unwrapped with a `Some _`/`None` arm, and `None`
propagated by hand. That boilerplate is the problem this lecture
solves.

Here is the pattern in miniature. Suppose we parse a number from a
string, double it, check it is in range, and print it. Each step
might fail, so each returns an
[`'a option`](M04-L04-recursive-types.html#the-option-type):
`Some x` on success, `None` on failure.

```ocaml
let parse_int s = int_of_string_opt s
let double x = if x > max_int / 2 then None else Some (x * 2)
let small x = if x < 100 then Some x else None
let print_num x = print_endline (string_of_int x); Some ()
```

Each `None` here marks a real failure mode. `parse_int` fails when
the string is not a number. `double` can *overflow*: native OCaml's
`int` is 63-bit, but the same code compiled to JavaScript with
[js_of_ocaml](https://ocsigen.org/js_of_ocaml/) uses 32-bit `int`s
(this is exactly how the runnable cells on this page execute), so
doubling a large value silently wraps to a wrong answer. We refuse
it and return `None` rather than lie. `small` fails when the result
is out of range. Only `print_num` always succeeds, but it still
returns `Some ()` so that every step shares the same `'a -> 'b
option` shape: that uniformity is exactly what lets us chain them.

We want to wire them together: parse, then double, then check, then
print. At each step, if the previous step said `None`, the whole
pipeline gives up; if it said `Some x`, we feed `x` to the next
step. The naive translation nests a `match` per step:

:::slide

## The pyramid of doom

```ocaml
let parse_int s = int_of_string_opt s
let double x = if x > max_int / 2 then None else Some (x * 2)
let small x = if x < 100 then Some x else None
let print_num x = print_endline (string_of_int x); Some ()

let demo s =
  match parse_int s with
  | None -> None
  | Some x ->
      match double x with
      | None -> None
      | Some y ->
          match small y with
          | None -> None
          | Some z -> print_num z
```

- Four steps, three `None -> None` arms, four levels of indent.
- The interesting logic is buried inside; the boring plumbing is on
  the outside.

:::

Every step has *exactly the same shape*: "if the previous step is
`None`, return `None`; otherwise unwrap and continue." It is
written once, then twice, then three times, growing linearly with
the number of steps. That repetition is the signal to pull out an
abstraction.

## Capturing the pattern: `bind`

Lift the repetition into a function. It takes an `option` and a
continuation saying "what to do if we have a value", and returns
the next `option`. With it the four nested matches flatten to a
vertical sequence, one `bind` per step:

:::slide

## Capturing the pattern: `bind`

```ocaml
let bind opt f =
  match opt with
  | None -> None
  | Some x -> f x

(* parse_int, double, small, print_num from the pyramid slide *)
let demo s =
  bind (parse_int s) (fun x ->
  bind (double x) (fun y ->
  bind (small y) (fun z ->
  print_num z)))
```

- `bind : 'a option -> ('a -> 'b option) -> 'b option`: an option,
  plus a continuation, giving the next option.
- One `bind` per step; the `None` plumbing lives once, inside it.
- Still noisy: the parentheses pile up, heavier than `let ... in`.

:::

OCaml infers `bind`'s type as `'a option -> ('a -> 'b option) -> 'b
option`: given the previous step's result and a continuation that
produces the next option, it returns the combined,
possibly-short-circuited result. The two type variables are
independent because the value type changes from step to step
(string to int, int to int, and so on).

`bind` collapses the three `None -> None` arms into one definition,
but it is still noisy: each line opens a parenthesis that piles up
at the end, and `bind ... (fun x -> ...)` is heavier than `let x =
... in ...`. OCaml has one more piece of sugar that closes the gap.

## Monad definition

A monad is a type plus two operations. Concretely for `option`:

:::slide

## Monad definition

```ocaml
module Opt = struct
  let return x = Some x
  let bind opt f =
    match opt with
    | None -> None
    | Some x -> f x
  let ( let* ) = bind
end
```

Two functions and one operator alias:

- `return : 'a -> 'a option`. Lift a plain value into the option
  world (just `Some`).
- `bind : 'a option -> ('a -> 'b option) -> 'b option`. Sequence
  two optional steps.
- `let*` is `bind` under a syntactic-sugar name.

:::

`return` (sometimes called `pure`) is the trivial way to put a
plain value into the option world. It earns a name because it is
part of the monad *interface*: anything claiming to be a monad
provides `return` and `bind`, and the rest of the code can pretend
not to know which monad it is using.

The line `let ( let* ) = bind` is what turns on the sugar. The
identifier `( let* )` is a *let-operator* (an OCaml feature since
4.08). Any identifier `let X` whose `X` starts with a punctuation
character can be bound to a function; once it is in scope, the
compiler treats `let* x = e in rest` as sugar for `( let* ) e (fun
x -> rest)`, which is `bind e (fun x -> rest)`. That single
rewrite rule is the whole feature.

## Using `let*`

The pyramid, one more time, now with `let*`:

:::slide

## Using `let*`

```ocaml
open Opt   (* Opt's let* and return are now in scope *)

let demo s =
  let* x = parse_int s in
  let* y = double x in
  let* z = small y in
  print_num z

let _ = demo "5"      (* prints 10; = Some () *)
let _ = demo "frog"   (* = None *)
let _ = demo "200"    (* = None *)
```

- `open Opt` brings the module's `let*` into scope, so we use it
  without the `Opt.` prefix.
- Each step is `let* name = expression in ...`; it reads almost
  like ordinary `let ... in ...`, the only mark being the `*`.
- Hidden: if any step gives `None`, the rest is skipped.

:::

The compiled code is identical to the nested-`match` and
explicit-`bind` forms: `let*` is purely syntactic sugar that
elaborates back to `bind`. A reader learns to read `let*` as "this
might fail, and if it does, give up"; each `let*` line names the
*successful* result, and the short-circuit on failure is implicit.
The whole function reads top to bottom with no nested matches.

## `let*` is not magic

We just used `let*`; here is why it is not magic. *Ordinary* `let`
works the same way. Name reverse application `flip` (so `flip a f =
f a`): then `let x = e in rest` is `flip e (fun x -> rest)`, and
`let*` has the *identical* shape, swapping `flip` for `bind`:

:::slide

## `let*` is not magic

```text
let  x = e in rest   is   flip e (fun x -> rest)
let* x = e in rest   is   bind e (fun x -> rest)
```

- Same shape: `combinator value (fun x -> continuation)`.
- `flip` just hands the value to the continuation; `bind` does that
  *and* the monad's work (for `option`, the `None` short-circuit).
- That extra work inside `bind` is the *only* difference.

:::

So reading `let*` is no harder than reading `let`: bind a name,
then continue. The extra behaviour is invisible at the call site
and lives entirely in the monad's `bind`.

## `Option.bind` and `Option.map`

The standard library ships these, so you do not write them yourself
in real code:

:::slide

## `Option.bind` and `Option.map`

```ocaml
let _ = Option.bind (Some 5) (fun x -> if x > 0 then Some (x * 2) else None)  (* = Some 10 *)
let _ = Option.bind None (fun x -> Some (x + 1))   (* = None *)
let _ = Option.map (fun x -> x * 2) (Some 5)        (* = Some 10 *)
```

- `Option.bind` is exactly the `bind` we defined.
- `Option.map` is weaker: it applies a *pure* function inside the
  option (the continuation cannot fail).
- Use `bind` when the next step itself returns an option; use `map`
  when it is a pure transformation.

:::

In monad-speak, `map` is the *functor* operation and `bind` the
stronger monad operation; `map` can be defined as `bind opt (fun x
-> Some (f x))`. There is also a sibling let-operator, `( let+ )`,
for map-only chains where no new failure is introduced; you will
meet it in real code, but `let*` alone covers everything we need
here.

In practice, codebases that lean on monads define a small module
per monad with `bind`, `( let* )`, and helpers, then `let open M
in` at the top of a function so the rest reads as plain `let*`. The
compiler does not guess which monad you mean: you choose it by what
is in scope, and the type of `let*` is always right there in front
of you.

## A realistic example: reaching into optional data

A `user` may have no `city`, a `city` may have no `address`, and an
`address` may have no `zip`. To get a user's zip we must descend
through all three options. This is
the pattern other languages bake into syntax as *optional chaining*
(`a?.b?.c` in Swift, Kotlin, or C#; `&.` in Ruby); in OCaml it is
just `let*` over `option`:

:::slide

## A realistic example: optional chaining

```ocaml
(* let* is in scope from the "Using let*" slide above *)
type address = { zip : string option }   (* more fields in real life *)
type city    = { address : address option }
type user    = { name : string; city : city option }

let user_zip u =
  let* city = u.city in          (* user may have no city *)
  let* addr = city.address in    (* city may have no address *)
  let* zip  = addr.zip in        (* address may have no zip *)
  Some (String.uppercase_ascii zip)
```

- `zip` comes from `addr`, which comes from `u.address`: each step
  *needs* the previous value, so this cannot collapse to one match.
- Any `None` on the way down short-circuits the whole lookup.

:::

:::slide

## Trying it

```ocaml
let u1 = { name = "Asha"; city = Some { address = Some { zip = Some "ec1a 1bb" } } }
let u2 = { name = "Ravi"; city = Some { address = Some { zip = None } } }
let u3 = { name = "Meera"; city = Some { address = None } }
let u4 = { name = "Dev"; city = None }

let _ = user_zip u1   (* = Some "EC1A 1BB" *)
let _ = user_zip u2   (* = None: address present, zip missing *)
let _ = user_zip u3   (* = None: no address at all *)
let _ = user_zip u4   (* = None: no city at all *)
```

- `u1`: every layer present, so the zip comes back uppercased.
- `u2`, `u3`, `u4`: a missing layer anywhere short-circuits to `None`.

:::

This is where `let*` beats a single `match`: because each
step depends on the previous one's value, you cannot lift the
checks into one flat match. It is the safe-navigation idiom that
`option` plus `let*` gives you for free, the antidote to the null
dereference [Module 4](M04-L04-recursive-types.html) warned about.

## When *not* to use a monad

A monad is overkill for a single optional step. The plain `match`
is shorter and just as clear:

:::slide

## When *not* to use a monad

```ocaml
let _ =
  match int_of_string_opt "frog" with
  | Some n -> n * 2
  | None -> 0          (* "frog" doesn't parse, so = 0 *)
```

Two cases, one `match`, three lines. No monad needed.

- Reach for `let*` at **three or more** sequential optional steps.
- Below three, the `match` is shorter and equally clear.
- Above three, the pyramid bites, and `let*` wins.

:::

There is nothing magic about three; it is a rule of thumb. If you
find yourself indenting past column 50 to handle a third level of
`None`, switch to `let*`. (A *lawful* monad's `return` and `bind`
also satisfy three equational laws; we make those precise in the
[next lecture](M08-L02-laws-list-result.html).)

## Where else does this come up?

The pattern is worth learning because the same `'a t` + `return` +
`bind` shape recurs everywhere, with `t` different each time:

:::slide

## Same shape, many monads

- `'a option`: maybe a value (this lecture).
- `('a, 'e) result`: a value or an error with information (next
  lecture).
- `'a list`: zero, one, or many values; `bind` is flat-map across
  all of them (the list monad, next lecture).
- `state -> 'a * state`: a value threaded against ambient state
  (the state lecture).
- `'a Lwt.t` / `'a Eio.Promise.t`: a value available after I/O
  completes (concurrent programming).
- `'a parser`: a parser consuming input (parser combinators).

One notation (`let*`), one intuition, many concrete monads.

:::

Build the habit of asking "is this shape a monad?" whenever you
write a computation that may not produce a plain value, and you
will spot the pattern far more often than you would expect.

## A quick check

:::quiz mcq id=M08-L01-q1
What is the type of the helper `bind` we defined?

- [ ] `'a option -> 'a option -> 'a option`
- [x] `'a option -> ('a -> 'b option) -> 'b option`
- [ ] `'a -> ('a -> 'b option) -> 'b option`
- [ ] `'a option -> ('a -> 'b) -> 'b option`

**Why:** `bind` takes an option (the previous step's result), a
function that turns the unwrapped value into the next option, and
returns that next option. The two type variables `'a` and `'b` are
independent because the value type can change from step to step
(parse a string to an int, then double the int, etc.).
:::

:::quiz mcq id=M08-L01-q2
You have `let* x = e1 in let* y = e2 in let* z = e3 in Some (x, y,
z)`, where `e1` is `Some 1`, `e2` is `None`, and `e3` is some
expression. What does the whole thing evaluate to, and how many
times is `e3` evaluated?

- [ ] `Some (1, ?, ?)`, evaluated once.
- [x] `None`, evaluated zero times.
- [ ] `Some (1, _, _)`, evaluated zero times.
- [ ] An exception is raised.

**Why:** the option monad short-circuits on the first `None`. Once
`e2` is `None`, the surrounding `let*` returns `None` without
evaluating its continuation, so `e3` never runs. Failure is
detected as soon as it happens and downstream code is skipped.
:::

:::slide

## Activity

The `bind` we wrote chains *one* option into the next. Use it to
combine *two*: define `add_opt : int option -> int option -> int
option` that returns `Some (x + y)` when both inputs are present,
and `None` if either is missing. Do not re-derive `bind`; use it.

:::

:::solution

:::slide

## Activity solution

```ocaml
let bind opt f =
  match opt with
  | None -> None
  | Some x -> f x

let add_opt a b =
  bind a (fun x ->
  bind b (fun y ->
  Some (x + y)))

let _ = add_opt (Some 3) (Some 4)   (* = Some 7 *)
let _ = add_opt (Some 3) None       (* = None *)
let _ = add_opt None (Some 4)       (* = None *)
```

- The outer `bind` unwraps `a`, the inner unwraps `b`; the body
  runs only when both are `Some`.
- If either is `None`, the matching `bind` short-circuits to
  `None`.

:::

:::

A code quiz to consolidate:

:::quiz code id=M08-L01-q3
Using the given `bind` and `safe_div`, write `div_chain : int ->
int -> int -> int option` that computes `a / b / c`, returning
`None` if either division is by zero.

```ocaml
let bind opt f =
  match opt with
  | None -> None
  | Some x -> f x

let safe_div a b = if b = 0 then None else Some (a / b)

let div_chain a b c =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (div_chain 100 5 2 = Some 10) "both divisions succeed";
  check (div_chain 100 0 2 = None) "first division by zero";
  check (div_chain 100 5 0 = None) "second division by zero";
  check (div_chain 7 2 1 = Some 3) "integer division floors";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let div_chain a b c =
  bind (safe_div a b) (fun ab ->
  safe_div ab c)
```

Two divisions, one `bind`, then a tail call. The chain
short-circuits on the first divide-by-zero. Sugared with `let*`
this reads `let* ab = safe_div a b in safe_div ab c`.

:::

## What is next

:::slide

## What is next

Lecture 2: the **monad laws**, the **list** monad, and the
**result** monad.

- Three equations a "lawful" monad satisfies.
- `'a list` as a monad: `bind = List.concat_map` (non-determinism).
- `('a, 'e) result`: the same shape, but failure carries
  information.

:::

The [next lecture](M08-L02-laws-list-result.html) states the three
laws that make a monad well-behaved, then shows the same `let*`
notation driving two very different shapes: the list monad (many
values) and the result monad (a value or an informative error).

## Reading

- **Cornell CS3110**, *Monads*:
  <https://cs3110.github.io/textbook/chapters/conc/monads.html>

## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
