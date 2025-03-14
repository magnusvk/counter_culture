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
    attr_accessor :use_read_replica

    def initialize
      @use_read_replica = false
    end
  end
end
