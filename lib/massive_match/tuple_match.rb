module MassiveMatch

  #
  # Matches groups of elements from an arbitrary number of sets. It can match
  # across any number of sets, returning tuples, each containing one member
  # from each composing set. For example, it can be used to match dogs with dog
  # walkers:
  #
  # Walkers: Alice, Bob, Carol
  # Dogs: Arnold, Bear, Clifford
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
    attr_reader :constraints, :variable_set

    def initialize(sets)
      @sets = sets
      @variable_set = VariableSet.new(sets)
      @constraints = []
      @matches_per_element = {}
      @inclusion_composers = nil
      @inclusion_vars = nil
    end


    #
    # Makes it so that each element within a vector is matched a set number of
    # times
    #
    def set_matches_per_element(match_vector)
      @matches_per_element = @matches_per_element.merge(match_vector)
    end


    #
    # Adds a subset as an inclusion set. Inclusion sets are unioned upon solve
    # time to create a variable matrix which contains each possible tuple.
    # A weight can be optionally added, with lower weights being preferred over
    # higher weights on solve. Elements assigned multiple weights are currently
    # unstable and should be avoided.
    #
    def add_inclusion_composer(vectors, options={})
      weight = options[:weight] || 1
      @inclusion_vars = nil
      matrix = @variable_set.create_subset(vectors)
      @inclusion_composers ||= {}
      @inclusion_composers[weight] ||= []
      @inclusion_composers[weight] << matrix
    end


    #
    # Adds a manual constraint in native lp format
    #
    def add_constraint(constraint_def)
      @constraints << Constraint.new(constraint_def)
    end


    #
    # Takes in a set of vectors which will compose a matrix of illegal
    # combinations
    #
    def add_exclusion_constraint(vectors)
      subset = @variable_set.create_subset(vectors)
      if !subset.empty?
        @constraints << Constraint.new(
          :vars => subset.to_lp_vars,
          :operator => '=',
          :target => 0
        )
      end
    end


    #
    # Takes in a hash of hashes that maps to the sets at the top level; at the
    # next level there is a hash of set element -> array of markers
    #
    # example:
    # {
    #   :dogs => {:dog1 => [1,2], :dog2 => [3]},
    #   :walkers => {:walker1 => [3], :walker2 => [4,5]}
    # }
    #
    # Any elements that share a marker will be put into an exclusion constraint
    #
    def exclude_on_markers(marker_hashes)
      # reindex
      objects_by_marker = reindex_by_marker(marker_hashes)

      # iterate over combinations
      objects_by_marker.each do |marker,marked_hashes|
        marked_sets = marked_hashes.to_a
        until marked_sets.size == 1
          o_name, o_set = marked_sets.pop
          marked_sets.each do |i_name,iter_hash|
            add_exclusion_constraint({o_name => o_set, i_name => iter_hash})
          end
        end
      end
    end


    #
    # Run the match with current constraints
    #
    def match
      # Set up initial variables
      lp = LPSelect.new(:vars => inclusion_vars)
      lp.set_objective(compose_objective)

      # Added whatever constraints have been placed
      constraints.each do |c|
        c.vars &= inclusion_vars if @inclusion_composers
        next if c.vars.empty?

        lp.add_constraint(c.to_lp_arg)
      end

      # Write to a file for debugging (comment this out later)
      lp.to_file("/tmp/eq")

      # Solve the equation
      status = lp.solve
      if status != LPSolve::OPTIMAL
        raise "No optimal solution"
      end

      # Parse the results
      results = lp.results.reject{|var, result| result.zero?}.keys
      results.map{|result| @variable_set[result]}
    end



  private
    #
    # Composes the objective function
    #
    def compose_objective
      objective = {}
      @inclusion_composers.each do |weight,weighted_sets|
        weighted_sets.each do |set|
          set.to_lp_vars.each do |var|
            objective[var] = weight
          end
        end
      end
      objective
    end


    #
    # Pulls the lp variables forming the inclusion matrix from composers
    #
    def inclusion_vars
      @inclusion_vars ||= begin
        if @inclusion_composers.nil?
          @variable_set.to_lp_vars
        else
          @inclusion_composers.values.flatten.inject([]) do |composition,composer|
            composition |= composer.to_lp_vars
          end
        end
      end
    end


    #
    # Sets up constraints based on matches_per_element values and the given
    # block if present
    #
    def constraints(extra_constraints=[])
      run_constraints = @constraints.dup
      run_constraints += extra_constraints

      # Add object-wide constraints
      @matches_per_element.each do |set_name,num_matches|
        set = @sets[set_name]
        set.each do |elt|
          # create a subset of all vars attached to our element
          subset = @variable_set.create_subset(set_name => [elt])

          # add that subset as a constraint
          if num_matches.is_a?(Integer)
            run_constraints << Constraint.new(
              :vars => subset.to_lp_vars,
              :operator => '=',
              :target => num_matches
            )
          elsif num_matches.is_a?(Range)
            run_constraints << Constraint.new(
              :vars => subset.to_lp_vars,
              :operator => '>=',
              :target => num_matches.min,
              :flexible => true
            )

            run_constraints << Constraint.new(
              :vars => subset.to_lp_vars,
              :operator => '<=',
              :target => num_matches.max
            )            
          else
            raise "Matches per element target must an Integer or a Range"
          end
        end
      end

      run_constraints
    end

    # def inspect
    #   "TupleMatch Object"
    # end


    #
    # Takes in hashes of vectors with hashes of component elements with arrays
    # of markers, then reindexes them on marker
    #
    # Example:
    #
    # panelists:
    #   p1: [1,2,3]
    #   p2: [2]
    # applications:
    #   a1: [1,4]
    #   a2: [4]
    #
    # produces
    #
    # 1:
    #   panelists: [p1]
    #   applications: [a1]
    # 2:
    #   panelists: [p1, p2]
    # 3:
    #   panelists: [p1]
    # 4:
    #   applications: [a1, a2]

    def reindex_by_marker(marker_hashes)
      out = {}
      marker_hashes.each do |vector,mh|
        mh.each do |obj,markers|
          markers = [markers] unless markers.is_a?(Array)
          markers.each do |marker|
            out[marker] ||= {}
            out[marker][vector] ||= []
            out[marker][vector] << obj
          end
        end
      end
      out
    end

  end
end