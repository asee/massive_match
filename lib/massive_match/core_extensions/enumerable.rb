#
# Stuff that will make our lives easier elsewhere
#
module Enumerable
  #
  # Accept any number of enumerables and compose an array of tuples
  #
  def cartesian_product(*enums)
    return self if enums.empty?
    results = [[]]
    ([self] + enums).each do |vector|
      iter_results, results = results, []
      iter_results.each do |existing|
        vector.each do |elt|
          results << existing + [elt]
        end
      end
    end
    results
  end

end
