# Threading pipe with Elixir `|>` semantics: the threaded value is inserted
# as the FIRST ARGUMENT of the next call. This flattens nested calls:
#
#   format_label(get_address(get_user(id)))
#
#   pipe id, get_user, get_address, format_label
#
# Step forms:
#   - `f(a, b)`         -> `f(value, a, b)`      (free function, first arg)
#   - `Mod.m(a)`        -> `Mod.m(value, a)`     (namespaced function)
#   - `->(x) { ... }`   -> `proc.call(value)`
#   - local proc var    -> `var.call(value)`
#
# Method chaining on the value itself (`"a,b".split(",").map(&.to_i)`)
# is already idiomatic Crystal with `.` — no pipe needed there.

macro pipe(value, *steps)
  {% if steps.size == 0 %}
    {{value}}
  {% else %}
    _functional_pipe({{value}}, [{{steps.splat}}], 0)
  {% end %}
end

# Iterates by index over the steps array passed as a single node.
# Re-splatting the tail on every level (the obvious recursive design)
# copies O(n) AST nodes per level => O(n^2); a 100k-step pipeline then
# OOMs the compiler. Index-sharing keeps it O(n).
macro _functional_pipe(value, steps, idx)
  {% if idx == steps.size %}
    {{value}}
  {% else %}
    _functional_pipe(_functional_step({{value}}, {{steps[idx]}}), {{steps}}, {{idx + 1}})
  {% end %}
end

macro _functional_step(value, c)
  {% if c.is_a?(ProcLiteral) || c.is_a?(Var) %}
    {{c}}.call({{value}})
  {% elsif c.is_a?(Call) %}
    {% if c.block %}
      {% if c.receiver %}
        {{c.receiver}}.{{c.name.id}}({{value}}, {{c.args.splat}}) {{c.block}}
      {% else %}
        {{c.name.id}}({{value}}, {{c.args.splat}}) {{c.block}}
      {% end %}
    {% else %}
      {% if c.receiver %}
        {{c.receiver}}.{{c.name.id}}({{value}}, {{c.args.splat}})
      {% else %}
        {{c.name.id}}({{value}}, {{c.args.splat}})
      {% end %}
    {% end %}
  {% else %}
    {% raise "pipe step must be `function(args)`, `Mod.method(args)` or a proc, got: #{c}" %}
  {% end %}
end
