# WITH guards: every argument is validated in Crystal *before* it crosses
# into C. A bad argument becomes Functional::MatchError — an ordinary,
# rescuable exception — instead of a hardware fault that kills the process.

require "../../src/functional"

lib MathLib
  fun mg_div(a : Int32, b : Int32) : Int32
  fun mg_mean(sum : Int32, n : Int32) : Int32
end

# Guard clauses at the FFI boundary: only sound arguments reach the C fun.
deff :safe_div do
  fn(a, b, when: b != 0) { MathLib.mg_div(a, b) }
  fn(_, _) { raise Functional::MatchError.new("safe_div: division by zero") }
end

deff :safe_mean do
  fn(sum, n, when: n > 0) { MathLib.mg_mean(sum, n) }
  fn(_, _) { raise Functional::MatchError.new("safe_mean: empty sample (n == 0)") }
end

calls = [
  {84, 2},
  {99, 3},
  {10, 0}, # killed the process in the unguarded version
  {7, 0},
]

calls.each do |pair|
  a, b = pair
  begin
    puts "#{a} / #{b} = #{safe_div(a, b)}"
  rescue e : Functional::MatchError
    puts "#{a} / #{b} = rejected by guard: #{e.message}"
  end
end

begin
  puts "mean(50, 5) = #{safe_mean(50, 5)}"
  puts "mean(9, 0)  = #{safe_mean(9, 0)}"
rescue e : Functional::MatchError
  puts "mean(9, 0)  = rejected by guard: #{e.message}"
end

puts "done — the program survived every bad argument"
