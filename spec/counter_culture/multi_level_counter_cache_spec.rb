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

  it "works correctly with a has_one association in the middle" do
    candidate_profile1 = CandidateProfile.create(candidate: Candidate.create)
    candidate1 = candidate_profile1.candidate
    candidate_profile2 = CandidateProfile.create(candidate: Candidate.create)
    candidate2 = candidate_profile2.candidate

    expect(candidate_profile1.conversations_count).to eq(0)
    expect(candidate_profile2.conversations_count).to eq(0)

    conversation1 = Conversation.create(candidate: candidate1)
    expect(candidate_profile1.reload.conversations_count).to eq(1)

    conversation2 = Conversation.create(candidate: candidate2)
    expect(candidate_profile2.reload.conversations_count).to eq(1)

    conversation2.candidate = candidate1
    conversation2.save!

    expect(candidate_profile1.reload.conversations_count).to eq(2)
    expect(candidate_profile2.reload.conversations_count).to eq(0)

    candidate_profile1.update_column(:conversations_count, 99)
    candidate_profile2.update_column(:conversations_count, 99)

    Conversation.counter_culture_fix_counts

    expect(candidate_profile1.reload.conversations_count).to eq(2)
    expect(candidate_profile2.reload.conversations_count).to eq(0)

    conversation2.destroy
    expect(candidate_profile1.reload.conversations_count).to eq(1)
    expect(candidate_profile2.reload.conversations_count).to eq(0)

    conversation1.destroy
    expect(candidate_profile1.reload.conversations_count).to eq(0)
    expect(candidate_profile2.reload.conversations_count).to eq(0)
  end

  it "increments second-level counter cache on create" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(company.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 314

    company.reload
    user.reload
    product.reload

    expect(company.reviews_count).to eq(1)
    expect(company.review_approvals_count).to eq(314)
    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
  end

  it "decrements second-level counter cache on destroy" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(company.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 314

    user.reload
    product.reload
    company.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(company.reviews_count).to eq(1)
    expect(company.review_approvals_count).to eq(314)

    review.destroy

    user.reload
    product.reload
    company.reload

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(company.reviews_count).to eq(0)
    expect(company.review_approvals_count).to eq(0)
  end

  it "updates second-level counter cache on update" do
    company1 = Company.create
    company2 = Company.create
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(0)
    expect(company1.reviews_count).to eq(0)
    expect(company2.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(company1.review_approvals_count).to eq(0)
    expect(company2.review_approvals_count).to eq(0)

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 69

    user1.reload
    user2.reload
    company1.reload
    company2.reload
    product.reload

    expect(user1.reviews_count).to eq(1)
    expect(user2.reviews_count).to eq(0)
    expect(company1.reviews_count).to eq(1)
    expect(company2.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(1)
    expect(company1.review_approvals_count).to eq(69)
    expect(company2.review_approvals_count).to eq(0)

    review.user = user2
    review.save!

    user1.reload
    user2.reload
    company1.reload
    company2.reload
    product.reload

    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(1)
    expect(company1.reviews_count).to eq(0)
    expect(company2.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(company1.review_approvals_count).to eq(0)
    expect(company2.review_approvals_count).to eq(69)

    review.update_attribute(:approvals, 42)
    expect(company2.reload.review_approvals_count).to eq(42)
  end
end
