# functional.cr

Functional programming toolkit for Crystal, built with macros.
Multi-clause pattern-matching functions, threading pipelines, proc helpers.

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

## pipe — threading pipeline

Elixir's `|>`, expanding to chained method calls at compile time:

```crystal
pipe "1,2,3", split(","), map(&.to_i), sum   # => 6
pipe "  hi  ", strip, upcase                 # => "HI"
```

A step is a method call (receiver becomes the threaded value; args and
blocks are kept), a proc literal, or a local variable holding a proc:

```crystal
double = ->(x : Int32) { x * 2 }
pipe 5, double, inc        # procs are called with the threaded value
```

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

- `defmemo` — memoized pure functions
- destructuring patterns in `deff` clauses (`fn({a, b}) { ... }`)
- `Result`/`Either` with happy-path piping
- compile-time exhaustiveness hints when the last clause is not a catch-all

## License

MIT
