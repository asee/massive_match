module MassiveMatch

  #
  # Matches elements of a set based on selection rules and constraints.
  #

  class SelectionMatch
    attr_reader :constraints, :variable_set

    def initialize(set)
      @set = set
      @variable_set = FlatVariableSet.new(set)
      @constraints = []
      @objective = nil
    end


    #
    # Makes it so that each element within a vector is matched a set number of
    # times.
    #
    def set_matches_per_element(set_name, num_matches, options={})
      @set_options[set_name][:num_matches] = num_matches
      @set_options[set_name] = @set_options[set_name].merge(options)
    end


    #
    # TODO: This needs to be fixed. 
    #
    def set_objective(variables_with_weights)
      @objective = variables_with_weights
    end


    #
    # Adds a manual constraint in native lp format
    #
    def add_constraint(constraint_def)
      @constraints << Constraint.new(constraint_def)
    end


    #
    # Make sure every element in the subset is matched
    #
    def match_all(elts, options={})
      subset = @variable_set.create_subset(elts)
      add_constraint(
        :vars => subset.to_lp_vars,
        :operator => '=',
        :target => subset.size,
        :name => options[:name]
      )
    end

    #
    # Match some exact number of elements from the subset
    #
    def match_exactly(elts, target, options={})
      subset = @variable_set.create_subset(elts)
      add_constraint(
        :vars => subset.to_lp_vars,
        :operator => '=',
        :target => target,
        :name => options[:name]
      )
    end


    #
    # Match some exact number of elements from the subset
    #
    def match_at_least(elts, target, options={})
      subset = @variable_set.create_subset(elts)
      add_constraint(
        {:vars => subset.to_lp_vars,
        :operator => '>=',
        :target => target}.merge(options)
      )
    end


    #
    # Match some exact number of elements from the subset
    #
    def match_at_most(elts, target, options={})
      subset = @variable_set.create_subset(elts)
      add_constraint(
        :vars => subset.to_lp_vars,
        :operator => '>=',
        :target => target,
        :name => options[:name]
      )
    end


    #
    # Takes in a set of vectors which will compose a matrix of illegal
    # combinations
    #
    def add_exclusion_constraint(vectors, options = {})
      subset = @variable_set.create_subset(vectors)
      if !subset.empty?
        constraint_hash = {
          :vars => subset.to_lp_vars,
          :operator => '=',
          :target => 0
        }
        constraint_hash[:name] = options[:name] if options.has_key?(:name)
        @constraints << Constraint.new(constraint_hash)
      end
    end


    #
    # Run the match with current constraints
    #
    def match
      # Set up initial variables
      lp = LPSelect.new(:vars => inclusion_vars)
      lp.set_objective(compose_objective)

      # Add whatever constraints have been placed
      constraints.each do |c|
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

      @objective.each do |obj,weight|
        objective["v#{@variable_set.set_indices[obj]}"] = weight
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
      @constraints + extra_constraints
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