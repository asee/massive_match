#
# VariableSets provide methods for accessing variables as well as
# methods for outputting those variables for consumption by LPSolve
#
module MassiveMatch
  class VariableSet
    include Enumerable

    attr_reader :set_indices, :sets

    #
    # Expects an ordered hash of arrays to manage. Optionally takes in a list
    # of indices to use internally (useful for subsets).
    #
    def initialize(sets, indices=nil)
      @sets = sets

      @set_indices = indices ?
        winnow_indices(indices) :
        create_indices
    end


    #
    # Takes in a partial list of vector elements--any missing keys will be
    # treated as wild cards and included all elements at this level as part of
    # the new subset
    #
    def create_subset(subset_elts)
      ordered_subset_elts = {}
      @sets.each do |k,v|
        ordered_subset_elts[k] = subset_elts.has_key?(k) ?
          subset_elts[k] :
          v.dup
      end

      VariableSet.new(ordered_subset_elts, @set_indices)
    end


    def index_tuples
      # be sure to preserve order if using ruby 1.8.7
      vals = []
      @sets.keys.map do |k|
        vals << @set_indices[k].values
      end
      vals.first.product(*vals[1..-1])
    end


    def empty?
      @sets.any?(&:empty?)
    end


    #
    # Use our indices to put variables in form for lp_solve
    # We use integer indices prefixed with v and joined by x, e.g. v13x45x12
    # 
    #
    def to_lp_vars
      index_tuples.map{|t| "v#{t.join('x')}"}
    end


    #
    # This returns the set of objects from the given lp var
    #
    def [](val)
      val = val.to_s[1..-1] # lop off the leading "v"
      indices = val.split('x')
      @sets.keys.map do |set_name|
        lookup_index(set_name,indices.shift)
      end
    end


    #
    # Pseudo-Set operations--these assume a common superset of sets
    #
    # def &(other)
    #   VariableSet
    # end



  protected

    #
    # Assign each set item an integer index
    #
    def create_indices
      indexed_set = {}
      @sets.each do |set_name,set|
        indexed_set[set_name] = {}
        set.each_with_index do |elt,i|
          indexed_set[set_name][elt] = i
        end
      end
      indexed_set
    end

    #
    # Remove unused indices if using a given set
    #
    def winnow_indices(indices)
      results = {}
      @sets.each do |set_name,set|
        results[set_name] = {}
        set.each do |elt|
          results[set_name][elt] = indices[set_name][elt]
        end
      end
      results
    end

    #
    # Inverts our indices for reverse look up
    #
    def lookup_index(set,index)
      @index_lookup_table ||= {}
      @index_lookup_table[set] ||= @set_indices[set].invert
      @index_lookup_table[set][index.to_i]

      # raise @index_lookup_table[set]
    end

  end
end