# functional.cr

Functional programming toolkit for Crystal, built with macros.
Multi-clause pattern-matching functions, a zero-allocation Result type,
threading pipelines, proc helpers.

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  functional:
    github: your-github/functional.cr
```

2. Run `shards install`
3. `require "functional"`

## deff — multi-clause functions

Elixir-style functions that dispatch on argument **values**, not just types:

```crystal
deff :fact do
  fn(0) { 1 }
  fn(n) { n * fact(n - 1) }
end

deff :gcd do
  fn(a, 0) { a }
  fn(a, b) { gcd(b, a % b) }
end

deff :http_status do
  fn(200) { "OK" }
  fn(404) { "Not Found" }
  fn(Int32) { "Other" }    # type pattern -> is_a?
  fn(_)     { "invalid" }  # wildcard
end

fact(5)     # => 120
gcd(48, 18) # => 6
```

Clauses are tried top to bottom; the first match wins. Patterns:

| Pattern      | Meaning                             |
|--------------|-------------------------------------|
| `42`, `"hi"` | equality (`==`)                     |
| `Int32`      | type check (`is_a?`)                |
| `n`          | binds the argument to `n`           |
| `_`          | wildcard, always matches            |

Guards, spelled `when:` (Elixir `when`):

```crystal
deff :sign do
  fn(x, when: x < 0) { -1 }
  fn(0) { 0 }
  fn(_) { 1 }
end
```

If no clause matches, `Functional::MatchError` is raised at runtime.
Arity mismatches between clauses are caught at compile time, during macro
expansion. Dispatch itself is runtime (a chain of `if`s) — Crystal's method
overloading works on types, not values.

Exhaustiveness hint: when no clause is an unconditional catch-all (every
pattern a binder or `_`, **no guard** — a guard can reject), the compiler
prints a warning at macro expansion time. It's a hint, not an error: a
`deff` that intentionally raises on out-of-domain input is a legitimate
style.

```console
functional: deff :http_status has no catch-all clause (fn(_) or a plain
binder, without a guard) — unmatched arguments raise Functional::MatchError
at runtime
```

## Why and where: guards at the C boundary

The best place for `deff` + guards is **wrapping C bindings**. C functions
are the most dangerous layer of a Crystal program:

- inside C there are **no exceptions**. A bad argument becomes a hardware
  fault — division by zero raises `SIGFPE`, a bad pointer raises `SIGSEGV` —
  and the **whole process dies**;
- no `rescue` can help: the crash is a signal, not a Crystal exception, so
  it happens before the runtime has any say;
- Crystal itself already protects its own arithmetic (`10 / 0` raises
  `DivisionByZeroError`), but a `fun` call hands the argument to C verbatim.
  The last checkpoint is the Crystal side of the FFI boundary.

Guards put that checkpoint exactly there: validate arguments with `when:`
clauses **before** they cross into C, and turn invalid input into an
ordinary, rescuable `Functional::MatchError`:

```crystal
lib MathLib
  fun div = mg_div(a : Int32, b : Int32) : Int32
end

deff :safe_div do
  fn(a, b, when: b != 0) { MathLib.div(a, b) }   # only sound args reach C
  fn(_, _) { raise Functional::MatchError.new("division by zero") }
end

safe_div(10, 0) # => MatchError — rescuable, loggable, process alive
```

A runnable demo with both versions — one crashing on `SIGFPE`, one
surviving every bad argument — lives in
[`examples/c_guards`](examples/c_guards):

```console
$ make demo
=== WITHOUT guards ===
computing 10 / 0 ...
Floating point exception (core dumped)     # exit code 136, program dead

=== WITH guards ===
10 / 0 = rejected by guard: safe_div: division by zero
done — the program survived every bad argument   # exit code 0
```

The same pattern applies to any C library: `libgit2`, `openssl`, audio and
video codecs — wherever a wrong argument in Crystal means a crash in C.

## Result — {:ok, value} / {:error, reason}

Elixir-style tagged results, with the tag checked by the compiler instead
of matched at runtime. `ok(v)` / `err(reason)` construct, native `case`
consumes:

```crystal
def parse_int(s)                          # inferred: Ok(Int32) | Err(String)
  v = s.to_i?
  v ? ok(v) : err("not a number: #{s}")
end

res = parse_int(input)
case res                                  # ≈ case ... do
when Ok  then puts "ok: #{res.value}"     #   {:ok, result} -> ...
when Err then puts "err: #{res.error}"    #   {:error, reason} -> ...
end
```

A `case` over `Ok | Err` is exhaustive **at compile time**: forget the
`when Err` branch and the value's type widens with `Nil`, which the
compiler flags at the first use — Elixir would raise `CaseClauseError`
only at runtime. For value-specific clauses, combine with `deff`:

```crystal
deff :show do
  fn(r, when: r.is_a?(Ok) && r.value == 0) { "ok, but zero" }  # ≈ {:ok, 0}
  fn(r, when: r.is_a?(Ok)) { "ok: #{r.value}" }
  fn(r, when: r.is_a?(Err)) { "err: #{r.error}" }
end
```

Happy-path chaining — the chain short-circuits on the first error, the
skipped blocks never run:

```crystal
parse_int("42")
  .and_then { |v| v.even? ? ok(v // 2) : err("odd: #{v}") }
  .map      { |v| v + 1 }
  .unwrap_or(-1)   # => 22

parse_int("x")
  .map { |v| v * 2 }
  .unwrap_or(0)    # => 0, the block never ran
```

Predicates and nilable accessors: `ok?`, `err?`, `value?`, `error?`.

Both variants are **structs** and combinators use `yield`, so wrapping is
free: an exception costs ~432 bytes of GC work per `raise`, `Ok`/`Err`
cost nothing. Use exceptions for the truly exceptional, `Result` where a
failure is a normal, expected outcome: parsing user input, cache lookups,
validations — and as the return type of guard-wrapped C bindings instead
of `raise`.

## pipe — threading pipeline

Elixir's `|>` semantics: the threaded value is inserted as the **first
argument** of the next call. Flattens nested free-function calls. Write it
multi-line by default — one step per line, like an Elixir pipeline:

```crystal
# instead of: format_label(get_address(get_user(id)))
label = pipe id,
  get_user,
  get_address,
  format_label

result = pipe "  Hi  ",
  Str.trim,
  Str.downcase,
  Str.codepoints

pipe 15,
  clamp(0, 10)   # => clamp(15, 0, 10)

pipe 9, Math.sqrt
```

Step forms: `f(a)` → `f(value, a)` (free function), `Mod.m(a)` →
`Mod.m(value, a)` (namespaced function), a proc literal or a local proc
variable → called with the value.

For method chaining on the value itself, plain `.` is already idiomatic
Crystal — `pipe` exists for the nested-call case, exactly like `|>` in Elixir.

## Functional — proc helpers

```crystal
f = ->(x : Int32) { x + 1 }
g = ->(x : Int32) { x * 2 }

Functional.compose(f, g).call(3)  # g(f(3)) => 8
Functional.pipe(f, g).call(3)     # same, pipeline reading order
Functional.curry(add).call(2).call(3)  # currying
Functional.identity(x)                 # id
```

## Roadmap ideas

- destructuring patterns in `deff` clauses (`fn({a, b}) { ... }`)

## License

MIT
