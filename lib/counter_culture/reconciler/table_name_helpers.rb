module CounterCulture
  class Reconciler
    module TableNameHelpers
      def parameterize(string)
        if ACTIVE_RECORD_VERSION < Gem::Version.new("5.0")
          string.parameterize('_')
        else
          string.parameterize(separator: '_')
        end
      end
    end
  end
end
