require 'spec_helper'

RSpec.describe "CounterCulture dynamic column_name" do
  it "increments dynamic counter cache on create" do
    user = User.create
    product = Product.create

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(0)

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(1)
  end

  it "decrements dynamic counter cache on destroy" do
    user = User.create
    product = Product.create

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(0)

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(1)

    review_tried.destroy

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(0)

    review_using.destroy

    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)
  end
end
