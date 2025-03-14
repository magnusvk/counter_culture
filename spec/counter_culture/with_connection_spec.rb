require 'spec_helper'

RSpec.describe CounterCulture::WithConnection do
  let(:model_class) { Class.new(ActiveRecord::Base) }
  let(:instance) { described_class.new(model_class) }

  before(:each) do
    CounterCulture.reset_configuration
  end

  describe '#call' do
    context 'when use_read_replica is enabled' do
      before do
        CounterCulture.configure { |config| config.use_read_replica = true }
      end

      it 'uses read replica for reading operations' do
        if ActiveRecord.version >= Gem::Version.new('7.2')
          expect(model_class).to receive(:connected_to).with(role: :reading)
        elsif ActiveRecord.version >= Gem::Version.new('7.1')
          expect(model_class.connection_handler).to receive(:while_preventing_writes).with(true)
        end

        instance.call(reading: true) { |conn| }
      end

      it 'uses primary database for writing operations' do
        if ActiveRecord.version >= Gem::Version.new('7.2')
          expect(model_class).not_to receive(:connected_to)
        elsif ActiveRecord.version >= Gem::Version.new('7.1')
          expect(model_class.connection_handler).not_to receive(:while_preventing_writes)
        end

        instance.call(reading: false) { |conn| }
      end
    end

    context 'when use_read_replica is disabled' do
      it 'always uses primary database' do
        if ActiveRecord.version >= Gem::Version.new('7.2')
          expect(model_class).not_to receive(:connected_to)
        elsif ActiveRecord.version >= Gem::Version.new('7.1')
          expect(model_class.connection_handler).not_to receive(:while_preventing_writes)
        end

        instance.call(reading: true) { |conn| }
      end
    end
  end
end
