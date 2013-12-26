#
# Variable Collection provide methods for accessing variables as well as
# methods for outputting those variables for consumption by LPSolve
#
module MassiveMatch
  class Constraint
    attr_accessor :name, :vars, :operator, :target

    OPERATOR_MAP = {
      '='  => LPSelect::EQ,
      '<=' => LPSelect::LE,
      '>=' => LPSelect::GE
    }

    class << self
      #
      # Give a constraint a unique name
      #
      def stamp_name!(constraint)
        @@constraint_idx = 0 unless defined?(@@constraint_idx)
        constraint.name = "constraint#{@@constraint_idx}"
        @@constraint_idx += 1
      end
    end

    #
    # Takes in a hash with the following arguments:
    #
    # :vars     : LPSolve variable name to constrain
    # :operator : '=', '>=', or '<='
    # :target   : integer to operate on
    #
    def initialize(args = {})
      Constraint.stamp_name!(self)
      @vars = args[:vars]
      @operator = OPERATOR_MAP[args[:operator]]
      @target = args[:target]
    end

    #
    # Format for consumption by LPSolve
    #
    def to_lp_arg
      {
        :name   => name,
        :target => target,
        :op     => operator,
        :vars   => vars
      }
    end

  end

end