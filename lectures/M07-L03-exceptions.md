---
title: "Exceptions"
lecture_no: 3
week: 7
youtube_id: bac4z2cj2RY
duration_target_min: 22
concepts: [raise, try-with, exception declarations, when to throw vs return option]
keywords: [OCaml, exception, raise, try, with, Failure, Not_found]
activity_question: "Write [find_first : ('a -> bool) -> 'a list -> 'a] that returns the first element matching the predicate, raising [Not_found] if none does. Then write [find_first_opt] *using* [find_first] as a wrapper, returning [None] instead of raising."
think_about_this: "Exceptions are not tracked in OCaml's type system. A function with type [int -> int] might raise anyway. What does this cost the reader? When is [result] / [option] a better fit?"
reading:
  - title: "Cornell CS3110, Exceptions"
    url: https://cs3110.github.io/textbook/chapters/data/exceptions.html
---

# Exceptions


:::slide

<div class="title-slide-inner">
<p class="title-slide-course">Functional Programming with OCaml</p>
<h2 class="title-slide-lecture">Exceptions</h2>
<p class="title-slide-label">Module 7 &middot; Lecture 3</p>
<p class="title-slide-instructor">KC Sivaramakrishnan<br>IIT Madras</p>
</div>

:::

A function's type tells you the shape of its output: `int -> int`
returns an `int`, `'a list -> int` returns the length of a list,
and so on. But what if the function is asked to compute something
that has no answer? `List.hd []` cannot return an `int`: the empty
list has no head. `1 / 0` cannot return an `int`: integer division
by zero is undefined. `int_of_string "hello"` cannot return an
`int`: the string is not a number.

We have already seen one way to express this: the
[`option` type](M04-L04-recursive-types.html#the-option-type)
(`None` when there is no answer, `Some x` when there is) and the
[`result` type](M04-L04-recursive-types.html#the-result-type)
(`Error e` instead of just `None`, so the failure can carry a
reason). Those were the subjects of
[the recursive-types lecture](M04-L04-recursive-types.html).
They are the *typed*
approach to partial functions: the possibility of failure is right
there in the return type, and the compiler will not let you forget
to handle it.

This lecture covers the other approach: *exceptions*. An exception
is a kind of value that, when *raised*, interrupts the normal flow
of evaluation and propagates up the call stack until something
catches it. Exceptions are how OCaml expresses "something went
wrong in a way the caller probably is not going to handle here,
but somebody up the call stack might want to." They are cheap at
the call site (no wrapping in `Some`, no unwrapping with `match`)
but they hide the possibility of failure from the type. We will
spend the lecture on what exceptions are, how to raise and catch
them, and the practical question of when an exception is the
right shape and when an `option` or `result` is.

:::slide

## This lecture: exceptions

- Some functions have no answer: `List.hd []`, `1 / 0`,
  `int_of_string "hello"`.
  - *Typed* approach (the recursive-types lecture): wrap failure
  in `option` or `result`.
  - *This lecture*: the other approach, *exceptions*.
- An exception interrupts evaluation and propagates up the call
  stack until something catches it.
  - Cheap at the call site; the cost is that failure is invisible
  to the type.
- Plan: what an exception is, `raise` and `try ... with`,
  defining your own, the built-in stdlib exceptions, when to
  choose exceptions vs `option` / `result`.

:::

## What is an exception?

An *exception* in OCaml is a kind of value, much like a
[variant constructor](M04-L03-variants.html). It has its own
type, `exn`. You declare a new exception with the `exception`
keyword, using exactly the syntax of a variant constructor:

```ocaml
exception Negative_input
exception Bad_index of int
exception Parse_error of string * int   (* message + offset *)
```

`Negative_input` is a nullary exception constructor, like `None`
in `option`. `Bad_index 7` is a payload-carrying value, like
`Some 7`. The standard library predefines a handful of these
(`Failure`, `Not_found`, `Division_by_zero`, ...); you can
declare your own.

What distinguishes an exception value from any other value is
what you *do* with it. The language offers two primitives:

- **`raise EXN_VAL`** signals that the exception just happened.
  Evaluation of the surrounding expression stops; the exception
  propagates *up* the call stack until something catches it. If
  nothing catches it, the program halts and prints the
  exception's name (and payload) to standard error.
- **`try EXPR with PATTERN -> HANDLER`** runs `EXPR`. If `EXPR`
  returns a value, that value is the result of the whole
  `try`-expression. If `EXPR` raises an exception that matches
  `PATTERN`, `HANDLER` is evaluated instead and *its* result is
  the result of the whole `try`. The `with` clauses are pattern
  matches against exception values.

The next two sections work through each primitive in turn.

:::slide

## What is an exception?

- A value of type `exn`, declared like a variant:

```ocaml
exception Negative_input
exception Bad_index of int
```

- Two primitives:
  - **`raise EXN_VAL`**: interrupts evaluation; propagates up
    the call stack.
  - **`try EXPR with PATTERN -> HANDLER`**: runs `EXPR`; if it
    raises an exception matching `PATTERN`, runs `HANDLER`
    instead.
- An uncaught exception halts the program.

:::

## Raising exceptions

To raise an exception, apply the primitive `raise` to an
exception value:

```ocaml
exception Negative_input

let rec factorial n =
  if n < 0 then raise Negative_input
  else if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial 5    (* = 120 *)
```

The `raise Negative_input` branch never returns;
control jumps out of `factorial` and up the call stack until
something catches the exception (we will get to catching in the
next section). If nothing does, the program halts and prints the
exception.

### The odd type of `raise`

The standard library gives `raise` the type:

```text
val raise : exn -> 'a
```

This is an unusual signature. Most OCaml functions have a
*specific* result type: `int_of_string : string -> int`,
`List.length : 'a list -> int`. `raise`'s result type is `'a`, a
type variable unconstrained by its argument. Read the signature
literally: it claims to take an `exn` and produce a value of
*any* type the caller asks for.

The reason this is sound is that `raise` *never actually returns
a value*. It transfers control to the nearest handler. The
result type can be anything because no result will ever flow
back through it. The type checker uses that latitude exactly
once: at the call site. Wherever the `raise` sits in a program,
the surrounding context expects *some* type `T`, and `'a` is
unified with `T`. That is what lets `raise Negative_input` sit
on one branch of `if n < 0 then ... else ...` opposite an `int`
branch: the `int` constrains `'a` to `int`, and the types match.
Without this polymorphism, the language would need a separate
`raise_int`, `raise_string`, `raise_bool`, and so on.

### Two convenience wrappers: `failwith` and `invalid_arg`

The standard library defines two convenience wrappers for the
most common case, where the exception you want to raise is just
"something went wrong, here's a message":

- `failwith s` is exactly `raise (Failure s)`.
- `invalid_arg s` is exactly `raise (Invalid_argument s)`.

These are not new primitives, just shorthand for `raise` applied
to one of the two stdlib-predefined exception constructors. So a
function that fails on the empty list can be written:

```ocaml
let head = function
  | [] -> failwith "head of empty list"
  | x :: _ -> x

let _ = head [1; 2; 3]    (* = 1 *)
```

The `failwith` arm expands to
`raise (Failure "head of empty list")`. The expanded form makes
the construction explicit: an exception value is a constructor
applied to its payload, exactly like `Some 3` is `Some` applied
to `3`.

:::slide

## Raising an exception

```ocaml
exception Negative_input

let rec factorial n =
  if n < 0 then raise Negative_input
  else if n = 0 then 1
  else n * factorial (n - 1)

let _ = factorial 5    (* = 120 *)
```

- `raise EXN_VAL` interrupts evaluation; propagates up the stack.
- `raise : exn -> 'a`
  - result type is polymorphic!
  - `raise` can sit opposite any other-typed branch.

:::

:::slide

## `failwith` and `invalid_arg`: shorthand, not magic

```ocaml
let head = function
  | [] -> failwith "head of empty list"
  | x :: _ -> x

let _ = head [1; 2; 3]    (* = 1 *)
```

- `failwith s` is `raise (Failure s)`.
- `invalid_arg s` is `raise (Invalid_argument s)`.
- Use the wrappers when the failure is a plain string message;
  declare a custom `exception` (like `Negative_input` above) when
  callers will want to *catch* it specifically.

:::

## Catching exceptions: `try ... with`

`try ... with` is an *expression*, like
[`if`](M02-L05-if-expressions.html) and
[`match`](M05-L01-basic-patterns.html). It produces a value, and
that value can be used wherever a value of its type is expected.
The general shape is:

```text
try
  EXPR
with
| PATTERN_1 -> HANDLER_1
| PATTERN_2 -> HANDLER_2
| ...
| PATTERN_N -> HANDLER_N
```

Evaluation order:

1.  Evaluate `EXPR`. If it returns a value, that value is the
    result of the whole `try`. The handlers are not visited.
2.  If `EXPR` raises an exception, the exception value is
    matched against `PATTERN_1`, `PATTERN_2`, ... in order. The
    first matching clause's `HANDLER_i` is evaluated and its
    result is the result of the whole `try`.
3.  If no `PATTERN_i` matches, the exception keeps propagating
    up the call stack. The `try` does not consume it.

The `with` clauses are real
[patterns](M05-L01-basic-patterns.html): they match on the
exception constructor, can bind the payload, and can use
[or-patterns](M05-L03-nested-and-or-patterns.html#or-patterns)
and the wildcard `_`.

### The type rule

Because `try ... with` is one expression, OCaml needs to give
*the whole thing* a single type. The rule is what you would
expect by analogy with `if` and `match`:

- `EXPR` has some type `T`.
- Every `HANDLER_i` must also have type `T`.

Then the whole `try` expression has type `T`. If any handler
returns a different type, the compiler rejects the whole `try`.

### A first example

```ocaml
let safe_head xs =
  try Some (List.hd xs)
  with Failure _ -> None

let _ = safe_head [1; 2; 3]   (* = Some 1 *)
let _ = safe_head []          (* = None *)
```

`List.hd` raises `Failure "hd"` on the empty list; the `with`
clause catches `Failure _` (the wildcard `_` ignores the
message) and produces `None`. Both `Some (List.hd xs)` and
`None` have type `int option`, so the whole `try` has type
`int option`.

### Multiple exception patterns

The `with` clause can list several patterns separated by `|`,
one per exception you want to handle:

```ocaml
let safely f x =
  try Ok (f x)
  with
  | Failure msg          -> Error ("failure: " ^ msg)
  | Invalid_argument msg -> Error ("invalid: " ^ msg)
  | Division_by_zero     -> Error "div by zero"

let _ = safely (fun n -> 100 / n) 4   (* = Ok 25 *)
let _ = safely (fun n -> 100 / n) 0   (* = Error "div by zero" *)
```

Each
clause has the same type as `Ok (f x)`, namely
`(int, string) result`, so the whole `try` is well-typed at that
type. Exceptions not listed (e.g., `Stack_overflow`) keep
propagating up; the `try` does not silently swallow them.

A wildcard `| _ -> ...` at the end would catch *every* exception,
but this is almost always a mistake: it hides bugs that would
otherwise surface as a crash. Catch specific exceptions; let
unexpected ones propagate.

### Nested `try ... with`

A `try` is just an expression, so you can nest one inside the
body of another. The general rule is unchanged: when an exception
is raised, it is matched against the *nearest enclosing* `try`'s
patterns first; only if that `try` does not match does the
exception keep propagating outward.

```ocaml
let parse_and_divide sa sb =
  try
    let a = try int_of_string sa with Failure _ -> 0 in
    let b = int_of_string sb in
    a / b
  with
  | Failure _ -> -1
  | Division_by_zero -> -2

let _ = parse_and_divide "10" "2"      (* =  5 *)
let _ = parse_and_divide "oops" "2"    (* =  0 *)
let _ = parse_and_divide "10" "oops"   (* = -1 *)
let _ = parse_and_divide "10" "0"      (* = -2 *)
```

- `parse_and_divide "10" "2"` returns `5`: both parses succeed,
  `10 / 2 = 5`.
- `parse_and_divide "oops" "2"` returns `0`: parsing `sa` raises
  `Failure "int_of_string"`, the *inner* `try` is the nearest
  enclosing one, it matches `Failure _` and substitutes `0` for
  `a`. The outer `try` never gets a chance.
- `parse_and_divide "10" "oops"` returns `-1`: parsing `sa`
  succeeds, so the inner `try` finishes normally. Parsing `sb`
  raises `Failure`, but now the inner `try` is no longer on the
  call stack. The exception propagates to the outer `try`, which
  matches `Failure _` and returns `-1`.
- `parse_and_divide "10" "0"` returns `-2`: both parses succeed,
  but `10 / 0` raises `Division_by_zero`. The inner `try` is
  long gone; the outer catches and returns `-2`.

The mental model is the same as with `try` and an unmatched
clause: an exception walks *up* the call stack, visiting each
`try` it meets in turn, taking the first matching clause it
finds. Nesting just makes the "nearest" relationship explicit.

:::slide

## Catching: `try ... with`

```text
try
  EXPR
with
| PATTERN_1 -> HANDLER_1
| ...
| PATTERN_N -> HANDLER_N
```

- `try ... with` is an **expression**: it produces a value.
- Run `EXPR`. If it returns, that's the result. If it raises an
  exception, match against the patterns and run the matching
  handler.
- Unmatched exceptions keep propagating; the `try` does **not**
  swallow them.
- Type rule: `EXPR` and every `HANDLER_i` must all have the
  *same* type; the `try` has that type.

:::

:::slide

## A first example: catching `Failure`

```ocaml
let safe_head xs =
  try Some (List.hd xs)
  with Failure _ -> None

let _ = safe_head [1; 2; 3]   (* = Some 1 *)
let _ = safe_head []          (* = None *)
```

- `List.hd []` raises `Failure "hd"`; the handler catches and
  returns `None`.
- Both `Some (...)` and `None` are `int option`, so the `try` is
  `int option`.

:::

:::slide

## Multiple exception patterns

```ocaml
let safely f x =
  try Ok (f x)
  with
  | Failure msg          -> Error ("failure: " ^ msg)
  | Invalid_argument msg -> Error ("invalid: " ^ msg)
  | Division_by_zero     -> Error "div by zero"

let _ = safely (fun n -> 100 / n) 4    (* = Ok 25 *)
let _ = safely (fun n -> 100 / n) 0    (* = Error "div by zero" *)
```

- `|` separates clauses, just like a `match`.
- Every clause has type `(int, string) result`; so does
  `Ok (f x)`; so does the whole `try`.
- Exceptions not listed keep propagating. Don't write a
  catch-all `_ -> ...`; you will swallow bugs.

:::

:::slide

## Nested `try ... with`: nearest enclosing wins

```ocaml
let parse_and_divide sa sb =
  try
    let a = try int_of_string sa with Failure _ -> 0 in
    let b = int_of_string sb in
    a / b
  with
  | Failure _ -> -1
  | Division_by_zero -> -2

let _ = parse_and_divide "10"   "2"       (* =  5 *)
let _ = parse_and_divide "oops" "2"       (* =  0: inner caught   *)
let _ = parse_and_divide "10"   "oops"    (* = -1: outer caught   *)
let _ = parse_and_divide "10"   "0"       (* = -2: outer caught   *)
```

- A raised exception walks up the call stack, taking the
  *first matching* `try` it meets.
- The inner `try` only sees what is raised inside its body; once
  it finishes, later exceptions bypass it.

:::

## Built-in exceptions

The standard library predefines a handful of exception
constructors that show up routinely in OCaml code. Now that you
know `raise` and `try ... with`, here is the tour:

- `Failure of string` is raised by `failwith "..."`. It signals
  "the function was called in a way the documentation forbids."
- `Invalid_argument of string` is raised by `invalid_arg "..."`.
  Used for outright invalid inputs: `String.get s i` with `i`
  out of range, for instance.
- `Not_found` is raised by lookup functions when the key is
  absent. `List.assoc`, `Hashtbl.find`, and many others raise it.
- `Division_by_zero` is raised by `/` and `mod` on integer zero.
- `End_of_file` is raised by reading-from-channel functions when
  they hit the end of input.
- `Assert_failure of (string * int * int)` is raised by the
  built-in `assert` keyword when its condition is false. The
  payload is `(file, line, column)` of the failing assertion,
  filled in automatically by the compiler.

The last one needs a closer look because `assert` is a syntactic
form, not a function:

```ocaml
let halve x =
  assert (x mod 2 = 0);
  x / 2

let _ = halve 10   (* = 5 *)
```

If the precondition holds, `assert` returns `()` and
evaluation continues. If it fails, `assert` raises
`Assert_failure (file, line, column)` pointing at the failing
line. The special form `assert false` is an idiom: it always
raises and has the polymorphic type `'a`, so you can use it
anywhere to mark a code path as unreachable. Use this when the
type system can't see that a case is impossible (a partial
`match` you have manually checked, for instance).

There are a handful more stdlib exceptions; the
[OCaml stdlib documentation](https://v2.ocaml.org/api/Stdlib.html)
lists them under "Predefined exceptions." In practice the six
above account for most of the try ... with clauses you
will see in idiomatic code.

:::slide

## Built-in exceptions

Common stdlib exceptions you will catch:

- `Failure of string`: from `failwith "..."`.
- `Invalid_argument of string`: from `invalid_arg "..."`.
- `Not_found`: lookups when the key is absent.
- `Division_by_zero`: `/` and `mod` on `0`.
- `End_of_file`: reading past the end of input.
- `Assert_failure (file, line, col)`: from the `assert` keyword.

```ocaml
(* List.hd [] raises Failure "hd"; the handler catches it *)
let _ = try List.hd [] with Failure _ -> 0   (* = 0 *)
```

:::

:::slide

## `assert`: precondition + "can't happen"

```ocaml
let halve x =
  assert (x mod 2 = 0);
  x / 2

let _ = halve 10        (* = 5 *)
```

- `assert COND`: if `COND` is true, returns `()`; if false,
  raises `Assert_failure (file, line, col)`.
- `assert false` always raises; its type is polymorphic (`'a`),
  so use it to mark unreachable code the type system can't see
  is impossible.

:::

## Custom exceptions with a payload

We have already seen a nullary custom exception
(`exception Negative_input`) in the Raising section. Custom
exceptions can also *carry a payload*, declared with the `of`
keyword the same way as a
[variant constructor with arguments](M04-L03-variants.html):

```ocaml
exception Parse_error of string * int  (* message, line number *)

let parse_int_field s =
  try int_of_string s
  with Failure _ ->
    raise (Parse_error ("not an int: " ^ s, 7))

let _ =                       (* = 42, prints nothing *)
  try parse_int_field "42"
  with Parse_error (msg, line) ->
    Printf.printf "line %d: %s\n" line msg;
    0

let _ =                       (* = 0, prints "line 7: ..." *)
  try parse_int_field "oops"
  with Parse_error (msg, line) ->
    Printf.printf "line %d: %s\n" line msg;
    0
```

The first call returns `42` and prints nothing. The second
re-raises a `Parse_error` (with a message and line number), the
handler catches and binds the payload, prints "line 7: not an
int: oops", and returns `0`. The handler pattern
`Parse_error (msg, line)` binds the constructor's payload
exactly as a variant pattern would.

### Extensible variants: a brief aside

Internally, all exception constructors share a single type,
`exn`. Every `exception` declaration adds a new constructor to
*that* type. This is unusual: most
[OCaml variants](M04-L03-variants.html) are *closed* (the set of
constructors is fixed at the declaration). `exn` is one of the
few *extensible* variants in the language, because libraries
throughout a program need to add their own exception
constructors.

The desugaring is visible if you ask for it. `exception NAME of
...` is exactly `type exn += NAME of ...`:

```ocaml
(* the sugar we have been using *)
exception My_error of string

(* the desugared form: extend an existing extensible variant *)
type exn += My_other_error of string

(* both flow through raise / try ... with identically *)
let _ =
  try raise (My_error "via the sugar")
  with My_error s -> s          (* = "via the sugar" *)

let _ =
  try raise (My_other_error "via type exn +=")
  with My_other_error s -> s    (* = "via type exn +=" *)
```

The `+=` form makes the
extension explicit; the `exception` keyword is the
exception-flavoured shorthand. We will not need to write `type
exn +=` ourselves in this course, but seeing it once explains
the bullet "exceptions are extensible variants" in concrete
terms.

:::slide

## Custom exceptions with a payload

```ocaml
exception Parse_error of string * int

let parse_int_field s =
  try int_of_string s
  with Failure _ ->
    raise (Parse_error ("not an int: " ^ s, 7))

let _ =                       (* = 0, prints "line 7: ..." *)
  try parse_int_field "oops"
  with Parse_error (msg, line) ->
    Printf.printf "line %d: %s\n" line msg;
    0
```

- `exception NAME of TYPE`: declare with a payload.
- `raise (NAME payload)`: build the constructor and raise it.
- `| NAME pat -> ...`: catch and bind the payload, like a
  variant pattern.

:::

:::slide

## Aside: exceptions are extensible variants

```ocaml
(* sugar *)
exception My_error of string

(* desugared: extend the open exn type *)
type exn += My_other_error of string

let _ = try raise (My_error "a")
        with My_error s -> s          (* = "a" *)
let _ = try raise (My_other_error "b")
        with My_other_error s -> s    (* = "b" *)
```

- All exception constructors share one type: `exn`.
- `exception NAME` is shorthand for `type exn += NAME`.
- Unusual: most OCaml variants are *closed*; `exn` is the
  textbook *open* (extensible) variant.

:::

## Exception vs option vs result

The three shapes for "this might fail," shown on the same tiny
lookup over an association list:

```ocaml
let table = [("a", 10); ("b", 20); ("c", 30)]

let find_x key = List.assoc key table
let find_x_opt key = List.assoc_opt key table
let find_x_result key =
  match List.assoc_opt key table with
  | Some v -> Ok v
  | None   -> Error ("no such key: " ^ key)
```

The toplevel reports:

```text
val find_x        : string -> int                          = <fun>
val find_x_opt    : string -> int option                   = <fun>
val find_x_result : string -> (int, string) result         = <fun>
```

Same lookup, three signatures. A few calls to feel the
difference at the call site:

```ocaml
let _ = find_x "b"          (* = 20 *)
let _ = find_x_opt "b"      (* = Some 20 *)
let _ = find_x_opt "z"      (* = None *)
let _ = find_x_result "z"   (* = Error "no such key: z" *)
```

The fourth combination is the interesting one. `find_x "z"` has no
`int` to return, so it raises. Internally `List.assoc` walks the
list exactly as `List.assoc_opt` does; the two differ only in how
they report a miss: `assoc` raises `Not_found` where `assoc_opt`
returns `None`.

```ocaml skip
let _ = find_x "z"   (* raises Not_found *)
```

**Raise.** Cheapest at the call site: the caller writes
`let x = find_x "key"` and uses `x` directly. The cost is that
the *type* says nothing about failure. A reader of the type
cannot tell whether the function might raise. The compiler will
not warn a caller that forgot to handle the failure.

**Option.** The failure is in the type. The caller is forced to
pattern-match on `Some` and `None`. The cost is two things:
every call site is slightly more code, and the failure carries
no information (`None` is just "no value here," with no reason).

**Result.** The same as option, but the failure side has a
payload: an error message, an error code, a structured error
variant. Best when the caller might want to log or recover based
on what went wrong.

:::slide

## Exception vs `option` vs `result`

```ocaml
let table = [("a", 10); ("b", 20); ("c", 30)]

let find_x key = List.assoc key table
let find_x_opt key = List.assoc_opt key table
let find_x_result key =
  match List.assoc_opt key table with
  | Some v -> Ok v
  | None   -> Error ("no such key: " ^ key)
```

- **Raise** (`find_x : string -> int`): cheap at the call site;
  failure invisible in the type.
- **Option** (`find_x_opt : string -> int option`): failure in
  the type; no reason carried.
- **Result** (`find_x_result : string -> (int, string) result`):
  failure in the type, with a payload.
- Stdlib offers both raising and `_opt` forms; prefer `_opt` in
  new code.

:::

The OCaml standard library follows a clear convention: any
function that raises an exception on failure comes in a paired
form that returns `option`, with the suffix `_opt`. So
`List.find` raises `Not_found`; `List.find_opt` returns `None`.
`List.assoc` raises `Not_found`; `List.assoc_opt` returns `None`.
`Hashtbl.find` raises; `Hashtbl.find_opt` returns. The convention
extends to types: the raising form usually exists for historical
reasons, and the `_opt` form is the one to prefer in new code.

Why two forms? The raising form is older; the `_opt` form was
added as OCaml moved toward making partial failures visible in
the type system. The library keeps both for backward compatibility,
but the social convention is clear: new code uses `_opt`.

The naming `_opt` suffix is the OCaml convention; expect to see
it everywhere.

## When not to use exceptions

A short list of cases where reaching for an exception is the
wrong call.

**For predictable missing values.** "The key might be missing from
the map" is not an exceptional case, it is the expected behaviour
of a lookup. Use [`option`](M04-L04-recursive-types.html#the-option-type);
the caller will pattern-match cleanly.

**For "this can't happen" assertions.** If a code path is
unreachable, write `assert false` or, better, restructure the
types so the unreachable case is genuinely impossible (a
[variant](M04-L03-variants.html) without that constructor).
Exceptions are not a substitute for type-driven design.

**For deeply nested control flow.** An exception raised three
levels deep, caught at the top, can be hard to follow when you
read the code. Each `try` introduces a place where execution can
jump; a function with many `try`s scattered through it is hard to
reason about.

The genuine sweet spot for exceptions: *unexpected, rare
failures* that callers usually do not handle locally. Parse
failures in a parser used inside a larger pipeline, file-system
errors that propagate to the top of a CLI, that kind of thing.
The convention here matches the convention in Python and Java:
exceptions for things that "should not normally happen."

:::slide

## When *not* to use exceptions

**Avoid for:**

- Predictable "missing value" cases: use `option`.
- "This won't happen" assertions: use `assert false`, or redesign.
- Deep nesting where the escape path is hard to follow.

**Good fit:**

- *Unexpected, rare* failures (parse failed, file not found)
  where error-handling code would otherwise pollute every step.

:::

## A quick check

:::quiz mcq id=M07-L03-q3
What is the type of `raise (Failure "oops")`?

- [ ] `unit`
- [ ] `exn`
- [x] `'a`
- [ ] `Failure`

**Why:** `raise` has type `exn -> 'a`. Its return type is
polymorphic because a `raise` never produces a normal value; it
can stand in any type-checking context. The exception value
itself (`Failure "oops"`) has type `exn`, but the *raise
expression* has type `'a`.
:::

:::quiz mcq id=M07-L03-q2
What does this evaluate to?

```ocaml
try
  let _ = List.hd [] in
  "no exception"
with
  | Not_found -> "not found"
  | Failure _ -> "failure"
```

- [ ] `"no exception"`
- [ ] `"not found"`
- [x] `"failure"`
- [ ] runtime crash

**Why:** `List.hd []` raises `Failure "hd"`. The `Failure _`
handler matches and returns `"failure"`. The `Not_found` clause
does not match (different exception); the body never finishes.
:::

## Activity

:::slide

## Activity

Write `find_first : ('a -> bool) -> 'a list -> 'a` that returns
the first element matching the predicate, raising `Not_found` if
none does. Then write `find_first_opt` *using* `find_first` as a
wrapper, returning `None` instead of raising.

:::

:::quiz code id=M07-L03-q1
Write `find_first` raising `Not_found`, then write
`find_first_opt` as a wrapper that *calls* `find_first` and
catches `Not_found`.

```ocaml
let rec find_first p xs =
  failwith "not implemented"

let find_first_opt p xs =
  failwith "not implemented"
```

```ocaml skip
let check b m = if not b then failwith m
let () =
  check (find_first (fun n -> n > 5) [1; 7; 3] = 7) "found";
  (match (try Some (find_first (fun _ -> false) [1; 2]) with Not_found -> None) with
   | None -> ()
   | Some _ -> failwith "expected Not_found");
  check (find_first_opt (fun n -> n > 5) [1; 7; 3] = Some 7) "opt found";
  check (find_first_opt (fun n -> n > 100) [1; 2; 3] = None) "opt missing";
  check (find_first_opt (fun _ -> false) [] = None) "opt empty";
  print_endline "all tests passed"
```
:::

:::solution

:::slide

## Activity solution

```ocaml
let rec find_first p = function
  | [] -> raise Not_found
  | x :: rest -> if p x then x else find_first p rest

let find_first_opt p xs =
  try Some (find_first p xs)
  with Not_found -> None

let _ = find_first_opt (fun n -> n > 5) [1; 7; 3]     (* = Some 7 *)
let _ = find_first_opt (fun n -> n > 100) [1; 2; 3]   (* = None *)
```

- `find_first_opt` is the **safe wrapper**: catches the exception
  and turns it into an `option`.
- Standard pattern when you want to expose both APIs.
- The stdlib's `List.find` and `List.find_opt` are exactly this
  pair.

:::

:::

The `find_first_opt` definition is the standard pattern for
turning a raising function into an optional one: wrap the call in
a `try`, and convert the exception into `None`. This is exactly
how the standard library's `_opt` forms are typically defined.
You can also go the other way (a raising version from an optional
version) with a `match`:

```text
let find_first p xs =
  match find_first_opt p xs with
  | Some x -> x
  | None -> raise Not_found
```

Either direction works; pick the one whose implementation is
easier to read for your case.

## What's next

That closes this module's imperative trio. The
[next two lectures](M07-L04-streams-and-laziness.html) take a
small detour: *streams* (infinite data structures, built using
thunks and refs from this module) and *memoization* (caching
function results, again using a ref to hold the cache). Then
the [last three lectures](M07-L06-module-basics.html) turn to
*modules*: how OCaml structures code at scale, namespaces large
libraries, and hides representation behind type signatures. The
standard library you have been using all course (`List`,
`Array`, `String`, `Option`) is a tree of modules; we finally
meet the machinery that builds it.

:::slide

## What's next

Lecture 4: **streams and laziness**.

- Recursive values and infinite data structures.
- Streams: pausing evaluation with thunks; lazy values; lazy
  streams.
- Higher-order ops on streams; primes by the Sieve of
  Eratosthenes; Fibonacci as a stream.

:::

## Reading

- **Cornell CS3110**, *Exceptions*:
  <https://cs3110.github.io/textbook/chapters/data/exceptions.html>
- **Real World OCaml**, *Error Handling*:
  <https://dev.realworldocaml.org/error-handling.html>
## Sources

This lecture's prose, worked examples, and quizzes are original to
this course. Materials referenced during preparation are listed in
the *Reading* section above; Cornell CS3110 and Real World OCaml
are CC BY-NC-ND-licensed and have not been derivatively reused.
See [`LICENSES.md`](https://github.com/fplaunchpad/ocaml_nptel/blob/main/LICENSES.md)
at the repository root for the full source posture.
