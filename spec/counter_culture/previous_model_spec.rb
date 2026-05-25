require 'spec_helper'

RSpec.describe "CounterCulture#previous_model" do
  let(:user){User.create :name => "John Smith", :manages_company_id => 1}

  it "should return a copy of the original model" do
    user.name = "Joe Smith"
    user.manages_company_id = 2
    user.save!

    prev = CounterCulture::Counter.new(user, :foobar, {}).previous_model(user)

    expect(prev.name).to eq("John Smith")
    expect(prev.manages_company_id).to eq(1)

    expect(user.name).to eq("Joe Smith")
    expect(user.manages_company_id).to eq(2)
  end
end
