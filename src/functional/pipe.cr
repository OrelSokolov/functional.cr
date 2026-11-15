# Threading pipeline: threads a value through a chain of method calls,
# like Elixir's `|>`. Expands to plain chained method calls at compile time.
#
#   pipe "1,2,3", split(","), map(&.to_i), sum   # => 6
#
# A step is either a method call (applied to the threaded value as receiver,
# extra args and blocks included) or a proc literal (called with the value).

macro pipe(value, *steps)
  _functional_pipe({{value}}, {{steps.splat}})
end

macro _functional_pipe(value, *steps)
  {% if steps.size == 0 %}
    {{value}}
  {% elsif steps.size == 1 %}
    _functional_step({{value}}, {{steps[0]}})
  {% else %}
    _functional_pipe(_functional_step({{value}}, {{steps[0]}}), {% for i in 1...steps.size %}{{steps[i]}}, {% end %})
  {% end %}
end

macro _functional_step(value, c)
  {% if c.is_a?(ProcLiteral) %}
    {{c}}.call({{value}})
  {% elsif c.is_a?(Var) %}
    # local variable holding a proc: call it with the threaded value
    {{c}}.call({{value}})
  {% elsif c.is_a?(Call) %}
    {% if c.block %}
      {{value}}.{{c.name.id}}({{c.args.splat}}) {{c.block}}
    {% else %}
      {{value}}.{{c.name.id}}({{c.args.splat}})
    {% end %}
  {% else %}
    {% raise "pipe step must be `method(args)` or a proc literal, got: #{c}" %}
  {% end %}
end
