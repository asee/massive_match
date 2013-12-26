#
# Variable Collection provide methods for accessing variables as well as
# methods for outputting those variables for consumption by LPSolve
#
module MassiveMatch
  class VariableCollection
    include Enumerable

    attr_reader :collection_indices

    #
    # Expects an array of arrays to manage
    #
    def initialize(collections)
      # Keeps hold of the collections
      @collections = collections

      # Holds all of our variables
      @variable_map = {}

      # Tracks expanded sets containing particular members of collections
      @collection_indices = {}

      # Do the expansion and indexing immediately
      expand_and_index
    end

    #
    # Creates a set of variables for consumption by LPSolver from array indices
    # of composing collections of the form:
    # var[col_1_id]x[col_2_id]x...x[col_n_id]
    #
    def expand_and_index
      _index_recurser(@collections.map(&:size))
    end

    #
    # Find each variable name from the collection at the position
    #
    def variables_for_collection_element(collection_idx, element_idx)
      @collection_indices[[collection_idx, element_idx]]
    end

    #
    # All variable strings
    #
    def variable_names
      @variable_map.keys
    end

    #
    # All of the possible tuples for the collection
    #
    def tuples
      @variable_map.values
    end

    #
    # Pass the block through to the variable map
    #
    def each(&block)
      @variable_map.each(&block)
    end

    #
    # Access the map directly
    #
    def [](idx)
      @variable_map[idx.to_s]
    end

    def inspect
      "#<#{self.class.name}:#{self.id}>"
    end

  private
    #
    # Calculate explicit n-ary Cartesian product of incoming collections as
    # well as indices. An element can be set to a particular value
    #
    def _index_recurser(future_collection_sizes, elts = [])
      if future_collection_sizes.empty?
        # This is the bottom--add to the proper indices
        var_name = "var#{elts.join("x")}"

        objs = []
        elts.each_with_index do |elt,jdx|
          objs << @collections[jdx][elt]
          @collection_indices[[jdx,elt]] ||= []
          @collection_indices[[jdx,elt]] << var_name
        end
        @variable_map[var_name] = objs

      else
        # Set up a prefix and recurse
        size = future_collection_sizes.shift
        0.upto(size-1) do |idx|
          new_elts = elts.dup << idx
          _index_recurser(future_collection_sizes.dup, new_elts)
        end
      end
    end


  end
end