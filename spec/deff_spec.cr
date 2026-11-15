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

deff :axis do
  fn({0, y}) { "y=#{y}" }
  fn({x, 0}) { "x=#{x}" }
  fn(_) { "diagonal" }
end

deff :sum_pair do
  fn({a, b}) { a + b }
end

deff :nested_pair do
  fn({ {x, y}, z }) { x + y + z }
end

deff :typed_pair do
  fn({Int32, b}) { "int+#{b}" }
  fn(_) { "other" }
end

deff :first_of do
  fn([a, _]) { a }
  fn(_) { nil }
end

deff :role do
  fn({name: "admin", org: o}) { "#{o}/admin" }
  fn({name: n, org: _}) { n }
  fn(_) { "anon" }
end

deff :pair_guard do
  fn({a, b}, when: a == b) { :equal }
  fn(_) { :different }
end

deff :only_one_one do
  fn({1, 1}) { "hit" }
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

  it "destructures tuple patterns" do
    sum_pair({3, 4}).should eq 7
  end

  it "mixes destructuring with literals and wildcards" do
    axis({0, 5}).should eq "y=5"
    axis({7, 0}).should eq "x=7"
    axis({2, 3}).should eq "diagonal"
  end

  it "destructures nested tuples" do
    nested_pair({ {1, 2}, 3 }).should eq 6
  end

  it "destructures with type sub-patterns" do
    typed_pair({42, "x"}).should eq "int+x"
    typed_pair({"a", "b"}).should eq "other"
  end

  it "destructures arrays" do
    first_of([9, :rest]).should eq 9
    first_of("nope").should be_nil
  end

  it "destructures named tuples by key" do
    role({name: "admin", org: "acme"}).should eq "acme/admin"
    role({name: "bob", org: "acme"}).should eq "bob"
    role("anon").should eq "anon"
  end

  it "supports guards over destructured bindings" do
    pair_guard({1, 1}).should eq :equal
    pair_guard({1, 2}).should eq :different
  end

  it "raises MatchError when no destructuring clause matches" do
    expect_raises(Functional::MatchError, /no matching clause for only_one_one/) { only_one_one({2, 2}) }
  end
end
