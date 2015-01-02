require 'tempfile'

module MassiveMatch
  class NoOptimalSolution < Exception; end

  KERNEL_TYPE = `uname -s`.split("\n").first
  LP_SOLVE = File.expand_path("../../binaries/lp_solve_#{KERNEL_TYPE.downcase}", __FILE__)

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
      @set_options = {}.tap{|out| sets.keys.each{|k| out[k] ={}}}
      @variable_set = VariableSet.new(sets)
      @constraints = []
      @matches_per_element = {}
      @inclusion_composers = nil
      @inclusion_vars = nil
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
    # Adds a subset as an inclusion set. Inclusion sets are unioned upon solve
    # time to create a variable matrix which contains each possible tuple.
    #
    # A weight can be optionally added, with lower weights being preferred over
    # higher weights on solve. Weights may also be expressed as a range, with
    # a random value from the range being assigned to any given element.
    #
    # Elements assigned multiple weights are currently will have those weights
    # summed.
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
    def exclude_on_markers(marker_hashes, options = {})
      # reindex
      objects_by_marker = reindex_by_marker(marker_hashes)

      # iterate over combinations
      objects_by_marker.each do |marker,marked_hashes|
        marked_sets = marked_hashes.to_a
        until marked_sets.size == 1
          o_name, o_set = marked_sets.pop
          marked_sets.each do |i_name,iter_hash|
            add_exclusion_constraint({o_name => o_set, i_name => iter_hash}, options)
          end
        end
      end
    end

    def include_on_markers(marker_hashes, options = {})
      # reindex
      objects_by_marker = reindex_by_marker(marker_hashes)

      # iterate over combinations
      objects_by_marker.each do |marker,marked_hashes|
        marked_sets = marked_hashes.to_a
        until marked_sets.size == 1
          o_name, o_set = marked_sets.pop
          marked_sets.each do |i_name,iter_hash|
            add_inclusion_composer({o_name => o_set, i_name => iter_hash}, options)
          end
        end
      end
    end


    #
    # Match some exact number of elements from the subset
    #
    def match_exactly(vectors, target, options={})
      match_some(vectors, target, options.merge(operator: '='))
    end


    #
    # Match some exact number of elements from the subset
    #
    def match_at_least(vectors, target, options={})
      match_some(vectors, target, options.merge(operator: '>='))
    end


    #
    # Match some exact number of elements from the subset
    #
    def match_at_most(vectors, target, options={})
      match_some(vectors, target, options.merge(operator: '<='))
    end


    #
    # Generic matcher
    #
    def match_some(vectors, target, options={})
      options = {target: target}.merge(options)

      expand_vectors(vectors).each do |expanded_vector|
        subset = @variable_set.create_subset(expanded_vector)
        add_constraint({vars: subset.to_lp_vars}.merge(options))
      end
    end


    #
    # Run the match with current constraints
    #
    def match
      file = Tempfile.new('massive_match')

      # Step 1: Compose the equation -- objective and constraints get
      #         calculated and formatted quietly in here
      #

      # objective
      obj_str = objective.map{|var, weight| "+#{weight} #{var}"}
      file.write("min: #{obj_str.join(" ")};\n")

      # constraints
      file.write(constraints.map(&:to_lp_arg).join("\n")+"\n\n")

      # variable must be either 0 or 1 (not selected or selected)
      file.write(inclusion_vars.map{|v| "#{v} <= 1;"}.join("\n"))

      # Step 2: Pipe the equation over to lp_solve
      #
      file.rewind
      lp_results = `#{LP_SOLVE} #{file.path}`

      # Step 3: Retrieve and parse the results
      #
      results = parse_lp_results(lp_results)
    end



  private
    #
    # Parse results from lp_solve
    #
    def parse_lp_results(results)
      infeasible_matcher = /This problem is infeasible/
      result_matcher = /^(v[\dx]+) +1$/

      raise NoOptimalSolution, "No optimal solution or empty result set" if infeasible_matcher.match(results)

      lp_vars = results.scan(result_matcher).map do |result|
        @variable_set[result.first]
      end
    end


    #
    # Handles such things as vectors expressed as enumerators, returns an array
    # of extracted vectors
    #
    def expand_vectors(vectors)
      return [vectors] unless vectors.any?{|k,v| v.is_a?(Enumerator)}

      vectors.reduce([{}]) do |memo, (set, vector)|
        # expand out enumerators if needed
        to_merge = vector.is_a?(Enumerator) ?
          vector.map { |v_elt| {set => [v_elt]} } :
          [{set => vector}]

        # cross the incoming vectors with what we've accumulated
        to_merge.map do |m|
          memo.map { |lm| m.merge(lm) }
        end.flatten
      end
    end


    #
    # Composes the objective function
    #
    def objective
      objective = {}
      composers = @inclusion_composers || {1 => [@variable_set]}
      composers.each do |weight,weighted_sets|
        weighted_sets.each do |set|
          cycler = (weight.is_a?(Range) ? weight : [weight]).cycle
          set.to_lp_vars.shuffle.each do |var|
            w = cycler.next
            objective[var] ||= 0
            objective[var] += w
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

      # Apply inclusion vars if needed
      @constraints.each{|c| c.vars &= inclusion_vars} if @inclusion_composers

      # Add object-wide constraints
      @sets.each do |set_name,set|
        next unless @set_options[set_name][:num_matches]
        num_matches = @set_options[set_name][:num_matches]
        match_padding = @set_options[set_name][:match_padding] || 0
        set.each do |elt|
          # create a subset of all vars attached to our element
          subset = @variable_set.create_subset(set_name => [elt])
          subset_vars = subset.to_lp_vars
          subset_vars &= inclusion_vars if @inclusion_composers

          # add that subset as a constraint
          if num_matches.is_a?(Integer)
            run_constraints << Constraint.new(
              :vars => subset_vars,
              :operator => '=',
              :target => [num_matches, subset_vars.size].min
            )
          elsif num_matches.is_a?(Range)
            run_constraints << Constraint.new(
              :vars => subset_vars,
              :operator => '>=',
              :target => [num_matches.min, subset_vars.size - match_padding].min
            )

            run_constraints << Constraint.new(
              :vars => subset_vars,
              :operator => '<=',
              :target => num_matches.max
            )
          else
            raise "Matches per element target must an Integer or a Range #{num_matches.inspect}"
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