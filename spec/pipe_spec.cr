require "../src/functional"
require "spec"

describe "pipe" do
  it "threads a value through method calls with args and blocks" do
    pipe("1,2,3", split(","), map(&.to_i), sum).should eq 6
  end

  it "threads through zero-arg method calls" do
    pipe("  hi  ", strip, upcase).should eq "HI"
  end

  it "supports proc literal steps" do
    double = ->(x : Int32) { x * 2 }
    inc = ->(x : Int32) { x + 1 }
    pipe(5, double, inc).should eq 11
  end

  it "returns the value unchanged with no steps" do
    pipe(42).should eq 42
  end

  it "works inside expressions" do
    (pipe("a,b", split(",")).size).should eq 2
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
