---
title: "Function composition and pipelines"
lecture_no: 5
week: 6
youtube_id: olKSNQo9eKU
duration_target_min: 20
concepts: [function composition, pipeline operator, point-free style, readability]
keywords: [OCaml, function composition, pipeline, |>, @@, point-free]
activity_question: "Write [is_short : string -> bool], true exactly when a word has at most 3 letters, two ways: as an explicit lambda, and as a composition of [String.length] with a comparison using a helper [compose]. Then use it with [List.filter] to keep the short words of a list."
think_about_this: "The pipeline operator [|>] is *just* application, written right-to-left in operand order. Why is its existence in the language worth more than zero, given that you could always write [f (g (h x))]?"
reading:
  - title: "Cornell CS3110, Pipelining"
    url: https://cs3110.github.io/textbook/chapters/hop/pipelining.html
---

# Function composition and pipelines


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Function composition and pipelines</h2>
<p class="title-slide-label">Module 6 &middot; Lecture 5</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

We now have a small toolkit: [`map`](M06-L02-map.html),
[`filter`](M06-L03-filter.html), [`fold`](M06-L04-fold.html), and a
habit of writing one-off functions with `fun x -> ...`. The natural
next question is how to *chain* these together. A real program
might "split text into words, then drop the short ones, then
lowercase them, then count the distinct ones." That is four
operations, and the obvious code is three or four nested function
calls. Read it top-to-bottom and the logical flow goes the wrong
way.

This lecture is about two pieces of plumbing that fix that
inside-out reading order. The first is the *pipeline operator* `|>`,
which is one of the most quietly important operators in the
standard library. The second is *function composition*, which
packages two functions into one without naming an intermediate
argument. Both are tiny, both are everyday OCaml, and both make
higher-order code more readable.

:::slide

## This lecture: pipelines and composition

- We have `map`, `filter`, `fold`, and `fun x -> ...`. How to *chain* them?
- Real code: split, drop short, lowercase, count distinct. Four steps.
- Nested calls read inside-out; the logic flows the wrong way.
- Two pieces of plumbing fix that:
  - The pipeline operator `|>`.
  - Function composition.
- Tiny operators; everyday OCaml; higher-order code becomes readable.

:::

## The pipeline operator `|>`

The operator `|>` is defined, in its entirety, like this:

```ocaml
let ( |> ) x f = f x
```

That is the entire definition. `x |> f` is exactly `f x`. Nothing
new computationally; nothing magical. The only reason for its
existence is to let you write `f x` as `x |> f`, which is to say:
write the value first, then the function. Pipelining a single
function this way is overkill (you would just write `f x`), but
pipelining a *chain* of functions transforms how the code reads.

Consider the four-step pipeline I described above (split, drop
short, lowercase, count distinct). Written with `|>`:

```ocaml
let _ =
  [1; 2; 3; 4; 5]
  |> List.map (fun x -> x * x)
  |> List.filter (fun y -> y > 5)
  |> List.fold_left (+) 0  (* = 50 *)
```

:::slide

## The pipeline operator `|>`

- `x |> f` is *exactly* `f x`.
- Defined in the standard library as:

```ocaml
let ( |> ) x f = f x
```

- The only reason it exists: write chains in the order they happen,
  instead of inside-out.

:::

:::slide

## A pipeline in action

```ocaml
let _ =
  [1; 2; 3; 4; 5]
  |> List.map (fun x -> x * x)
  |> List.filter (fun y -> y > 5)
  |> List.fold_left (+) 0  (* = 50 *)
```

- Squares of 1-5: `[1;4;9;16;25]`.
- Keep those > 5: `[9;16;25]`.
- Sum: `50`.
- Read top-to-bottom: list, square, filter, sum.

:::

The result is `50`. Read it top to bottom and you see exactly what
happens, in order:

1. Start with `[1; 2; 3; 4; 5]`.
2. Square each element. (`[1; 4; 9; 16; 25]`.)
3. Filter to keep only the ones greater than `5`. (`[9; 16; 25]`.)
4. Sum them. (`50`.)

The visual order of the code matches the logical order of the
computation. That is the entire point of `|>`.

## Without `|>`: parens and reading right-to-left

Without `|>`, the same computation has to be written as a tower of
nested calls:

```ocaml
let _ = List.fold_left (+) 0
          (List.filter (fun y -> y > 5)
             (List.map (fun x -> x * x)
                [1; 2; 3; 4; 5]))  (* = 50 *)
```

:::slide

## Without `|>`: parens and reading right-to-left

The same computation:

```ocaml
let _ = List.fold_left (+) 0
          (List.filter (fun y -> y > 5)
             (List.map (fun x -> x * x)
                [1; 2; 3; 4; 5]))  (* = 50 *)
```

Same answer, but:

- You start at the *innermost* parens (`[1; 2; 3; 4; 5]`).
- Then move outward.
- Reading direction is opposite to the dataflow.
- `|>` doesn't introduce new computation: it aligns visual order
  with conceptual order.

:::

To follow what this does, you have to find the innermost expression
(the list literal), then mentally unwrap each layer outward. That is
backwards from how the computation actually proceeds. For a chain of
two or three steps it is tolerable; for five or ten it is awful.

`|>` does not introduce new computation. It does not let you write
anything you could not have written before. Its single contribution
is to align the visual order of your code with the conceptual order
of the data flow. That is enough to make it indispensable.

If you have programmed in a Unix shell, `|>` is exactly the shell's
`|`: each step receives the output of the previous step as its
input, and you write the steps in the order they happen.
[The pipeline notation in Unix](https://www.bell-labs.com/usr/dmr/www/hist.html)
goes back to Doug McIlroy in the 1960s; functional-programming
languages adopted it in the form `|>` in the 2000s
(F# popularised the spelling; OCaml added `|>` to its standard
library in version 4.01, released in 2013).
The Unix analogy is not just a metaphor: the semantics are exactly
"the value flows from one step to the next."

## The application operator `@@`

The dual operator `@@` does the same trick in the other direction:
`f @@ x` is `f x`, with low precedence and right-associativity. It
lets you avoid parens *on the right* of a function call when the
argument is a long expression.

```ocaml
let _ = print_endline @@ string_of_int 42  (* prints 42 *)
let _ = print_endline (string_of_int 42)   (* prints 42 *)
```

:::slide

## The application operator `@@`

- Dual of `|>`: `f @@ x` is also `f x`.
- Used to avoid parens on the right:

```ocaml
let _ = print_endline @@ string_of_int 42  (* prints 42 *)
let _ = print_endline (string_of_int 42)   (* prints 42 *)
```

Same thing.

- `@@` is right-associative and low precedence.
- `f @@ g @@ x` parses as `f (g x)`.
- It's the application counterpart of `|>` in the *other* direction.
- Use `@@` when the alternative is `(f x)` with parens around a
  long expression.

:::

You will see `@@` mostly when the right-hand side is a deeply nested
expression that would otherwise need awkward parentheses. The chain
`f @@ g @@ x` parses as `f (g x)`, so it is *the same direction* as
nested function calls, not the opposite of `|>`. Use it sparingly:
in most code, `|>` is the more readable form because it matches the
direction of data flow.

## Function composition

A different way to chain functions: build a new function that
*combines* two existing functions. If `f : 'b -> 'c` and `g : 'a ->
'b`, the composition `fun x -> f (g x)` is a function `'a -> 'c`
that runs `g`, then `f`. We previewed this in
[Lecture 1](M06-L01-functions-revisited.html#function-composition);
here we look at it more carefully.

OCaml's standard library does not give this composition a built-in
operator (some projects define `(>>)` or `(<<)`), so let us write it
ourselves:

```ocaml
let compose f g = fun x -> f (g x)

let square_then_inc = compose (fun x -> x + 1) (fun x -> x * x)
let _ = square_then_inc 4  (* = 17 *)
```

:::slide

## Function composition

A composition operator could be defined as:

```ocaml
let compose f g = fun x -> f (g x)

let square_then_inc = compose (fun x -> x + 1) (fun x -> x * x)
let _ = square_then_inc 4  (* = 17 *)
```

`4 * 4 = 16`, then `+ 1 = 17`.

- `compose f g` means "do `g` first, then `f`".
- Mathematically: `f ∘ g`.
- Standard library has no built-in composition operator.
- Some projects define one as `(>>)` or `(<<)`; easy to write yourself.

:::

`square_then_inc 4` produces `17`: square `4` to get `16`, then add
`1`. The order of arguments to `compose` mirrors mathematical
notation: `compose f g` is *f composed with g*, written `f ∘ g`,
which means "do g first, then f."

The type signature:

```
val compose : ('b -> 'c) -> ('a -> 'b) -> 'a -> 'c
```

You can read it as: given a function `'b -> 'c` and a function `'a ->
'b`, return a function `'a -> 'c`. The intermediate type `'b` is
where the two halves "fit together."

Some projects define composition as a left-to-right operator
(`(>>)`), in which case `f >> g` means "do `f` first, then `g`."
That matches the natural reading direction but reverses the
mathematical convention. Neither convention is universally right;
when you encounter a project, find out which one is in use and stick
with it.

## Point-free style

Once you have composition, you can sometimes write a function
*without naming its argument at all*:

```ocaml
let compose f g = fun x -> f (g x)

let process = compose (fun x -> x * 2) (fun x -> x + 1)
let _ = process 5  (* = 12 *)
```

:::slide

## Point-free style

- Express a function as a composition of others **without** naming
  the argument: this is **point-free** style.

```ocaml
let compose f g = fun x -> f (g x)

let process = compose (fun x -> x * 2) (fun x -> x + 1)
let _ = process 5  (* = 12 *)
```

- `process` doesn't mention its argument explicitly.
- It's defined entirely as a pipeline of two functions.
- Some love point-free; some find it cryptic.
- Pragmatic rule: use it when the composition is *obvious*; name
  the argument when there's any twist (a condition, a destructuring).

:::

`process 5` computes `(5 + 1) * 2 = 12`. The definition of `process`
never mentions a variable `x`: it is built entirely as a composition
of other functions. This is called *point-free* style (the "points"
are the function arguments; we are programming without them).

Point-free style has its enthusiasts and its detractors. At its
best, it makes the structure of a computation visually obvious: you
see two functions composed, and the data flow is implicit.
[Haskell idioms](https://wiki.haskell.org/Pointfree) lean heavily on
it. At its worst, it produces line noise where the original
explicit-argument version was clearer.

The pragmatic rule: use point-free style when the composition is
obvious from context. When there is any twist (a conditional, a
destructuring of an argument, a less common combinator), name the
argument and write the function the long way. Readability beats
cleverness.

## Pipelines are point-free at runtime

A nice middle ground: the pipeline form `xs |> f |> g |> h` is
*locally* point-free (none of `f`, `g`, `h` name their argument
explicitly inside the pipeline), but you still get to give a name to
the initial value (`xs`). This is often the right blend of clarity
and brevity.

```ocaml
let normalize_words text =
  text
  |> String.lowercase_ascii
  |> String.split_on_char ' '
  |> List.filter (fun s -> s <> "")
  |> List.map String.trim

let _ = normalize_words "  Hello World  "  (* = ["hello"; "world"] *)
```

:::slide

## Pipelines are point-free at runtime

```ocaml
let normalize_words text =
  text
  |> String.lowercase_ascii
  |> String.split_on_char ' '
  |> List.filter (fun s -> s <> "")
  |> List.map String.trim

let _ = normalize_words "  Hello World  "  (* = ["hello"; "world"] *)
```

- `text` is named at the top; inside the pipeline, each function
  receives an *unnamed* value (the previous step's output).
- Readable middle ground between "tons of lambdas" and "deep parens".

:::

The result is `["hello"; "world"]`. The function `normalize_words`
takes a string and returns a list of normalised words. Each step in
the pipeline reads as a clear transformation: lowercase, split,
filter, trim. You can see the data being shaped at each step. No
intermediate variables; no nested calls; no anonymous functions
except the one trivial empty-string check.

This pattern is the bread-and-butter of higher-order programming in
OCaml (and in F#, Elixir, and other languages with `|>`). It is
worth getting fluent in.

## When to use composition / pipeline / explicit lambdas

There is more than one way to write a single transformation. Suppose
we want to add `1` to every element of a list:

```ocaml
(* (1) explicit *)
let f1 xs = List.map (fun x -> x + 1) xs

(* (2) partial application + map *)
let f2 = List.map ((+) 1)

(* (3) pipeline (only useful when there's a chain) *)
let f3 xs = xs |> List.map ((+) 1)
```

:::slide

## When to use composition / pipeline / explicit lambdas

Three options for the same code:

```ocaml
(* (1) explicit *)
let f1 xs = List.map (fun x -> x + 1) xs

(* (2) partial application + map *)
let f2 = List.map ((+) 1)

(* (3) pipeline (only useful when there's a chain) *)
let f3 xs = xs |> List.map ((+) 1)
```

All three are `int list -> int list`.

- `f1`: most explicit; you see the lambda.
- `f2`: point-free; clean for short functions.
- `f3`: useful when there are *more* steps; otherwise just noise.
- Reach for `|>` when you have **three or more** steps in a row.

:::

All three have the type `int list -> int list`. Which to prefer?

- **`f1` is the most explicit.** The lambda makes the per-element
  operation visually clear. Good for code that someone unfamiliar
  with idiomatic OCaml will read.
- **`f2` is point-free.** Clean and concise, but requires the reader
  to know that `(+) 1` is "add 1." Good for short functions in
  contexts where this idiom is established.
- **`f3` is a pipeline for one step.** Almost always overkill. Use
  the pipeline when there are *three or more* steps; below that
  threshold it adds visual noise without paying back.

The threshold is a matter of taste, but "three or more steps before
reaching for `|>`" is a reasonable rule. The exception: if there is
any sense in which the data is the "subject" of the sentence and the
functions are "verbs" being applied to it, pipelining one step can
still be clearer. Use your judgment; do not pipe everything by reflex.

## Putting it together

A worked example combining the lecture's pieces. Suppose we have a
list of records and want to compute the average age of adults:

```ocaml
type person = { name : string; age : int }

let people = [
  { name = "Ada"; age = 36 };
  { name = "Bob"; age = 17 };
  { name = "Cleo"; age = 24 };
  { name = "Dan"; age = 12 };
]

let average_adult_age people =
  let ages =
    people
    |> List.filter (fun p -> p.age >= 18)
    |> List.map (fun p -> p.age)
  in
  match ages with
  | [] -> None
  | _ ->
      let total = List.fold_left (+) 0 ages in
      let count = List.length ages in
      Some (float_of_int total /. float_of_int count)

let _ = average_adult_age people  (* = Some 30.0 *)
```

The two adults (Ada and Cleo) have ages `36` and `24`, average
`30`. The pipeline pulls out the ages of
adults in a clean two-step chain; the final aggregation needs the
list length (`List.length`) so it lives outside the pipeline. We
return a `float option` because the average is undefined for an
empty list. This is a real shape of code, and it is the kind of thing
Module 6 is preparing you to write fluently.

## A quick check

:::quiz mcq id=M06-L05-q3
What is `[1; 2; 3] |> List.map ((+) 10)`?

- [ ] `[10; 11; 12]`
- [ ] `[11; 12; 13; 10]`
- [x] `[11; 12; 13]`
- [ ] An error: `|>` does not accept a list on the left.

**Why:** `xs |> f` is `f xs`. So this is `List.map ((+) 10) [1; 2;
3]`. The function `(+) 10` adds 10 to its argument. Mapping gives
`[11; 12; 13]`. The pipeline operator does not change the meaning;
it changes the writing order.
:::

:::quiz mcq id=M06-L05-q2
What does `compose f g x` compute, where `let compose f g = fun x ->
f (g x)`?

- [x] `f (g x)`
- [ ] `g (f x)`
- [ ] `f x ; g x`
- [ ] `f (compose g x)`

**Why:** the definition says exactly `f (g x)`. The first function
listed (`f`) is the *outer* one, applied to the result of the second
(`g`). Mathematically, `f ∘ g` means "do `g` first, then `f`." Some
libraries reverse this convention; check before relying on it.
:::

A code challenge:

:::quiz code id=M06-L05-q1
Write `sum_of_even_squares : int list -> int` that returns the sum
of the squares of the even elements of a list. Use `|>` and at
least two of `List.map`, `List.filter`, `List.fold_left`.

```ocaml
let sum_of_even_squares xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (sum_of_even_squares []                  = 0)  "empty";
  check (sum_of_even_squares [1; 3; 5]           = 0)  "no evens";
  check (sum_of_even_squares [2; 4]              = 20) "2^2 + 4^2";
  check (sum_of_even_squares [1; 2; 3; 4; 5; 6]  = 56) "2^2 + 4^2 + 6^2";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let sum_of_even_squares xs =
  xs
  |> List.filter (fun x -> x mod 2 = 0)
  |> List.map (fun x -> x * x)
  |> List.fold_left (+) 0
```

Three steps, all pipelined: filter out the odd elements, square the
remaining ones, sum. A very common shape.

:::

## Activity

:::slide

## Activity

Write `is_short : string -> bool`, true exactly when a word has at
most 3 letters, two ways:

1. As an explicit lambda `fun w -> ...`.
2. By composing `String.length` with a comparison, using a
   `compose` helper you define yourself.

Then use it with `List.filter` to keep the short words of a list.

:::

:::solution

:::slide

## Activity solution

```ocaml
let f1 = fun w -> String.length w <= 3

let compose g f = fun x -> g (f x)
let f2 = compose (fun n -> n <= 3) String.length

let _ = f1 "fox"    (* = true *)
let _ = f2 "quick"  (* = false *)
let _ = List.filter f2 ["the"; "quick"; "fox"; "is"]  (* = ["the"; "fox"; "is"] *)
```

Same predicate, two spellings.

- `f1` is direct: measure the word, compare the length.
- `f2` composes the comparison with `String.length`:
  - length first, then `<= 3`.
- A composed *predicate* slots straight into `List.filter`.

:::

:::

## What's next

We have all the pieces. The next and final lecture in this module
is the [tutorial](M06-L06-tutorial.html): exercises that rebuild
parts of `List` using only the higher-order toolkit, and then
lift `fold` itself to binary trees and rose trees. The exercise
is not just about practice; it is about seeing how versatile a
tiny set of primitives is, and how the *same* pattern carries
over to other recursive data types.

:::slide

## What's next

Lecture 6: the **tutorial** for Module 6.

- Rebuild small parts of `List` (`sum`, `concat`, `count`, ...).
- Then fold across other shapes: pre / in / post / level-order on
  binary trees, and rose-tree folds.

:::

## Reading

- **Cornell CS3110**, *Pipelining*:
  <https://cs3110.github.io/textbook/chapters/hop/pipelining.html>
- **Real World OCaml**, *Variables and functions*:
  <https://dev.realworldocaml.org/variables-and-functions.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
