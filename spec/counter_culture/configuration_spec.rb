require 'spec_helper'

RSpec.describe CounterCulture::Configuration do
  after(:each) do
    CounterCulture.reset_configuration
  end

  describe '.configure' do
    context 'when Rails version is >= 6.1' do
      before do
        allow_any_instance_of(CounterCulture::Configuration)
          .to receive(:rails_supports_read_replica?)
          .and_return(true)
      end

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

    context 'when Rails version is < 6.1' do
      before do
        allow_any_instance_of(CounterCulture::Configuration)
          .to receive(:rails_supports_read_replica?)
          .and_return(false)
      end

      it 'raises error when setting use_read_replica to true' do
        expect {
          CounterCulture.configure do |config|
            config.use_read_replica = true
          end
        }.to raise_error("Counter Culture's read replica support requires Rails 6.1 or higher")
      end
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
