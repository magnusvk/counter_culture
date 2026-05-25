require 'spec_helper'

RSpec.describe "CounterCulture.skip_counter_culture_updates" do
  it "skips increments counter cache on create" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    Review.skip_counter_culture_updates do
      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13
    end

    user.reload
    product.reload

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
  end

  it "skips increments counter cache on create - nested" do
    user = User.create
    category = Category.create

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(category.products_count).to eq(0)

    Product.skip_counter_culture_updates do
      Review.skip_counter_culture_updates do
        product = category.products.create
        user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13
      end
    end

    user.reload
    category.reload

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(category.products_count).to eq(0)

    product = category.products.create
    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    user.reload
    category.reload

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
    expect(category.products_count).to eq(1)
  end

  it "skips increments counter cache on update" do
    user = User.create
    review = user.reviews.create :approvals => 13

    user.reload

    expect(user.review_approvals_count).to eq(13)

    Review.skip_counter_culture_updates do
      review.update :approvals => 26
    end

    user.reload

    expect(user.review_approvals_count).to eq(13)

    review.update :approvals => 39

    user.reload

    expect(user.review_approvals_count).to eq(26)
  end

  it "skips increments counter cache on destroy" do
    user = User.create
    product = Product.create
    2.times { user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13 }

    user.reload
    product.reload

    expect(user.reviews_count).to eq(2)
    expect(product.reviews_count).to eq(2)
    expect(user.review_approvals_count).to eq(26)

    Review.skip_counter_culture_updates do
      user.reviews.last.destroy
    end

    user.reload
    product.reload

    expect(user.reviews_count).to eq(2)
    expect(product.reviews_count).to eq(2)
    expect(user.review_approvals_count).to eq(26)

    user.reviews.last.destroy

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
  end
end
