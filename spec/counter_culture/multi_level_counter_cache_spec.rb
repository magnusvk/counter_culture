require 'spec_helper'

RSpec.describe "CounterCulture multi-level and dynamic counter caches" do
  it "increments third-level counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.reviews_count).to eq(0)
    expect(industry.review_approvals_count).to eq(0)
    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42

    industry.reload
    company.reload
    user.reload
    product.reload

    expect(industry.reviews_count).to eq(1)
    expect(industry.review_approvals_count).to eq(42)
    expect(company.reviews_count).to eq(1)
    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
  end

  it "decrements third-level counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.reviews_count).to eq(0)
    expect(industry.review_approvals_count).to eq(0)
    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42

    industry.reload
    company.reload
    user.reload
    product.reload

    expect(industry.reviews_count).to eq(1)
    expect(industry.review_approvals_count).to eq(42)
    expect(company.reviews_count).to eq(1)
    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)

    review.destroy

    industry.reload
    company.reload
    user.reload
    product.reload

    expect(industry.reviews_count).to eq(0)
    expect(industry.review_approvals_count).to eq(0)
    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
  end

  it "updates third-level counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    expect(industry1.reviews_count).to eq(0)
    expect(industry2.reviews_count).to eq(0)
    expect(company1.reviews_count).to eq(0)
    expect(company2.reviews_count).to eq(0)
    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(0)
    expect(industry1.review_approvals_count).to eq(0)
    expect(industry2.review_approvals_count).to eq(0)

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 42

    industry1.reload
    industry2.reload
    company1.reload
    company2.reload
    user1.reload
    user2.reload

    expect(industry1.reviews_count).to eq(1)
    expect(industry2.reviews_count).to eq(0)
    expect(company1.reviews_count).to eq(1)
    expect(company2.reviews_count).to eq(0)
    expect(user1.reviews_count).to eq(1)
    expect(user2.reviews_count).to eq(0)
    expect(industry1.review_approvals_count).to eq(42)
    expect(industry2.review_approvals_count).to eq(0)

    review.user = user2
    review.save!

    industry1.reload
    industry2.reload
    company1.reload
    company2.reload
    user1.reload
    user2.reload

    expect(industry1.reviews_count).to eq(0)
    expect(industry2.reviews_count).to eq(1)
    expect(company1.reviews_count).to eq(0)
    expect(company2.reviews_count).to eq(1)
    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(1)
    expect(industry1.review_approvals_count).to eq(0)
    expect(industry2.review_approvals_count).to eq(42)

    review.update_attribute(:approvals, 69)
    expect(industry2.reload.review_approvals_count).to eq(69)
  end

  it "increments third-level custom counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id

    industry.reload

    expect(industry.rexiews_count).to eq(1)
  end

  it "decrements third-level custom counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id

    industry.reload
    expect(industry.rexiews_count).to eq(1)

    review.destroy

    industry.reload
    expect(industry.rexiews_count).to eq(0)
  end

  it "updates third-level custom counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    expect(industry1.rexiews_count).to eq(0)
    expect(industry2.rexiews_count).to eq(0)

    review = Review.create :user_id => user1.id, :product_id => product.id

    industry1.reload
    expect(industry1.rexiews_count).to eq(1)
    industry2.reload
    expect(industry2.rexiews_count).to eq(0)

    review.user = user2
    review.save!

    industry1.reload
    expect(industry1.rexiews_count).to eq(0)
    industry2.reload
    expect(industry2.rexiews_count).to eq(1)
  end

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

  it "increments third-level dynamic counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.using_count).to eq(0)
    expect(industry.tried_count).to eq(0)

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    industry.reload

    expect(industry.using_count).to eq(1)
    expect(industry.tried_count).to eq(0)

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    industry.reload

    expect(industry.using_count).to eq(1)
    expect(industry.tried_count).to eq(1)
  end

  it "decrements third-level custom counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(industry.using_count).to eq(0)
    expect(industry.tried_count).to eq(0)

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    industry.reload

    expect(industry.using_count).to eq(1)
    expect(industry.tried_count).to eq(0)

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    industry.reload

    expect(industry.using_count).to eq(1)
    expect(industry.tried_count).to eq(1)

    review_tried.destroy

    industry.reload

    expect(industry.using_count).to eq(1)
    expect(industry.tried_count).to eq(0)

    review_using.destroy

    industry.reload

    expect(industry.using_count).to eq(0)
    expect(industry.tried_count).to eq(0)
  end

  it "updates third-level custom counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    expect(industry1.using_count).to eq(0)
    expect(industry1.tried_count).to eq(0)
    expect(industry2.using_count).to eq(0)
    expect(industry2.tried_count).to eq(0)

    review_using = Review.create :user_id => user1.id, :product_id => product.id, :review_type => 'using'

    industry1.reload
    industry2.reload

    expect(industry1.using_count).to eq(1)
    expect(industry1.tried_count).to eq(0)
    expect(industry2.using_count).to eq(0)
    expect(industry2.tried_count).to eq(0)

    review_tried = Review.create :user_id => user1.id, :product_id => product.id, :review_type => 'tried'

    industry1.reload
    industry2.reload

    expect(industry1.using_count).to eq(1)
    expect(industry1.tried_count).to eq(1)
    expect(industry2.using_count).to eq(0)
    expect(industry2.tried_count).to eq(0)

    review_tried.user = user2
    review_tried.save!

    industry1.reload
    industry2.reload

    expect(industry1.using_count).to eq(1)
    expect(industry1.tried_count).to eq(0)
    expect(industry2.using_count).to eq(0)
    expect(industry2.tried_count).to eq(1)

    review_using.user = user2
    review_using.save!

    industry1.reload
    industry2.reload

    expect(industry1.using_count).to eq(0)
    expect(industry1.tried_count).to eq(0)
    expect(industry2.using_count).to eq(1)
    expect(industry2.tried_count).to eq(1)
  end
end
