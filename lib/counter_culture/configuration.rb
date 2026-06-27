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

  def self.supports_composite_keys?
    Gem::Requirement.new('>= 7.2.0').satisfied_by?(ActiveRecord.version)
  end

  # Rails 7.2+ ships `ActiveRecord.after_all_transactions_commit`, which lets
  # `execute_after_commit` defer counter updates natively instead of relying on
  # the `after_commit_action` gem.
  def self.supports_native_after_commit?
    Gem::Requirement.new('>= 7.2.0').satisfied_by?(ActiveRecord.version)
  end

  class Configuration
    attr_reader :use_read_replica

    def initialize
      @use_read_replica = false
    end

    def use_read_replica=(value)
      if value && !rails_supports_read_replica?
        raise "Counter Culture's read replica support requires Rails 7.1 or higher"
      end
      @use_read_replica = value
    end

    private

    def rails_supports_read_replica?
      Gem::Requirement.new('>= 7.1.0').satisfied_by?(ActiveRecord.version)
    end
  end
end
