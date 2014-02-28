module MassiveMatch
  class FlatVariableSet
    include Enumerable

    attr_reader :set_indices, :sets

    #
    # Expects an array to manage
    #
    def initialize(set, indices=nil)
      @set = set

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
      FlatVariableSet.new(subset_elts, @set_indices)
    end


    def empty?
      @set.empty?
    end


    def size
      @set.size
    end


    #
    # Use our indices to put variables in form for lp_solve
    # We use integer indices prefixed with v and joined by x, e.g. v13x45x12
    # 
    #
    def to_lp_vars
      @set.map{|t| "v#{@set_indices[t]}"}
    end


    #
    # This returns the set of objects from the given lp var
    #
    def [](val)
      val = val.to_s[1..-1] # lop off the leading "v"
      lookup_index(val)
    end



  protected

    #
    # Assign each set item an integer index
    #
    def create_indices
      indexed_set = {}
      @set.each_with_index do |elt,i|
        indexed_set[elt] = i
      end
      indexed_set
    end

    #
    # Remove unused indices if using a given set
    #
    def winnow_indices(indices)
      results = {}
      @set.each do |elt|
        results[elt] = indices[elt]
      end
      results
    end

    #
    # Inverts our indices for reverse look up
    #
    def lookup_index(index)
      @index_lookup_table ||= @set_indices.invert
      @index_lookup_table[index.to_i]
    end

  end
end