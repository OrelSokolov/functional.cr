# Elixir-style multi-clause functions with pattern matching on argument values.
#
#   deff :fact do
#     fn(0) { 1 }
#     fn(n) { n * fact(n - 1) }
#   end
#
# Clauses are tried top to bottom; the first match wins. Supported patterns:
#   - literal      -> equality check (==)
#   - type (Path)  -> is_a? check (e.g. Int32, String, MyType)
#   - identifier   -> binds the argument to that name
#   - `_`          -> wildcard
#   - tuple        -> destructuring: `{a, 0}`, `{Int32, b}`; nest with a
#                     space after `{`: `{ {x, y}, rest }` (otherwise `{{`
#                     is read as a macro interpolation)
#   - array        -> destructuring: `[a, b]`
#   - named tuple  -> destructuring by key: `{name: n, age: 0}`
#
# Every element/key position inside a destructuring pattern is a full
# pattern itself, so patterns nest arbitrarily.
#
# A clause may carry a guard: `fn(n, when: n > 0) { ... }`.
# When no clause matches at runtime, Functional::MatchError is raised.
#
# Note: destructured positions are indexed at compile time, so a deff'd
# argument must narrow to one shape — mixing tuples of different sizes (or
# named tuples with different key sets) in calls to the same deff is a
# compile error, not a runtime mismatch.

class Functional::MatchError < Exception
end

# :nodoc:
# Emits `return false unless ...` statements for one pattern node, for use
# inside the check helpers defined by `__deff_check_helper`. Recursive:
# the macro calls emitted for sub-patterns expand in place, and that is
# how nested paths like `v[1][0]` get built by the parser.
macro __deff_check_stmts(pat, path)
  {% if pat.is_a?(TupleLiteral) || pat.is_a?(ArrayLiteral) %}
    {% type = pat.is_a?(ArrayLiteral) ? "Array" : "Tuple" %}
    return false unless {{path}}.is_a?({{type.id}}) && {{path}}.size == {{pat.size}}
    {% for i in 0...pat.size %}
      __deff_check_stmts({{pat[i]}}, {{path}}[{{i}}])
    {% end %}
  {% elsif pat.is_a?(NamedTupleLiteral) %}
    return false unless {{path}}.is_a?(NamedTuple) && {{path}}.keys.size == {{pat.to_a.size}}
    {% for pair in pat.to_a %}
      __deff_check_stmts({{pair[1]}}, {{path}}[:{{pair[0]}}])
    {% end %}
  {% elsif pat.is_a?(Path) %}
    return false unless {{path}}.is_a?({{pat}})
  {% elsif pat.is_a?(Var) || pat.is_a?(Underscore) || (pat.is_a?(Call) && pat.args.empty?) %}
    # binder or `_`: always matches
  {% elsif pat.is_a?(Call) %}
    {% raise "unsupported pattern #{pat}: literal, Type, binder, or tuple/array/named-tuple destructuring" %}
  {% else %}
    return false unless {{path}} == {{pat}}
  {% end %}
end

# :nodoc:
# Defines a check helper `<name>(v)` returning whether v matches `pat`.
# Kept as a method (not inline ifs) because the recursive statement
# emission above only works through nested macro calls.
macro __deff_check_helper(name, pat)
  def {{name.id}}(v)
    __deff_check_stmts({{pat}}, v)
    true
  end
end

# :nodoc:
# Binding is chained through `{{yield}}` continuations instead of plain
# generated statements, because Crystal locals assigned inside one macro
# expansion are invisible to a later sibling expansion — only code yielded
# *into* the same expansion chain can see them.

# :nodoc:
# Binds one pattern node against `path`, then runs the block. A
# destructured node is narrowed through a temporary `tmp` + `is_a?`
# (always true here: only reached after its check helper succeeded,
# but the shape check happened in another method, so the compiler
# can't see it).
macro __deff_bind_one(pat, path, tmp, &)
  {% if pat.is_a?(TupleLiteral) || pat.is_a?(ArrayLiteral) %}
    {% type = pat.is_a?(ArrayLiteral) ? "Array" : "Tuple" %}
    {{tmp.id}} = {{path}}
    if {{tmp.id}}.is_a?({{type.id}})
      __deff_bind_seq({{pat}}, {{tmp}}, 0, {{tmp}}) do
        {{yield}}
      end
    end
  {% elsif pat.is_a?(NamedTupleLiteral) %}
    {{tmp.id}} = {{path}}
    if {{tmp.id}}.is_a?(NamedTuple)
      __deff_bind_ntseq({{pat}}, {{tmp}}, 0, {{tmp}}) do
        {{yield}}
      end
    end
  {% else %}
    {% if pat.is_a?(Var) || pat.is_a?(Underscore) || (pat.is_a?(Call) && pat.args.empty?) %}
      {% unless pat.id == "_" %}
        {{pat}} = {{path}}
      {% end %}
    {% end %}
    {{yield}}
  {% end %}
end

# :nodoc:
# Walks the elements of a tuple/array pattern left to right, then runs
# the block. `v` is the already-cast container, `tmp` the prefix for its
# children's temporaries.
macro __deff_bind_seq(pat, v, idx, tmp, &)
  {% if idx >= pat.size %}
    {{yield}}
  {% else %}
    {% sub = "#{tmp.id}_#{idx}".id %}
    __deff_bind_one({{pat[idx]}}, {{v}}[{{idx}}], {{sub}}) do
      __deff_bind_seq({{pat}}, {{v}}, {{idx + 1}}, {{tmp}}) do
        {{yield}}
      end
    end
  {% end %}
end

# :nodoc:
# Same as `__deff_bind_seq`, for named tuple patterns (by key).
macro __deff_bind_ntseq(pat, v, idx, tmp, &)
  {% if idx >= pat.to_a.size %}
    {{yield}}
  {% else %}
    {% pair = pat.to_a[idx] %}
    {% sub = "#{tmp.id}_#{pair[0]}".id %}
    __deff_bind_one({{pair[1]}}, {{v}}[:{{pair[0]}}], {{sub}}) do
      __deff_bind_ntseq({{pat}}, {{v}}, {{idx + 1}}, {{tmp}}) do
        {{yield}}
      end
    end
  {% end %}
end

# :nodoc:
# Binds every argument of the clause `c` in order, then runs the block
# (the guard + body). Callers may refer to any binding from it.
macro __deff_bind_args(c, idx, arity, &)
  {% if idx >= arity %}
    {{yield}}
  {% elsif c.args[idx].is_a?(TupleLiteral) || c.args[idx].is_a?(ArrayLiteral) || c.args[idx].is_a?(NamedTupleLiteral) %}
    __deff_bind_one({{c.args[idx]}}, a{{idx}}, __deff_t{{idx}}) do
      __deff_bind_args({{c}}, {{idx + 1}}, {{arity}}) do
        {{yield}}
      end
    end
  {% else %}
    {% item = c.args[idx] %}
    {% if item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
      {% unless item.id == "_" %}
        {{item}} = a{{idx}}
      {% end %}
    {% end %}
    __deff_bind_args({{c}}, {{idx + 1}}, {{arity}}) do
      {{yield}}
    end
  {% end %}
end

macro deff(name, &block)
  {% clauses = block.body.is_a?(Expressions) ? block.body.expressions : [block.body] %}
  {% arity = clauses[0].args.size %}
  {% for c in clauses %}
    {% unless c.is_a?(Call) && c.name == "fn" && c.block %}
      {% raise "deff clause must look like fn(pattern) { ... }, got: #{c}" %}
    {% end %}
    {% if c.args.size != arity %}
      {% raise "clause arity mismatch in #{name}: expected #{arity}, got #{c.args.size}" %}
    {% end %}
    {% if c.named_args %}
      {% for na in c.named_args %}
        {% unless na.name == "when" %}
          {% raise "unknown fn option #{na.name} in #{name}, supported: when" %}
        {% end %}
      {% end %}
    {% end %}
  {% end %}

  # check helpers for destructured patterns, defined before the dispatch
  # method so they resolve first
  {% for c, ci in clauses %}
    {% for item, i in c.args %}
      {% if item.is_a?(TupleLiteral) || item.is_a?(ArrayLiteral) || item.is_a?(NamedTupleLiteral) %}
        __deff_check_helper(__deff_check_{{name.id}}_{{ci}}_{{i}}, {{item}})
      {% end %}
    {% end %}
  {% end %}

  def {{name.id}}({% for i in 0...arity %}a{{i}}, {% end %})
    {% for c, ci in clauses %}
      {% guard = nil %}
      {% if c.named_args %}
        {% for na in c.named_args %}
          {% guard = na.value %}
        {% end %}
      {% end %}
      # shape/type/literal checks, nested so a failed check skips the body;
      # binder args need no check
      {% for item, i in c.args %}
        {% if item.is_a?(TupleLiteral) || item.is_a?(ArrayLiteral) || item.is_a?(NamedTupleLiteral) %}
          if __deff_check_{{name.id}}_{{ci}}_{{i}}(a{{i}})
        {% elsif item.is_a?(Path) %}
          if a{{i}}.is_a?({{item}})
        {% elsif item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
          # binder: always matches
        {% else %}
          if a{{i}} == {{item}}
        {% end %}
      {% end %}
      # bindings — chained after the checks, because a destructured binding
      # such as `a = a0[0]` is only valid once the shape of a0 is confirmed;
      # the guard and body ride along in the innermost block, where every
      # binding is visible
      __deff_bind_args({{c}}, 0, {{arity}}) do
        {% if guard %}
          if {{guard}}
        {% end %}
            return {{c.block.body}}
        {% if guard %}
          end
        {% end %}
      end
      {% for item in c.args %}
        {% if item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
          # binder: nothing to close
        {% else %}
          end
        {% end %}
      {% end %}
    {% end %}
    match_args = { {% for i in 0...arity %}a{{i}}, {% end %} }
    raise Functional::MatchError.new("no matching clause for {{name.id}}(#{match_args.inspect})")
  end
end
