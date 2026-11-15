# WITHOUT guards: arguments reach C verbatim.
#
# The first calls succeed, then one bad argument kills the process.
# Nothing below the crash ever runs — and no `rescue` can help.

lib MathLib
  fun mg_div(a : Int32, b : Int32) : Int32
  fun mg_mean(sum : Int32, n : Int32) : Int32
end

puts "computing 84 / 2  => #{MathLib.mg_div(84, 2)}"
puts "computing 99 / 3  => #{MathLib.mg_div(99, 3)}"
puts "mean of 50 by 5  => #{MathLib.mg_mean(50, 5)}"

puts "computing 10 / 0 ..."
puts MathLib.mg_div(10, 0) # SIGFPE inside C: the process dies right here

puts "never reached — the line above killed the program"
