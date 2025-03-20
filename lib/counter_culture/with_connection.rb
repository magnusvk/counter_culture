module CounterCulture
  class WithConnection
    def initialize(recipient)
      @recipient = recipient
    end

    attr_reader :recipient

    def call(reading: false)
      if rails_7_1_or_greater?
        use_read_replica = CounterCulture.configuration.use_read_replica && reading
        role = use_read_replica ? :reading : :writing

        ActiveRecord::Base.connected_to(role: role) do
          yield_with_connection { |conn| yield conn }
        end
      else
        # For older Rails versions, just use normal connection
        yield_with_connection { |conn| yield conn }
      end
    end

    private

    def yield_with_connection
      if rails_7_2_or_greater?
        recipient.with_connection { |conn| yield conn }
      elsif rails_7_1?
        recipient.connection_pool.with_connection { |conn| yield conn }
      else
        yield recipient.connection
      end
    end

    def rails_7_1_or_greater?
      Gem::Requirement.new('>= 7.1.0').satisfied_by?(ActiveRecord.version)
    end

    def rails_7_2_or_greater?
      Gem::Requirement.new('>= 7.2.0').satisfied_by?(ActiveRecord.version)
    end

    def rails_7_1?
      Gem::Requirement.new('~> 7.1.0').satisfied_by?(ActiveRecord.version)
    end
  end
end
