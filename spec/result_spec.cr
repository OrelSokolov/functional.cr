require "../src/functional"
require "spec"

def parse_int(s : String)
  v = s.to_i?
  v ? ok(v) : err("not a number: #{s}")
end

deff :show do
  fn(r, when: r.is_a?(Ok) && r.value == 0) { "ok, but zero" }
  fn(r, when: r.is_a?(Ok)) { "ok: #{r.value}" }
  fn(r, when: r.is_a?(Err)) { "err: #{r.error}" }
end

describe "Result" do
  it "dispatches with native case, like case {:ok, v} -> ... in Elixir" do
    r = parse_int("42")
    msg = case r
          when Ok  then "ok: #{r.value}"
          when Err then "err: #{r.error}"
          end
    msg.should eq "ok: 42"

    r = parse_int("oops")
    msg = case r
          when Ok  then "ok: #{r.value}"
          when Err then "err: #{r.error}"
          end
    msg.should eq "err: not a number: oops"
  end

  it "chains the happy path and short-circuits on error" do
    parse_int("42").map { |v| v * 2 }.unwrap_or(0).should eq 84
    parse_int("x").map { |v| v * 2 }.unwrap_or(0).should eq 0

    parse_int("42")
      .and_then { |v| v.even? ? ok(v // 2) : err("odd: #{v}") }
      .map { |v| v + 1 }
      .unwrap_or(-1)
      .should eq 22

    parse_int("43")
      .and_then { |v| v.even? ? ok(v // 2) : err("odd: #{v}") }
      .map { |v| v + 1 }
      .unwrap_or(-1)
      .should eq(-1)
  end

  it "answers predicates and nilable accessors" do
    r = parse_int("7")
    r.ok?.should be_true
    r.err?.should be_false
    r.value?.should eq 7
    r.error?.should be_nil

    e = parse_int("x")
    e.ok?.should be_false
    e.err?.should be_true
    e.value?.should be_nil
    e.error?.should eq "not a number: x"
  end

  it "combines with deff guards (value-specific clauses)" do
    show(parse_int("42")).should eq "ok: 42"
    show(parse_int("0")).should eq "ok, but zero"
    show(parse_int("x")).should eq "err: not a number: x"
  end
end
