require "../src/functional"
require "spec"

# аналог Elixir: defguard is_even(n) when rem(n, 2) == 0
def even?(n : Int32) : Bool
  n % 2 == 0
end

def positive?(n : Int32) : Bool
  n > 0
end

deff :classify do
  fn(n, when: even?(n) && positive?(n)) { "positive even" }
  fn(n, when: even?(n)) { "even" }
  fn(_) { "other" }
end

describe "custom guards" do
  it "reuses plain functions as guards (defguard analog)" do
    classify(4).should eq "positive even"
    classify(-2).should eq "even"
    classify(3).should eq "other"
  end
end
