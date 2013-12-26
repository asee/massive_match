module MassiveMatch

  #
  # Matches groups of elements from an arbitrary number of sets. It can match
  # across any number of sets, returning tuples, each containing one member
  # from each composing set. For example, it can be used to match dogs with dog
  # walkers:
  #
  # Walkers: Alice, Bob, Carol
  # Dogs: Arnold, Bev, Clint
  #
  # One match would be: [Alice, Arnold]
  #
  # You may specify rules for matches. Say, each dog must be walked by two
  # different walkers.  Also, you could say that dogs can't be walked by
  # humans whose names start with the same letter. In this case, only one
  # outcome is possible.
  #
  # The TupleMatch#match method specifies the arguments that can be handled.
  #
  # This class acts as wrapper around the LPSolve library, which proviceds more
  # generalized problem solving power than this class utilizes.
  #
  class TupleMatch
    attr_reader :variable_collection, :match_block

    class << self

      #
      # Starting point for match making. Takes in the following arguments:
      #
      # Array of hashes with the following keys
      # :collection          : array of objects for matching
      # :matches_per_element : integer or range of the number of elements to be
      #                        matched on a given element
      #
      # Also optionally takes in a block that accepts a pair of elements to be
      # matched and returns false if that match should not be allowed. At least
      # two collections should be passed in for this to be useful.
      #
      def match(collections_config, &block)
        new(collections_config, &block).match
      end

    end


    def initialize(collections_config, &block)
      @collections_config = collections_config
      @collections = collections_config.map{|cc| cc[:collection]}
      @match_block = block
      @variable_collection = VariableCollection.new(@collections)
    end

    def match
      # Set up initial variables
      lp = LPSelect.new(:vars => @variable_collection.variable_names)
      constraints.each{|c| lp.add_constraint(c.to_lp_arg)}

      # Solve the equation
      status = lp.solve
      if status != LPSolve::OPTIMAL
        raise "No optimal solution"
      end

      # Parse the results
      results = lp.results.reject{|var, result| result.zero?}.keys
      results.map{|result| @variable_collection[result]}
    end


    #
    # Sets up constraints based on matches_per_element values and the given
    # block if present
    #
    def constraints
      return @constraints if defined?(@constraints) && @constraints
      @constraints = []

      # Apply single-collection min/max constraints
      @collections_config.each_with_index do |config, idx|
        if config.has_key?(:matches_per_element)
          if config[:matches_per_element].is_a?(Integer)
            0.upto(config[:collection].size - 1) do |elt|
              @constraints << Constraint.new(
                :vars => @variable_collection.variables_for_collection_element(idx, elt),
                :operator => '=',
                :target => config[:matches_per_element]
              )
            end

          elsif config[:matches_per_element].is_a?(Range)
            0.upto(config[:collection].size - 1) do |elt|
              @constraints << Constraint.new(
                :vars => @variable_collection.variables_for_collection_element(idx, elt),
                :operator => '>=',
                :target => config[:matches_per_element].min
              )

              @constraints << Constraint.new(
                :vars => @variable_collection.variables_for_collection_element(idx, elt),
                :operator => '<=',
                :target => config[:matches_per_element].max
              )
            end

          end
        end
      end

      # Create a constraint based on our block if one was given initially
      if @match_block
        # run each tuple through the block--only keeping the ones that return
        # false so we can exclude them later
        vars = @variable_collection.reject do |var, tuple|
          @match_block.call(*tuple)
        end

        # results come back as [var_name, tuple]; ignore the tuple here
        vars.map!{|v| v[0]}

        @constraints << Constraint.new(
          :vars => vars,
          :operator => '=',
          :target => 0
        )
      end

      @constraints
    end

    def inspect
      "PairMatch Object"
    end


  end
end