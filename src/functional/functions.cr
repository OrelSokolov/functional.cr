# Proc-level helpers: composition, currying, identity.

module Functional
  # Composes two procs: (g . f)(x) == g.call(f.call(x))
  def self.compose(f : Proc(A, B), g : Proc(B, C)) : Proc(A, C) forall A, B, C
    ->(x : A) { g.call(f.call(x)) }
  end

  # Same as compose, with pipeline reading order: pipe(f, g) == g after f.
  def self.pipe(f : Proc(A, B), g : Proc(B, C)) : Proc(A, C) forall A, B, C
    ->(x : A) { g.call(f.call(x)) }
  end

  # Curries a two-argument proc: curry(f).call(x).call(y) == f.call(x, y)
  def self.curry(f : Proc(A, B, C)) : Proc(A, Proc(B, C)) forall A, B, C
    ->(x : A) { ->(y : B) { f.call(x, y) } }
  end

  def self.identity(x : A) : A forall A
    x
  end
end
