require 'spec_helper'

RSpec.describe CounterCulture::Configuration do
  after(:each) do
    CounterCulture.reset_configuration
  end

  describe '.configure' do
    it 'works according to the Rails version' do
      if Gem::Requirement.new('>= 7.1.0').satisfied_by?(ActiveRecord.version)
        CounterCulture.configure do |config|
          config.use_read_replica = true
        end

        expect(CounterCulture.configuration.use_read_replica).to be true
      else
        expect {
          CounterCulture.configure do |config|
            config.use_read_replica = true
          end
        }.to raise_error("Counter Culture's read replica support requires Rails 7.1 or higher")
      end
    end

    it 'defaults to false' do
      expect(CounterCulture.configuration.use_read_replica).to be false
    end
  end

  describe '.reset_configuration' do
    before do
      allow_any_instance_of(CounterCulture::Configuration)
        .to receive(:rails_supports_read_replica?)
        .and_return(true)
    end

    it 'resets to default values' do
      CounterCulture.configure do |config|
        config.use_read_replica = true
      end

      CounterCulture.reset_configuration

      expect(CounterCulture.configuration.use_read_replica).to be false
    end
  end
end
