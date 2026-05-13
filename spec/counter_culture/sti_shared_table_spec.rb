require 'spec_helper'

# Test for Rails 8.1+ UPDATE...FROM alias issue with STI models sharing a table
# See: https://github.com/magnusvk/counter_culture/issues/422
RSpec.describe "CounterCulture STI models sharing a table" do
  it "increments counter cache on create" do
    agreement = StiContract::Agreement.create!
    expect(agreement.contracts_count).to eq(0)

    contract = StiContract::Base.create!(agreement: agreement)

    agreement.reload
    expect(agreement.contracts_count).to eq(1)
  end

  it "decrements counter cache on destroy" do
    agreement = StiContract::Agreement.create!
    contract = StiContract::Base.create!(agreement: agreement)

    agreement.reload
    expect(agreement.contracts_count).to eq(1)

    contract.destroy
    agreement.reload
    expect(agreement.contracts_count).to eq(0)
  end

  it "updates counter cache when changing association" do
    agreement1 = StiContract::Agreement.create!
    agreement2 = StiContract::Agreement.create!
    contract = StiContract::Base.create!(agreement: agreement1)

    agreement1.reload
    expect(agreement1.contracts_count).to eq(1)
    expect(agreement2.contracts_count).to eq(0)

    contract.update!(agreement: agreement2)

    agreement1.reload
    agreement2.reload
    expect(agreement1.contracts_count).to eq(0)
    expect(agreement2.contracts_count).to eq(1)
  end

  it "works with aggregate_counter_updates" do
    agreement = StiContract::Agreement.create!
    expect(agreement.contracts_count).to eq(0)

    CounterCulture.aggregate_counter_updates do
      StiContract::Base.create!(agreement: agreement)
      StiContract::Base.create!(agreement: agreement)
    end

    agreement.reload
    expect(agreement.contracts_count).to eq(2)
  end
end
