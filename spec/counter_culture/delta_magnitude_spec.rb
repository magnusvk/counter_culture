require 'spec_helper'

RSpec.describe "CounterCulture delta_magnitude" do
  it "correctly handles dynamic delta magnitude" do
    user = User.create
    product = Product.create

    review_heavy = Review.create(
      :user_id => user.id,
      :review_type => 'using',
      :product_id => product.id,
      :heavy => true,
    )
    user.reload
    expect(user.dynamic_delta_count).to eq(2)

    review_light = Review.create(
      :user_id => user.id,
      :product_id => product.id,
      :review_type => 'using',
      :heavy => false,
    )
    user.reload
    expect(user.dynamic_delta_count).to eq(3)

    review_heavy.destroy
    user.reload
    expect(user.dynamic_delta_count).to eq(1)

    review_light.destroy
    user.reload
    expect(user.dynamic_delta_count).to eq(0)
  end

  it "correctly handles non-dynamic custom delta magnitude" do
    user = User.create
    product = Product.create

    review1 = Review.create(
      :user_id => user.id,
      :review_type => 'using',
      :product_id => product.id
    )
    user.reload
    expect(user.custom_delta_count).to eq(3)

    review2 = Review.create(
      :user_id => user.id,
      :review_type => 'using',
      :product_id => product.id
    )
    user.reload
    expect(user.custom_delta_count).to eq(6)

    review1.destroy
    user.reload
    expect(user.custom_delta_count).to eq(3)

    review2.destroy
    user.reload
    expect(user.custom_delta_count).to eq(0)
  end
end
