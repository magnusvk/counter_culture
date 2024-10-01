module CounterCulture
  class WithConnection
    def initialize(recipient)
      @recipient = recipient
    end

    attr_reader :recipient

    def call
      if rails_7_2_or_greater?
        recipient.with_connection do |connection|
          yield connection
        end
      elsif rails_7_1?
        recipient.connection_pool.with_connection do |connection|
          yield connection
        end
      else
        yield recipient.connection
      end
    end

    private

    def rails_7_1?
      Gem::Requirement.new('~> 7.1.0').satisfied_by?(Gem::Version.new(Rails.version))
    end

    def rails_7_2_or_greater?
      Gem::Requirement.new('>= 7.2.0').satisfied_by?(Gem::Version.new(Rails.version))
    end
  end
end
