require 'spec_helper'

RSpec.describe "CounterCulture with float column totals" do
  it "should correctly sum up float values" do
    user = User.create

    r1 = Review.create :user_id => user.id, :value => 3.4

    user.reload
    expect(user.review_value_sum.round(1)).to eq(3.4)

    r2 = Review.create :user_id => user.id, :value => 7.2

    user.reload
    expect(user.review_value_sum.round(1)).to eq(10.6)

    r3 = Review.create :user_id => user.id, :value => 5

    user.reload
    expect(user.review_value_sum.round(1)).to eq(15.6)

    r2.destroy

    user.reload
    expect(user.review_value_sum.round(1)).to eq(8.4)

    r3.destroy

    user.reload
    expect(user.review_value_sum.round(1)).to eq(3.4)

    r1.destroy

    user.reload
    expect(user.review_value_sum.round(1)).to eq(0)
  end

  it "should correctly fix float values that came out of sync" do
    user = User.create

    r1 = Review.create :user_id => user.id, :value => 3.4
    r2 = Review.create :user_id => user.id, :value => 7.2
    r3 = Review.create :user_id => user.id, :value => 5

    user.update_column(:review_value_sum, 0)
    Review.counter_culture_fix_counts skip_unsupported: true

    user.reload
    expect(user.review_value_sum.round(1)).to eq(15.6)

    r2.destroy

    user.update_column(:review_value_sum, 0)
    Review.counter_culture_fix_counts skip_unsupported: true

    user.reload
    expect(user.review_value_sum.round(1)).to eq(8.4)

    r3.destroy

    user.update_column(:review_value_sum, 0)
    Review.counter_culture_fix_counts skip_unsupported: true

    user.reload
    expect(user.review_value_sum.round(1)).to eq(3.4)

    r1.destroy

    user.update_column(:review_value_sum, 0)
    Review.counter_culture_fix_counts skip_unsupported: true

    user.reload
    expect(user.review_value_sum.round(1)).to eq(0)
  end
end
