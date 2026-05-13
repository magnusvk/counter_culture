require 'spec_helper'

RSpec.describe "conditional counts on update" do
  let(:product) {Product.create!}
  let(:user) {User.create!}

  it "should increment and decrement if changing column name" do
    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => "using"
    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(0)

    review.review_type = "tried"
    review.save!

    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(1)
  end

  it "should increment if changing from a nil column name" do
    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil
    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review.review_type = "tried"
    review.save!

    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(1)
  end

  it "should decrement if changing column name to nil" do
    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => "using"
    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(0)

    review.review_type = nil
    review.save!

    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)
  end

  it "should decrement if changing column name to nil without errors using default scope" do
    User.with_default_scope do
      expect(user.using_count).to eq(0)
      expect(user.tried_count).to eq(0)

      review = Review.create(
        user_id: user.id,
        product_id: product.id,
        review_type: 'using'
      )

      user.reload

      expect(user.using_count).to eq(1)
      expect(user.tried_count).to eq(0)

      review.review_type = nil
      review.save!

      user.reload

      expect(user.using_count).to eq(0)
      expect(user.tried_count).to eq(0)
    end
  end
end
