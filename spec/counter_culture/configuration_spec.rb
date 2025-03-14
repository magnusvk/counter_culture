require 'spec_helper'

RSpec.describe CounterCulture::Configuration do
  after(:each) do
    CounterCulture.reset_configuration
  end

  describe '.configure' do
    it 'allows setting use_read_replica' do
      CounterCulture.configure do |config|
        config.use_read_replica = true
      end

      expect(CounterCulture.configuration.use_read_replica).to be true
    end

    it 'defaults to false' do
      expect(CounterCulture.configuration.use_read_replica).to be false
    end
  end

  describe '.reset_configuration' do
    it 'resets to default values' do
      CounterCulture.configure do |config|
        config.use_read_replica = true
      end

      CounterCulture.reset_configuration

      expect(CounterCulture.configuration.use_read_replica).to be false
    end
  end
end
