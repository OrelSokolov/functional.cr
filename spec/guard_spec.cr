require "../src/functional"
require "spec"

deff :kind_of do
  fn(x, when: x.is_a?(Int32) && x > 0) do
    "Positive integer"
  end

  fn(x, when: x.is_a?(Int32) && x < 0) do
    "Negative integer"
  end

  fn(0) do
    "Zero"
  end
end

describe "guards" do
  it "dispatches on type + comparison guards like Elixir def ... when ..." do
    kind_of(5).should eq "Positive integer"
    kind_of(-3).should eq "Negative integer"
    kind_of(0).should eq "Zero"
  end

  it "falls through all clauses and raises when no guard/pattern matches" do
    expect_raises(Functional::MatchError) { kind_of("str") }
  end
end
