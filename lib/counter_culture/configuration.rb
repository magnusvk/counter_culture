module CounterCulture
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  def self.reset_configuration
    @configuration = Configuration.new
  end

  class Configuration
    attr_reader :use_read_replica

    def initialize
      @use_read_replica = false
    end

    def use_read_replica=(value)
      if value && !rails_supports_read_replica?
        raise "Counter Culture's read replica support requires Rails 6.1 or higher"
      end
      @use_read_replica = value
    end

    private

    def rails_supports_read_replica?
      Gem::Requirement.new('>= 7.1.0').satisfied_by?(ActiveRecord.version)
    end
  end
end
