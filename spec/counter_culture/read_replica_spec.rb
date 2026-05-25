require 'spec_helper'

RSpec.describe "CounterCulture with read replica configuration" do
  after(:each) do
    CounterCulture.reset_configuration
  end

  let(:company) { Company.create! }

  before do
    company.children << Company.create!
    company.update_column(:children_count, -1)
  end

  context "with Rails 7.1+" do
    before do
      allow_any_instance_of(CounterCulture::WithConnection)
        .to receive(:rails_7_1_or_greater?)
        .and_return(true)
      allow_any_instance_of(CounterCulture::Configuration)
        .to receive(:rails_supports_read_replica?)
        .and_return(true)
    end

    it "uses read replica when enabled" do
      CounterCulture.configure do |config|
        config.use_read_replica = true
      end

      roles_used = []
      allow(ActiveRecord::Base).to receive(:connected_to).and_wrap_original do |original, **kwargs, &block|
        roles_used << kwargs[:role]
        block.call if block
      end

      Company.counter_culture_fix_counts

      expect(roles_used).to include(:reading)
      expect(roles_used - [:reading]).to all(eq(:writing))
    end

    it "does not use read replica when disabled" do
      CounterCulture.configure do |config|
        config.use_read_replica = false
      end

      roles_used = []
      allow(ActiveRecord::Base).to receive(:connected_to).and_wrap_original do |original, **kwargs, &block|
        roles_used << kwargs[:role]
        block.call if block
      end

      Company.counter_culture_fix_counts

      expect(roles_used).to include(:writing)
    end
  end

  context "with Rails < 7.1" do
    before do
      allow_any_instance_of(CounterCulture::WithConnection)
        .to receive(:rails_7_1_or_greater?)
        .and_return(false)
      allow_any_instance_of(CounterCulture::Configuration)
        .to receive(:rails_supports_read_replica?)
        .and_return(false)
    end

    it "works without read replica support" do
      # Should raise error when trying to enable read replica
      expect {
        CounterCulture.configure do |config|
          config.use_read_replica = true
        end
      }.to raise_error("Counter Culture's read replica support requires Rails 7.1 or higher")

      # Should not use connected_to at all
      expect(ActiveRecord::Base).not_to receive(:connected_to)

      Company.counter_culture_fix_counts
      expect(company.reload.children_count).to eq(1)
    end
  end

  context "with db_connection_builder option" do
    before do
      SimpleDependent.delete_all
      SimpleMain.delete_all

      5.times do
        main = SimpleMain.create
        3.times { main.simple_dependents.create }
      end
    end

    it "should request a reading and not a writing database connection" do
      # Counts are correct at this point so no update should happen

      requested_reading_connection = false
      requested_writing_connection = false
      SimpleDependent.counter_culture_fix_counts db_connection_builder: lambda{|reading, block|
        if reading
          requested_reading_connection = true
        else
          requested_writing_connection = true
        end
        block.call
      }
      expect(requested_reading_connection).to be(true)
      expect(requested_writing_connection).to be(false)
    end

    it "should request a reading and a writing database connection" do
      # Damage the counts so an update happens
      SimpleMain.update_all(simple_dependents_count: -1)

      requested_reading_connection = false
      requested_writing_connection = false
      SimpleDependent.counter_culture_fix_counts db_connection_builder: lambda{|reading, block|
        if reading
          requested_reading_connection = true
        else
          requested_writing_connection = true
        end
        block.call
      }
      expect(requested_reading_connection).to be(true)
      expect(requested_writing_connection).to be(true)
    end
  end
end
