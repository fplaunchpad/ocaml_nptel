---
title: "`filter`: keep what passes the predicate"
lecture_no: 3
week: 6
duration_target_min: 20
concepts: [filter, predicate, list filtering, filter_map, partition]
keywords: [OCaml, filter, predicate, list, higher-order]
activity_question: "Write [unique : 'a list -> 'a list] that removes duplicate elements, keeping the first occurrence of each (so the output preserves the order in which elements first appear in the input). (Hint: use [List.mem] to check whether a value has already been seen.)"
think_about_this: "[filter] returns a sublist of its input. [map] returns a list of the same length. What kind of operation would return a list of *different* length but not necessarily a sublist? Where would you reach for [filter_map]?"
reading:
  - title: "Cornell CS3110, Filter"
    url: https://cs3110.github.io/textbook/chapters/hop/filter.html
---

# `filter`: keep what passes the predicate


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">`filter`: keep what passes the predicate</h2>
<p class="title-slide-label">Module 6 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

`filter` is the second of the three canonical higher-order list
functions. Where [`map`](M06-L02-map.html) transforms every element
and keeps them all, `filter` keeps each element exactly as it was,
but drops the ones that fail a test. Its type signature, `('a ->
bool) -> 'a list -> 'a list`, encodes that promise: the function
argument is a *predicate* (it returns a `bool`), and the result list
has the same element type as the input. No transformation; just
selection.

The pair `map` + `filter` covers much of everyday list
manipulation. The rest of this lecture works through the
definition, the common variations (`filter_map`, `partition`), and
the points where you should pause and reach for `filter` rather than
something else.

:::slide

## This lecture: `filter`

- `filter p xs`: keep the elements for which `p` is `true`, drop the rest.
- Type: `('a -> bool) -> 'a list -> 'a list`. No transformation; selection.
- The predicate is a `bool`-returning function.
- `map` + `filter` covers much of list manipulation.
- Also today: `filter_map`, `partition`, when to reach for `filter`.

:::

## Writing `filter` from scratch

Just as we did with [`map`](M06-L02-map.html#writing-map-from-scratch),
let us start from two concrete functions that share a shape.

```ocaml
let rec evens = function
  | [] -> []
  | h :: t -> if h mod 2 = 0 then h :: evens t else evens t

let rec positives = function
  | [] -> []
  | h :: t -> if h > 0 then h :: positives t else positives t

let _ = evens [1; 2; 3; 4]           (* = [2; 4] *)
let _ = positives [-2; 0; 3; -1; 5]  (* = [3; 5] *)
```

Both walk a list. Both keep an element if some condition is true and
drop it otherwise. The condition is the only thing that differs:
`h mod 2 = 0` vs `h > 0`. Factor the condition out as a parameter
`p` (for *predicate*):

```ocaml
let rec filter p = function
  | [] -> []
  | h :: t -> if p h then h :: filter p t else filter p t
```

:::slide

## Definition

```ocaml
let rec filter p = function
  | [] -> []
  | h :: t ->
      if p h then h :: filter p t
      else filter p t

let _ = filter (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5; 6]  (* = [2; 4; 6] *)
```

- Type: `('a -> bool) -> 'a list -> 'a list`.
- Predicate takes an element and returns a `bool`.
- Result list has the **same element type**, possibly shorter.

:::

Now `evens` and `positives` collapse to one-liners:

```ocaml
let evens     = filter (fun x -> x mod 2 = 0)
let positives = filter (fun x -> x > 0)
```

That is the entire trick. The standard library calls this function
`List.filter`, and the implementation is essentially what we wrote.
The library version is also stack-safe on long lists, which we
will come back to in a moment.

## Type and what it tells you

The signature of `filter`:

```
val filter : ('a -> bool) -> 'a list -> 'a list
```

The element type appears in three places, and it is the same `'a`
in each: the predicate takes an `'a`, the input is a list of `'a`,
the output is also a list of `'a`. Filtering cannot change the type
of the elements. If you find yourself wanting to "filter and
transform," you want [`filter_map`](#filtermap-filter-and-transform-in-one-pass),
which we will see below.

The output is always a *sublist* of the input, in the same order.
The relative order of elements is preserved: filter never reshuffles.

## Examples

```ocaml
let _ = List.filter (fun n -> n > 5) [3; 7; 1; 8; 2; 9]                          (* = [7; 8; 9] *)
let _ = List.filter (fun s -> String.length s > 3) ["hi"; "hello"; "ok"; "world"] (* = ["hello"; "world"] *)
```

:::slide

## `filter` in the standard library

```ocaml
let _ = List.filter (fun n -> n > 5) [3; 7; 1; 8; 2; 9]                          (* = [7; 8; 9] *)
let _ = List.filter (fun s -> String.length s > 3) ["hi"; "hello"; "ok"; "world"] (* = ["hello"; "world"] *)
```

- Same pattern: predicate first, list second.
- Result is a sublist: elements in the same order, just fewer.

:::

The argument order matters: predicate first, list second. This is
consistent with `List.map` (function first, list second) and with
[`List.fold_left`](M06-L04-fold.html#foldleft-the-other-direction)
(function first, accumulator second, list third). The convention is
that "the part that varies between calls" (the function argument)
comes first; the list comes last. This lets you partially apply the
function argument and get back a useful specialised function, like
`evens = filter (...)` above; the rule of thumb is "data goes last."

## Combining `map` and `filter`

A great deal of everyday list processing is "map, then filter" or
"filter, then map":

```ocaml
let big_squares xs =
  xs
  |> List.map (fun x -> x * x)
  |> List.filter (fun y -> y > 10)

let _ = big_squares [1; 2; 3; 4; 5]  (* = [16; 25] *)
```

:::slide

## Combining `map` and `filter`

```ocaml
let big_squares xs =
  xs
  |> List.map (fun x -> x * x)
  |> List.filter (fun y -> y > 10)

let _ = big_squares [1; 2; 3; 4; 5]  (* = [16; 25] *)
```

- `|>` is the *pipeline operator*: `x |> f` is the same as `f x`.
- Lets you read left-to-right (covered fully in Lecture 5).
- Top-to-bottom: start with the list, square each, keep those above 10.

:::

`big_squares` returns `[16; 25]`: square each of `1..5` to get
`[1; 4; 9; 16; 25]`, then keep those above 10 to get `[16; 25]`.

The pipeline operator `|>` is just function application written in
the other direction: `x |> f` is exactly `f x`. We will dedicate
[Lecture 5](M06-L05-pipelines.html) to it. For now, notice that the
pipeline reads top to bottom as a clear sequence of steps: start
with the list, square, filter. The alternative is nested calls:

```ocaml
let big_squares xs =
  List.filter (fun y -> y > 10) (List.map (fun x -> x * x) xs)
```

Same answer, but you have to read inside-out: find `xs` at the
deepest level, then `map`, then `filter`. With three or more steps
the inside-out version becomes unreadable; the pipeline form keeps
its clarity.

## `filter` preserves relative order

A property worth stating explicitly:

```ocaml
let _ = List.filter (fun x -> x > 3) [5; 1; 7; 2; 9; 3; 4]  (* = [5; 7; 9; 4] *)
```

:::slide

## `filter` doesn't change order

- Like `map`, `filter` preserves relative order.
- The output is a subsequence of the input.

```ocaml
let _ = List.filter (fun x -> x > 3) [5; 1; 7; 2; 9; 3; 4]  (* = [5; 7; 9; 4] *)
```

- Elements that passed, in the order they appeared.
- Matters when filtering a sorted list or a log of timestamped events.
- Order is preserved for you.

:::

Elements that passed (`> 3`) appear in the
same order they did in the input. If the input was a sorted list,
the output is still sorted; if it was a chronologically-ordered log,
the output is still in chronological order. You do not have to
re-sort after filtering.

## `filter_map`: filter and transform in one pass

Often you want to keep *and* transform each element. A common
example: parse a list of strings into a list of integers, dropping
the strings that did not parse. With the tools we have so far:

```ocaml
let parse_ints_v1 xs =
  xs
  |> List.map int_of_string_opt    (* string list -> int option list *)
  |> List.filter Option.is_some    (* drop None *)
  |> List.map Option.get           (* unwrap Some *)
```

This works, but it walks the list three times and uses
`Option.get`, which raises an exception if it ever sees a `None`.
The code knows the `None`s are gone, but the type system does not.

The standard library function `List.filter_map` packages "keep some,
transform the kept ones" into a single primitive. The function it
takes returns an `'a option`: `None` means "drop this element,"
`Some y` means "keep `y` in the output."

```ocaml
let parse_ints xs =
  List.filter_map int_of_string_opt xs

let _ = parse_ints ["42"; "frog"; "13"; " "; "0"]  (* = [42; 13; 0] *)
```

:::slide

## `filter_map`: filter and transform together

```ocaml
let parse_ints xs =
  List.filter_map int_of_string_opt xs

let _ = parse_ints ["42"; "frog"; "13"; " "; "0"]  (* = [42; 13; 0] *)
```

- `int_of_string_opt : string -> int option`.
- `Some n` if it parses, `None` otherwise.
- `filter_map` discards `None`s and unwraps `Some`s.
- One pass, no exception risk.

:::

The result is `[42; 13; 0]`: the three strings that parsed, in
order, as raw integers. The strings `"frog"` and `" "` returned
`None` from `int_of_string_opt` and were dropped.

`filter_map` is worth knowing well. Any pipeline of "parse, drop
the failures, move on" benefits from it. Its type:

```
val filter_map : ('a -> 'b option) -> 'a list -> 'b list
```

The element type can change (`'a` to `'b`), unlike plain `filter`.
And the result length can shrink, unlike plain `map`. `filter_map`
is the most general of the three "walk a list and transform"
operations: `map` is `filter_map` where the function always returns
`Some`; `filter p` is `filter_map (fun x -> if p x then Some x else
None)`.

## `partition`: keep both halves

Sometimes you want to keep the elements that fail the predicate
*as well*. You could call `filter p` and `filter (fun x -> not (p
x))` separately, but that walks the list twice. The standard library
provides `List.partition` to do both in one pass:

```ocaml
let (passed, failed) =
  List.partition (fun n -> n >= 60) [85; 42; 73; 30; 95; 58]
```

:::slide

## `partition`: keep both halves

```ocaml
let (passed, failed) =
  List.partition (fun n -> n >= 60) [85; 42; 73; 30; 95; 58]

let _ = passed  (* = [85; 73; 95] *)
let _ = failed  (* = [42; 30; 58] *)
```

- `partition p xs` returns *two* lists: passed, then failed.
- Equivalent to `filter p` and `filter (not p)`.
- But done in a single pass.

:::

The result is a pair of lists: `passed = [85; 73; 95]`, `failed =
[42; 30; 58]`. Both lists preserve the original order. The type:

```
val partition : ('a -> bool) -> 'a list -> 'a list * 'a list
```

Use `partition` whenever you would otherwise call `filter` twice on
the same list with complementary predicates: it is a single pass and
makes the intent obvious to a reader.

## A real-world filter pipeline

Filter and map together let you express SQL-style "select fields
where condition holds" queries very compactly. Suppose we have a
list of books:

```ocaml
type book = { title : string; year : int; pages : int }

let library = [
  { title = "OCaml";   year = 2020; pages = 350 };
  { title = "Rust";    year = 2024; pages = 600 };
  { title = "Old";     year = 1985; pages = 200 };
  { title = "Recent";  year = 2023; pages = 50 };
]

let modern_long = List.filter
  (fun b -> b.year >= 2020 && b.pages > 100)
  library

let _ = List.map (fun b -> b.title) modern_long  (* = ["OCaml"; "Rust"] *)
```

:::slide

## A real-world filter pipeline

```ocaml
type book = { title : string; year : int; pages : int }
let library = [
  { title = "OCaml";  year = 2020; pages = 350 };
  { title = "Rust";   year = 2024; pages = 600 };
  { title = "Old";    year = 1985; pages = 200 };
  { title = "Recent"; year = 2023; pages = 50 };
]
let modern_long = List.filter
  (fun b -> b.year >= 2020 && b.pages > 100) library
let _ = List.map (fun b -> b.title) modern_long  (* = ["OCaml"; "Rust"] *)
```

- Filter on a compound predicate, then map to titles.
- "Select-where" in database lingo, two chained calls in OCaml.

:::

The result is `["OCaml"; "Rust"]`: those are the books from 2020 or
later with more than 100 pages.

The same query in SQL would be `SELECT title FROM library WHERE year >= 2020 AND pages > 100`.
The OCaml version is one filter plus one
map. This filter-then-map pattern (sometimes called *select-where*
in database lingo, or *project-select* in relational algebra) is
common. With `filter_map` the same thing collapses to one call:

```ocaml
let _ =
  List.filter_map
    (fun b ->
       if b.year >= 2020 && b.pages > 100 then Some b.title else None)
    library
  (* = ["OCaml"; "Rust"] *)
```

One pass instead of two; same result.

## Tail recursion and `filter`

We saw with `map` that the naive recursive implementation is not
tail-recursive. The same is true of `filter`:

```ocaml
let rec filter p = function
  | [] -> []
  | h :: t ->
      if p h then h :: filter p t
      else filter p t
```

In the "keep" branch, the cons `h :: filter p t` does work after the
recursive call. So filter sits on the stack the same way map does.

You can make it stack-safe by hand with exactly the
accumulator-and-reverse trick we showed for `map`:

```ocaml
let filter p xs =
  let rec go acc = function
    | [] -> List.rev acc
    | h :: t ->
        if p h then go (h :: acc) t
        else go acc t
  in
  go [] xs
```

The standard library does not need the trick: just as with
`List.map`, modern OCaml compiles `List.filter` with tail recursion
modulo cons, so the natural cons-onto-the-recursive-call definition
is stack-safe out of the box. For practical purposes, both versions
are fine on lists of any length you are likely to meet.

## A quick check

:::quiz mcq id=M06-L03-q3
What is the type of `List.filter (fun x -> x > 0)`?

- [ ] `int list -> int`
- [x] `int list -> int list`
- [ ] `int -> int list`
- [ ] `int -> bool`

**Why:** `List.filter` has type `('a -> bool) -> 'a list -> 'a
list`. Apply it to a predicate `int -> bool`, and you get back the
specialised type `int list -> int list`. Note the predicate is
`(>) 0`-like, and once supplied, only the list argument is left.
:::

:::quiz mcq id=M06-L03-q2
Which of these are equivalent to `List.filter p xs`?

- [x] `List.filter_map (fun x -> if p x then Some x else None) xs`
- [ ] `List.map p xs`
- [x] `fst (List.partition p xs)`
- [ ] `List.find p xs`

**Why:** the first option turns the predicate into a "return Some
x if it passes, None otherwise" function and uses `filter_map`, so
yes. The third option uses `partition` and takes the "passed" half,
also equivalent. The second option (`List.map p xs`) returns a
`bool list`, not the filtered list. The fourth option (`List.find`)
returns the *first* matching element (or raises), not the whole
sublist.
:::

A code challenge:

:::quiz code id=M06-L03-q1
We used `List.partition` above; now build it yourself. Write
`partition : ('a -> bool) -> 'a list -> 'a list * 'a list` that
returns the elements satisfying the predicate and the elements
failing it, as a pair of lists, each preserving the input order.
Do not use `List.partition` or `List.filter`; recurse directly.

```ocaml
let rec partition p xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (partition (fun n -> n mod 2 = 0) [1; 2; 3; 4; 5]
         = ([2; 4], [1; 3; 5])) "evens vs odds";
  check (partition (fun s -> String.length s > 2)
           ["a"; "abc"; "ab"; "abcd"]
         = (["abc"; "abcd"], ["a"; "ab"])) "strings";
  check (partition (fun _ -> true) [1; 2] = ([1; 2], [])) "all pass";
  check (partition (fun _ -> false) [1; 2] = ([], [1; 2])) "none pass";
  check (partition (fun n -> n > 0) ([] : int list) = ([], [])) "empty";
  print_endline "all tests passed"
```
:::

:::solution

Reference solution:

```
let rec partition p = function
  | [] -> ([], [])
  | h :: t ->
      let (yes, no) = partition p t in
      if p h then (h :: yes, no) else (yes, h :: no)
```

Partition the tail first, destructure the resulting pair with a
`let` pattern, then cons the head onto whichever half it belongs
to. Both halves come out in input order because each head is
prepended to an already-ordered tail result.

:::

## Activity

:::slide

## Activity

Write `unique : 'a list -> 'a list` that removes duplicate
elements, keeping each value's *first occurrence*. The output
should preserve the order in which elements first appear in the
input.

Hint: use the helper function `List.mem : 'a -> 'a list -> bool`
which checks if an element is in a list.

:::

:::solution

:::slide

## Activity solution

```ocaml
let unique xs =
  let rec go seen = function
    | [] -> List.rev seen
    | x :: rest ->
        if List.mem x seen then go seen rest
        else go (x :: seen) rest
  in
  go [] xs

let _ = unique [1; 2; 1; 3; 2; 4; 1]          (* = [1; 2; 3; 4] *)
let _ = unique ["a"; "b"; "a"; "c"; "b"]      (* = ["a"; "b"; "c"] *)
```

- Maintain a `seen` list (in reverse for efficiency).
- Include each element only if not already seen.
- `List.mem` is `O(n)` per call: overall `O(n^2)`.
- Fine for short lists; use a `Set` ([Module 7](M07-L08-functors.html)) for big lists.

:::

:::

## `List.mem` is not magic

We leaned on `List.mem` to check membership. It is itself a small
recursive function, the same shape we have been writing all
along:

```ocaml
let rec mem x = function
  | [] -> false
  | h :: t -> h = x || mem x t

let _ = mem 3 [1; 2; 3; 4]   (* = true *)
let _ = mem 5 [1; 2; 3; 4]   (* = false *)
```

`||` short-circuits: as soon as `h = x` is true, the rest of the
list is not traversed. Worst case (the element is missing or
last) is a full walk; that is the `O(n)` we counted toward the
overall `O(n^2)` of `unique`.

:::slide

## `List.mem` is not magic

```ocaml
let rec mem x = function
  | [] -> false
  | h :: t -> h = x || mem x t

let _ = mem 3 [1; 2; 3; 4]   (* = true *)
let _ = mem 5 [1; 2; 3; 4]   (* = false *)
```

- Walk the list; return `true` on a match.
- `||` short-circuits: stop as soon as `h = x` is true.
- `O(n)` per call (worst case: scan to the end).
- `List.mem` is the standard library's version.

:::

## Dropping the order-preserving rule

The `O(n^2)` cost above buys us one specific property: the output
keeps the original *first-appearance* order. If we relax that
property and let the output be sorted instead, we can do much
better. The trick is to sort the input first (`O(n log n)`) and
then walk it once, keeping the first of every consecutive run:

```ocaml
let unique_sorted xs =
  match List.sort compare xs with
  | [] -> []
  | y :: ys ->
      let rec go prev = function
        | [] -> [prev]
        | x :: rest ->
            if x = prev then go prev rest
            else prev :: go x rest
      in
      go y ys

let _ = unique_sorted [3; 1; 2; 1; 3; 4; 2]   (* = [1; 2; 3; 4] *)
```

`List.sort compare` is the stdlib's general-purpose sort
(`O(n log n)` worst case). After sorting, duplicates sit next to
each other, so the linear sweep `go` just skips runs of equal
values.

:::slide

## Relax the order, win the complexity

```ocaml
let unique_sorted xs =
  match List.sort compare xs with
  | [] -> []
  | y :: ys ->
      let rec go prev = function
        | [] -> [prev]
        | x :: rest ->
            if x = prev then go prev rest
            else prev :: go x rest
      in
      go y ys

let _ = unique_sorted [3; 1; 2; 1; 3; 4; 2]   (* = [1; 2; 3; 4] *)
```

- Sort first (`O(n log n)`), then one linear sweep (`O(n)`).
- Total: `O(n log n)`, beating the `O(n^2)` order-preserving version.
- Output is sorted, not in first-appearance order.
- Pick the one whose output guarantee matches your need.

:::

## What's next

We have `map` (transform every element) and `filter` (keep a
sublist). Both build new lists. The next lecture,
[`fold`](M06-L04-fold.html), builds *anything*: a number, a string,
a record, another list. It is the most general of the three, and is
the one that subsumes the other two.

:::slide

## What's next

Lecture 4: **`fold`**.

- The most general of the three.
- Both `map` and `filter` can be expressed in terms of `fold`.
- Once you grok `fold`, most list computations follow.

:::

## Reading

- **Cornell CS3110**, *Filter*:
  <https://cs3110.github.io/textbook/chapters/hop/filter.html>
- **Real World OCaml**, *Lists and patterns*:
  <https://dev.realworldocaml.org/lists-and-patterns.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
