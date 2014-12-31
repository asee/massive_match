require_relative 'test_helper'
require 'minitest/autorun'

class TupleMatchTest < Minitest::Test
  def setup
    @dogs = ['Arfie', 'Bear', 'Canon', 'Cupcake', 'Godzilla']
    @humans = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Franz']

    @matcher = MassiveMatch::TupleMatch.new(
      dogs:   @dogs,
      humans: @humans
    )
  end
  

  def test_no_constraints_produce_empty_results
    results = @matcher.match
    assert results.empty?
  end


  def test_simple_constraint
    # walk each dog at least once, make each human walk at least once
    @matcher.match_at_least({dogs: @dogs.each, humans: @humans}, 1)
    @matcher.match_at_least({dogs: @dogs, humans: @humans.each}, 1)

    results = @matcher.match

    assert_equal [@dogs.size, @humans.size].max, results.size
    assert @dogs.all?{|dog| results.any?{|d,h| d == dog}}
    assert @humans.all?{|human| results.any?{|d,h| h == human}}
  end


  # def test_result_block_forms
  #   @matcher.match_at_least({dogs: @dogs.each, humans: @humans}, 1)
  #   @matcher.match_at_least({dogs: @dogs, humans: @humans.each}, 1)

  #   results = @matcher.match

  #   assert results.detect{|match| @dogs.include?(match[:dogs])}
  #   # assert results.detect{|dog, human| @dogs.include?(dog) && @humans.include?(human)}
  # end

  
  def test_insoluble_raises_error
    @matcher.match_exactly({humans: [@humans.first]}, @dogs.size)
    @matcher.match_exactly({humans: [@humans.first]}, @dogs.size + 1)

    assert_raises MassiveMatch::NoOptimalSolution do
      @matcher.match
    end
  end

  
end
