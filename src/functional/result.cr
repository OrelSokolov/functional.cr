# Elixir-style `{:ok, value}` / `{:error, reason}` for Crystal, with the
# tag checked by the compiler instead of matched at runtime.
#
#   def parse_int(s)                        # inferred: Ok(Int32) | Err(String)
#     v = s.to_i?
#     v ? ok(v) : err("not a number: #{s}")
#   end
#
#   case parse_int(input)                   # ≈ case ... do {:ok, v} -> ...
#   when Ok  then puts "ok: #{res.value}"
#   when Err then puts "err: #{res.error}"
#   end
#
# Both variants are structs, so wrapping never touches the heap — an
# exception costs ~432 bytes of GC work per raise, `Ok`/`Err` cost nothing.
# Combinators use `yield`, not `Proc`, for the same reason.
#
# A `case` over `Ok | Err` is exhaustive at compile time: forget the
# `when Err` branch and the value's type widens with `Nil`, which the
# compiler flags at the first use.

struct Ok(T)
  getter value : T

  def initialize(@value : T)
  end

  def map(& : T -> U) : Ok(U) forall U
    Ok.new(yield @value)
  end

  def and_then(& : T -> U) : U forall U
    yield @value
  end

  def unwrap_or(default) : T
    @value
  end

  def ok? : Bool
    true
  end

  def err? : Bool
    false
  end

  def value? : T?
    @value
  end

  def error? : Nil
    nil
  end
end

struct Err(E)
  getter error : E

  def initialize(@error : E)
  end

  # Error path: the chain is short-circuited, the block never runs.
  def map(&) : Err(E)
    self
  end

  def and_then(&) : Err(E)
    self
  end

  def unwrap_or(default) 
    default
  end

  def ok? : Bool
    false
  end

  def err? : Bool
    true
  end

  def value? : Nil
    nil
  end

  def error? : E?
    @error
  end
end

# Elixir-style constructors: ok(v) ≈ {:ok, v}, err(reason) ≈ {:error, reason}
# (a `Result(T, E)` alias is not expressible: Crystal aliases can't declare
# their own type parameters — write `Ok(T) | Err(E)` in annotations, or let
# the return type be inferred)
def ok(value)
  Ok.new(value)
end

def err(reason)
  Err.new(reason)
end
