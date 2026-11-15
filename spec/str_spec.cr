require "../src/functional"
require "spec"

module Str
  def self.trim(s : String) : String
    s.strip
  end

  def self.downcase(s : String) : String
    s.downcase
  end

  def self.codepoints(s : String) : Array(Char)
    s.chars
  end
end

describe "Str pipeline" do
  it "threads through module functions like String.trim |> String.downcase |> String.codepoints" do
    result = pipe "  Hi  ",
      Str.trim,
      Str.downcase,
      Str.codepoints

    result.should eq ['h', 'i']
  end
end
