#
# Results encapsulate matches and provide two ways of extracting results, based
# on block arity.
#
module MassiveMatch
  class Result
    include Enumerable

    attr_reader :results

    # results are an array of hashes
    def initialize(results)
      @results = results
    end

    # doesn't work as expected yet, see: https://bugs.ruby-lang.org/issues/10684
    def each(&block)
      if block.arity == 1 || true  #(hack until above works)
        @results.each(&block)
      else
        @results.each do |r|
          yield *r.values
        end
      end
    end

    def detect(&block)
      each(&block)
    end

    def method_missing(meth)
      @results.send(meth)
    end

  end
end