require 'spec_helper'

RSpec.describe "CounterCulture with read replica configuration" do
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
end
