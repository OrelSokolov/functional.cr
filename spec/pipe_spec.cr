require "../src/functional"
require "spec"

def half(x : Int32) : Int32
  x // 2
end

def inc(x : Int32) : Int32
  x + 1
end

def clamp(x : Int32, lo : Int32, hi : Int32) : Int32
  Math.min(Math.max(x, lo), hi)
end

def second_word(text : String, separator : String) : String
  text.split(separator)[1]
end

describe "pipe" do
  it "threads the value as first argument of free functions" do
    pipe(10, half, inc).should eq 6
    # expands to: inc(half(10))
  end

  it "inserts extra step args after the threaded value" do
    pipe(15, clamp(0, 10)).should eq 10
    # expands to: clamp(15, 0, 10)
  end

  it "works with namespaced module functions" do
    pipe(9, Math.sqrt).should eq 3.0
    # expands to: Math.sqrt(9)
  end

  it "supports proc literals and proc variables" do
    double = ->(x : Int32) { x * 2 }
    pipe(5, double).should eq 10
    pipe(5, ->(x : Int32) { x + 1 }).should eq 6
  end

  it "flattens nested free-function calls" do
    pipe("hello brave world", second_word(" ")).should eq "brave"
  end

  it "returns the value unchanged with no steps" do
    pipe(42).should eq 42
  end
end

describe "Functional" do
  it "composes procs" do
    f = ->(x : Int32) { x + 1 }
    g = ->(x : Int32) { x * 2 }
    Functional.compose(f, g).call(3).should eq 8
    Functional.pipe(f, g).call(3).should eq 8
  end

  it "curries two-argument procs" do
    add = ->(x : Int32, y : Int32) { x + y }
    Functional.curry(add).call(2).call(3).should eq 5
  end

  it "returns identity" do
    Functional.identity("x").should eq "x"
  end
end
