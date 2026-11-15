# Elixir-style multi-clause functions with pattern matching on argument values.
#
#   deff :fact do
#     fn(0) { 1 }
#     fn(n) { n * fact(n - 1) }
#   end
#
# Clauses are tried top to bottom; the first match wins. Supported patterns:
#   - literal     -> equality check (==)
#   - type (Path) -> is_a? check (e.g. Int32, String, MyType)
#   - identifier  -> binds the argument to that name
#   - `_`         -> wildcard
#
# A clause may carry a guard: `fn(n, when: n > 0) { ... }`.
# When no clause matches at runtime, Functional::MatchError is raised.

class Functional::MatchError < Exception
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

  def {{name.id}}({% for i in 0...arity %}a{{i}}, {% end %})
    {% for c in clauses %}
      {% guard = nil %}
      {% if c.named_args %}
        {% for na in c.named_args %}
          {% guard = na.value %}
        {% end %}
      {% end %}
      # bindings (harmless if the clause later fails to match: next clause rebinds)
      {% for item, i in c.args %}
        {% binder = item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
        {% if binder && item.id != "_" %}
          {{item}} = a{{i}}
        {% end %}
      {% end %}
      # pattern checks, nested for short-circuit &&
      {% for item, i in c.args %}
        {% binder = item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
        {% unless binder %}
          {% if item.is_a?(Call) && item.args.size > 0 %}
            {% raise "unsupported pattern #{item} in #{name}: literal, Type or binder identifier only" %}
          {% elsif item.is_a?(Path) %}
            if a{{i}}.is_a?({{item}})
          {% else %}
            if a{{i}} == {{item}}
          {% end %}
        {% end %}
      {% end %}
      # guard
      {% if guard %}
        if {{guard}}
      {% end %}
          return {{c.block.body}}
      {% if guard %}
        end
      {% end %}
      {% for item in c.args %}
        {% binder = item.is_a?(Var) || item.is_a?(Underscore) || (item.is_a?(Call) && item.args.empty?) %}
        {% unless binder %}
          end
        {% end %}
      {% end %}
    {% end %}
    match_args = { {% for i in 0...arity %}a{{i}}, {% end %} }
    raise Functional::MatchError.new("no matching clause for {{name.id}}(#{match_args.inspect})")
  end
end
