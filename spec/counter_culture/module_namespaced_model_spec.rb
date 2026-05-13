require 'spec_helper'

RSpec.describe "CounterCulture with a module for the model" do
  it "works" do
    model2 = WithModule::Model2.create!
    5.times { WithModule::Model1.create!(model2: model2) }

    model2.reload
    expect(model2.model1s_count).to eq(5)

    model2.update_column(:model1s_count, -1)

    WithModule::Model1.counter_culture_fix_counts

    model2.reload
    expect(model2.model1s_count).to eq(5)
  end
end
