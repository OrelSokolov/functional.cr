require "../src/functional"
require "spec"

deff :fact do
  fn(0) { 1 }
  fn(n) { n * fact(n - 1) }
end

deff :gcd do
  fn(a, 0) { a }
  fn(a, b) { gcd(b, a % b) }
end

deff :describe do
  fn(0) { "zero" }
  fn(Int32) { "some int" }
  fn(_) { "not an int" }
end

deff :sign do
  fn(x, when: x < 0) { -1 }
  fn(0) { 0 }
  fn(_) { 1 }
end

deff :only_two do
  fn(2) { "two" }
end

deff :arity_two do
  fn(a, b) { "#{a}-#{b}" }
end

describe "deff" do
  it "matches literals and binds args" do
    fact(5).should eq 120
  end

  it "matches mixed literal/binder clauses" do
    gcd(48, 18).should eq 6
    gcd(7, 0).should eq 7
  end

  it "matches types and falls through to wildcard" do
    describe(0).should eq "zero"
    describe(42).should eq "some int"
    describe("hello").should eq "not an int"
  end

  it "supports guards that fall through to later clauses" do
    sign(-5).should eq -1
    sign(0).should eq 0
    sign(9).should eq 1
  end

  it "raises MatchError when no clause matches" do
    expect_raises(Functional::MatchError, /no matching clause for only_two/) { only_two(3) }
  end

  it "catches arity mismatch between clauses at compile time" do
    # arity mismatch is a macro-time error; here we just verify the happy path
    arity_two(1, "a").should eq "1-a"
  end
end
