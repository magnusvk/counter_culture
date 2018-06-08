require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'models/company'
require 'models/industry'
require 'models/product'
require 'models/review'
require 'models/simple_review'
require 'models/twitter_review'
require 'models/user'
require 'models/category'
require 'models/has_string_id'
require 'models/simple_main'
require 'models/simple_dependent'
require 'models/conditional_main'
require 'models/conditional_dependent'
require 'models/post'
require 'models/post_comment'
require 'models/categ'
require 'models/subcateg'
require 'models/another_post'
require 'models/another_post_comment'
require 'models/person'
require 'models/transaction'
require 'models/soft_delete_discard'
require 'models/soft_delete_paranoia'
require 'models/conversation'
require 'models/candidate_profile'
require 'models/candidate'

require 'database_cleaner'
DatabaseCleaner.strategy = :deletion

describe "CounterCulture" do
  before(:each) do
    DatabaseCleaner.clean
  end

  it "should use relation foreign_key correctly" do
    post = AnotherPost.new
    comment = post.comments.build
    comment.comment = 'Comment'
    post.save!
    post.reload
    expect(post.another_post_comments_count).to eq(1)
  end

  it "should fix counts using relation foreign_key correctly" do
    post = AnotherPost.new
    comment = post.comments.build
    comment.comment = 'Comment'
    post.save!
    post.reload
    expect(post.another_post_comments_count).to eq(1)
    expect(post.comments.size).to eq(1)

    post.another_post_comments_count = 2
    post.save!

    fixed = AnotherPostComment.counter_culture_fix_counts
    expect(fixed.length).to eq(1)

    post.reload
    expect(post.another_post_comments_count).to eq(1)
  end

  it "increments counter cache on create" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
    expect(product.reviews_count).to eq(1)
  end

  it "decrements counter cache on destroy" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 69

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    review.destroy

    user.reload
    product.reload

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(0)
  end

  it "updates counter cache on update" do
    user1 = User.create
    user2 = User.create
    product = Product.create

    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user1.review_approvals_count).to eq(0)
    expect(user2.review_approvals_count).to eq(0)

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 42

    user1.reload
    user2.reload
    product.reload

    expect(user1.reviews_count).to eq(1)
    expect(user2.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(1)
    expect(user1.review_approvals_count).to eq(42)
    expect(user2.review_approvals_count).to eq(0)

    review.user = user2
    review.save!

    user1.reload
    user2.reload
    product.reload

    expect(user1.reviews_count).to eq(0)
    expect(user2.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user1.review_approvals_count).to eq(0)
    expect(user2.review_approvals_count).to eq(42)

    review.update_attribute(:approvals, 69)
    expect(user2.reload.review_approvals_count).to eq(69)
  end

  it "treats null delta column values as 0" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => nil

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(1)
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

  it "increments custom counter cache column on create" do
    user = User.create
    product = Product.create

    expect(product.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    expect(product.rexiews_count).to eq(1)
  end

  it "decrements custom counter cache column on destroy" do
    user = User.create
    product = Product.create

    expect(product.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    expect(product.rexiews_count).to eq(1)

    review.destroy

    product.reload

    expect(product.rexiews_count).to eq(0)
  end

  it "updates custom counter cache column on update" do
    user = User.create
    product1 = Product.create
    product2 = Product.create

    expect(product1.rexiews_count).to eq(0)
    expect(product2.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product1.id

    product1.reload
    product2.reload

    expect(product1.rexiews_count).to eq(1)
    expect(product2.rexiews_count).to eq(0)

    review.product = product2
    review.save!

    product1.reload
    product2.reload

    expect(product1.rexiews_count).to eq(0)
    expect(product2.rexiews_count).to eq(1)
  end

  it "handles nil column name in custom counter cache on create" do
    user = User.create
    product = Product.create

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil

    user.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)
  end

  it "handles nil column name in custom counter cache on destroy" do
    user = User.create
    product = Product.create

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil

    product.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)

    review.destroy

    product.reload

    expect(user.using_count).to eq(0)
    expect(user.tried_count).to eq(0)
  end

  it "handles nil column name in custom counter cache on update" do
    product = Product.create
    user1 = User.create
    user2 = User.create

    expect(user1.using_count).to eq(0)
    expect(user1.tried_count).to eq(0)
    expect(user2.using_count).to eq(0)
    expect(user2.tried_count).to eq(0)

    review = Review.create :user_id => user1.id, :product_id => product.id, :review_type => nil

    user1.reload
    user2.reload

    expect(user1.using_count).to eq(0)
    expect(user1.tried_count).to eq(0)
    expect(user2.using_count).to eq(0)
    expect(user2.tried_count).to eq(0)

    review.user = user2
    review.save!

    user1.reload
    user2.reload

    expect(user1.using_count).to eq(0)
    expect(user1.tried_count).to eq(0)
    expect(user2.using_count).to eq(0)
    expect(user2.tried_count).to eq(0)
  end

  describe "conditional counts on update" do
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
    end
  end

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

  it "should overwrite foreign-key values on create" do
    3.times { Category.create }
    Category.all {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| expect(category.products_count).to eq(1) }
  end

  it "should overwrite foreign-key values on destroy" do
    3.times { Category.create }
    Category.all {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| expect(category.products_count).to eq(1) }

    product.destroy
    Category.all {|category| expect(category.products_count).to eq(0) }
  end

  it "should overwrite foreign-key values on destroy" do
    3.times { Category.create }
    Category.all {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| expect(category.products_count).to eq(1) }

    product.category = nil
    product.save!
    Category.all {|category| expect(category.products_count).to eq(0) }
  end

  it "should not report correct counts when fix_counts is called" do
    user1 = User.create
    user2 = User.create

    review1 = Review.create user_id: user1.id, product: Product.create
    review2 = Review.create user_id: user2.id, product: Product.create

    user1.update_column :reviews_count, 2

    expect(Review.counter_culture_fix_counts(skip_unsupported: true)).to eq([{ entity: 'User', id: user1.id, what: 'reviews_count', right: 1, wrong: 2 }])
  end

  it 'should update the timestamp when fixing counts with `touch: true`' do
    product = Product.create
    review = Review.create product: product

    product.update_column :reviews_count, 2

    product.reload

    old_product_updated_at = product.updated_at

    Timecop.travel(1.second.from_now) do
      Review.counter_culture_fix_counts(skip_unsupported: true, only: :product, touch: true)

      product.reload

      expect(product.updated_at).to be > old_product_updated_at
    end
  end

  it 'should not update the timestamp when fixing counts without `touch: true`' do
    product = Product.create
    review = Review.create product: product

    product.update_column :reviews_count, 2

    product.reload

    old_product_updated_at = product.updated_at

    Timecop.travel(2.second.from_now) do
      Review.counter_culture_fix_counts(skip_unsupported: true, only: :product)

      product.reload

      expect(product.updated_at).to eq old_product_updated_at
    end
  end

  it 'should update the timestamp of a custom column when fixing counts with touch: rexiews_updated_at' do
    product = Product.create
    review = Review.create product: product

    product.update_column :rexiews_count, 2

    product.reload

    old_rexiews_updated_at = product.rexiews_updated_at

    Timecop.travel(1.second.from_now) do
      Review.counter_culture_fix_counts(skip_unsupported: true, touch: :rexiews_updated_at)

      product.reload

      expect(product.rexiews_updated_at).to be > old_rexiews_updated_at
    end
  end

  it "should fix a simple counter cache correctly" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 69

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    user.reviews_count = 0
    product.reviews_count = 2
    user.review_approvals_count = 7
    user.save!
    product.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    expect(fixed.length).to eq(3)

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)
  end

  it "should fix where the count should go back to zero correctly" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)

    user.reviews_count = -1
    user.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    expect(fixed.length).to eq(1)

    user.reload

    expect(user.reviews_count).to eq(0)

  end

  it "should fix a STI counter cache correctly" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(company.twitter_reviews_count).to eq(0)
    expect(product.twitter_reviews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42
    twitter_review = TwitterReview.create :user_id => user.id, :product_id => product.id, :approvals => 32

    company.reload
    user.reload
    product.reload

    expect(company.twitter_reviews_count).to eq(1)
    expect(product.twitter_reviews_count).to eq(1)

    company.twitter_reviews_count = 2
    product.twitter_reviews_count = 2
    company.save!
    product.save!

    TwitterReview.counter_culture_fix_counts :skip_unsupported => true

    company.reload
    product.reload

    expect(company.twitter_reviews_count).to eq(1)
    expect(product.twitter_reviews_count).to eq(1)
  end

  it "handles an inherited STI counter cache correctly" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create
    SimpleReview.create :user_id => user.id, :product_id => product.id
    product.reload
    expect(product.reviews_count).to eq(1)
    expect(product.simple_reviews_count).to eq(1)

    Review.create :user_id => user.id, :product_id => product.id
    product.reload
    expect(product.reviews_count).to eq(2)
    expect(product.simple_reviews_count).to eq(1)
  end

  it "should fix a second-level counter cache correctly" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    expect(company.reviews_count).to eq(0)
    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(company.review_approvals_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42

    company.reload
    user.reload
    product.reload

    expect(company.reviews_count).to eq(1)
    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(company.review_approvals_count).to eq(42)

    company.reviews_count = 2
    company.review_approvals_count = 7
    user.reviews_count = 3
    product.reviews_count = 4
    company.save!
    user.save!
    product.save!

    Review.counter_culture_fix_counts :skip_unsupported => true
    company.reload
    user.reload
    product.reload

    expect(company.reviews_count).to eq(1)
    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(company.review_approvals_count).to eq(42)
  end

  it "should fix a custom counter cache correctly" do
    user = User.create
    product = Product.create

    expect(product.rexiews_count).to eq(0)

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    expect(product.rexiews_count).to eq(1)

    product.rexiews_count = 2
    product.save!

    Review.counter_culture_fix_counts :skip_unsupported => true

    product.reload
    expect(product.rexiews_count).to eq(1)
  end

  it "should fix a dynamic counter cache correctly" do
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

    user.using_count = 2
    user.tried_count = 3
    user.save!

    Review.counter_culture_fix_counts :skip_unsupported => true

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(1)

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'null'

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(1)

    user.using_count = 2
    user.tried_count = 3
    user.save!

    Review.counter_culture_fix_counts :skip_unsupported => true

    user.reload

    expect(user.using_count).to eq(1)
    expect(user.tried_count).to eq(1)
  end

  it "should fix a string counter cache correctly" do
    string_id = HasStringId.create({:id => "bbb"})

    user = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(1)

    user2 = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(2)

    string_id.users_count = 123
    string_id.save!

    string_id.reload
    expect(string_id.users_count).to eq(123)

    User.counter_culture_fix_counts

    string_id.reload
    expect(string_id.users_count).to eq(2)
  end

  it "should fix a static delta magnitude column correctly" do
    user = User.create
    product = Product.create

    Review.create(
      :user_id => user.id,
      :review_type => 'using',
      :product_id => product.id
    )

    user.reload
    expect(user.custom_delta_count).to eq(3)

    user.update_attributes(:custom_delta_count => 5)

    Review.counter_culture_fix_counts(:skip_unsupported => true)

    user.reload
    expect(user.custom_delta_count).to eq(3)
  end

  it "should work correctly for relationships with custom names" do
    company = Company.create
    user1 = User.create :manages_company_id => company.id

    company.reload
    expect(company.managers_count).to eq(1)

    user2 = User.create :manages_company_id => company.id

    company.reload
    expect(company.managers_count).to eq(2)

    user2.destroy

    company.reload
    expect(company.managers_count).to eq(1)

    company2 = Company.create
    user1.manages_company_id = company2.id
    user1.save!

    company.reload
    expect(company.managers_count).to eq(0)
  end

  it "should work correctly with string keys" do
    skip("Unsupported in this version of Rails") if Rails.version < "4.0.0"

    string_id = HasStringId.create(id: "1")
    string_id2 = HasStringId.create(id: "abc")

    user = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(1)

    user2 = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(2)

    user2.has_string_id_id = string_id2.id
    user2.save!

    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(1)
    expect(string_id2.users_count).to eq(1)

    user2.destroy
    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(1)
    expect(string_id2.users_count).to eq(0)

    user.destroy
    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(0)
    expect(string_id2.users_count).to eq(0)
  end

  it "should raise a good error message when calling fix_counts with no caches defined" do
    expect { Category.counter_culture_fix_counts }.to raise_error "No counter cache defined on Category"
  end

  MANY = CI_TEST_RUN ? 1000 : 20
  A_FEW = CI_TEST_RUN ? 50:  10
  A_BATCH = CI_TEST_RUN ? 100: 10

  it "should support batch processing" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    expect_any_instance_of(CounterCulture::Reconciler::Reconciliation).to receive(:update_count_for_batch).exactly(MANY/A_BATCH).times

    MANY.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH
  end

  it "should correctly fix the counter caches with thousands of records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    MANY.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(3) }

    SimpleMain.order(Arel.sql('random()')).limit(A_FEW).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(3) }
  end

  it "should correctly fix the counter caches for thousands of records when counter is conditional" do
    # first, clean up
    ConditionalDependent.delete_all
    ConditionalMain.delete_all

    MANY.times do |i|
      main = ConditionalMain.create
      3.times { main.conditional_dependents.create(:condition => main.id % 2 == 0) }
    end

    ConditionalMain.find_each { |main| expect(main.conditional_dependents_count).to eq(main.id % 2 == 0 ? 3 : 0) }

    ConditionalMain.order(Arel.sql('random()')).limit(A_FEW).update_all :conditional_dependents_count => 1
    ConditionalDependent.counter_culture_fix_counts :batch_size => A_BATCH

    ConditionalMain.find_each { |main| expect(main.conditional_dependents_count).to eq(main.id % 2 == 0 ? 3 : 0) }
  end

  it "should correctly fix the counter caches when no dependent record exists for some of main records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    MANY.times do |i|
      main = SimpleMain.create
      (main.id % 4).times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(main.id % 4) }

    SimpleMain.order(Arel.sql('random()')).limit(A_FEW).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(main.id % 4) }
  end

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

  it "should update the timestamp if touch: true is set" do
    user = User.create
    product = Product.create

    Timecop.travel(1.second.from_now) do
      review = Review.create :user_id => user.id, :product_id => product.id

      user.reload; product.reload

      expect(user.created_at.to_i).to eq(user.updated_at.to_i)
      expect(product.created_at.to_i).to be < product.updated_at.to_i
    end
  end

  it "should update the timestamp for custom column if touch: rexiews_updated_at is set" do
    product = Product.create

    Timecop.travel(1.second.from_now) do
      Review.create :product_id => product.id

      product.reload

      expect(product.created_at.to_i).to be < product.rexiews_updated_at.to_i
      expect(product.created_at.to_i).to be < product.updated_at.to_i
    end
  end

  it "should update counts correctly when creating using nested attributes" do
    user = User.create(:reviews_attributes => [{:some_text => 'abc'}, {:some_text => 'xyz'}])
    user.reload
    expect(user.reviews_count).to eq(2)
  end

  it "should use relation primary_key correctly" do
    subcateg = Subcateg.create :subcat_id => Subcateg::SUBCAT_1
    post = Post.new
    post.subcateg = subcateg
    post.save!
    subcateg.reload
    expect(subcateg.posts_count).to eq(1)
  end

  it "should use relation primary key on counter destination table correctly when fixing counts" do
    subcateg = Subcateg.create :subcat_id => Subcateg::SUBCAT_1
    post = Post.new
    post.subcateg = subcateg
    post.save!

    subcateg.posts_count = -1
    subcateg.save!

    fixed = Post.counter_culture_fix_counts :only => :subcateg

    expect(fixed.length).to eq(1)
    expect(subcateg.reload.posts_count).to eq(1)
  end

  it "should use primary key on counted records table correctly when fixing counts" do
    skip("Unsupported in this version of Rails") if Rails.version < "4.0.0"

    subcateg = Subcateg.create :subcat_id => Subcateg::SUBCAT_1
    post = Post.new
    post.subcateg = subcateg
    post.save!

    post_comment = PostComment.create!(:post_id => post.id)

    post.comments_count = -1
    post.save!

    fixed = PostComment.counter_culture_fix_counts
    expect(fixed.length).to eq(1)
    expect(post.reload.comments_count).to eq(1)
  end

  it "should use multi-level relation primary key on counter destination table correctly when fixing counts" do
    skip("Unsupported in this version of Rails") if Rails.version < "4.0.0"

    categ = Categ.create :cat_id => Categ::CAT_1
    subcateg = Subcateg.new :subcat_id => Subcateg::SUBCAT_1
    subcateg.categ = categ
    subcateg.save!

    post = Post.new
    post.subcateg = subcateg
    post.save!

    categ.posts_count = -1
    categ.save!

    fixed = Post.counter_culture_fix_counts :only => [[:subcateg, :categ]]

    expect(fixed.length).to eq(1)
    expect(categ.reload.posts_count).to eq(1)
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

  describe "#previous_model" do
    let(:user){User.create :name => "John Smith", :manages_company_id => 1}

    it "should return a copy of the original model" do
      user.name = "Joe Smith"
      user.manages_company_id = 2

      if Rails.version >= "5.1.0"
        # must save to make the actual "saved_changes" available in Rails 5.1
        # whereas we simply use the "changed_attributes" before that
        user.save!
      end
      prev = CounterCulture::Counter.new(user, :foobar, {}).previous_model(user)

      expect(prev.name).to eq("John Smith")
      expect(prev.manages_company_id).to eq(1)

      expect(user.name).to eq("Joe Smith")
      expect(user.manages_company_id).to eq(2)
    end
  end

  describe "self referential counter cache" do
    it "increments counter cache on create" do
      company = Company.create!
      company.children << Company.create!

      company.reload
      expect(company.children_count).to eq(1)
    end

    it "decrements counter cache on destroy" do
      company = Company.create!
      company.children << Company.create!

      company.reload
      expect(company.children_count).to eq(1)

      company.children.first.destroy

      company.reload
      expect(company.children_count).to eq(0)
    end

    it "fixes counter cache" do
      company = Company.create!
      company.children << Company.create!

      company.children_count = -1
      company.save!

      fixed = Company.counter_culture_fix_counts
      expect(fixed.length).to eq(1)
      expect(company.reload.children_count).to eq(1)
    end
  end

  describe "dynamic column names with totaling instead of counting" do
    it "should correctly sum up the values" do
      person = Person.create!

      earning_transaction = Transaction.create(monetary_value: 10, person: person)

      person.reload
      expect(person.money_earned_total).to eq(10)

      spending_transaction = Transaction.create(monetary_value: -20, person: person)
      person.reload
      expect(person.money_spent_total).to eq(-20)
    end

    it "should show the correct changes when changes are present" do
      person = Person.create(id:100)

      earning_transaction = Transaction.create(monetary_value: 10, person: person)
      spending_transaction = Transaction.create(monetary_value: -20, person: person)

      # Overwrite the values for the person so they are incorrect
      person.reload
      person.money_earned_total = 0
      person.money_spent_total = 0
      person.save

      fixed = Transaction.counter_culture_fix_counts
      expect(fixed.length).to eq(2)
      expect(fixed).to eq([
        {:entity=>"Person", :id=>person.id, :what=>"money_earned_total", :wrong=>0, :right=>10},
        {:entity=>"Person", :id=>person.id, :what=>"money_spent_total", :wrong=>0, :right=>-20}
      ])
    end
  end

  describe "when using discard for soft deletes" do
    it "works" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"
      company = Company.create!
      expect(company.soft_delete_discards_count).to eq(0)
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      sd.reload
      expect(sd).to be_discarded
      expect(company.reload.soft_delete_discards_count).to eq(0)

      company.update_attributes(soft_delete_discards_count: 100)
      expect(company.reload.soft_delete_discards_count).to eq(100)
      SoftDeleteDiscard.counter_culture_fix_counts
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.undiscard
      expect(company.reload.soft_delete_discards_count).to eq(1)
    end

    it "runs destroy callback only once" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"

      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end

    it "runs restore callback only once" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"

      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.undiscard
      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.undiscard
      expect(company.reload.soft_delete_discards_count).to eq(1)
    end
  end

  describe "when using paranoia for soft deletes" do
    it "works" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"
      company = Company.create!
      expect(company.soft_delete_paranoia_count).to eq(0)
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      sd.reload
      expect(sd.deleted_at).to be_truthy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      company.update_attributes(soft_delete_paranoia_count: 100)
      expect(company.reload.soft_delete_paranoia_count).to eq(100)
      SoftDeleteParanoia.counter_culture_fix_counts
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.restore
      expect(company.reload.soft_delete_paranoia_count).to eq(1)
    end

    it "runs destroy callback only once" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"

      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)

      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end

    it "runs restore callback only once" do
      skip("Unsupported in this version of Rails") if Rails.version < "4.2.0"

      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)

      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.restore
      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.restore
      expect(company.reload.soft_delete_paranoia_count).to eq(1)
    end
  end

  describe "with polymorphic_associations" do
    before(:all) do
      require 'models/poly_image'
      require 'models/poly_employee'
      require 'models/poly_product'
    end
    let(:employee) { PolyEmployee.create(id: 3000) }
    let(:product1) { PolyProduct.create() }
    let(:product2) { PolyProduct.create() }
    let(:special_url) { "http://images.example.com/special.png" }

    def mess_up_counts
      PolyEmployee.update_all(poly_images_count: 100, poly_images_count_dup: 100, special_poly_images_count: 100)
      PolyProduct.update_all(poly_images_count: 100, poly_images_count_dup: 100, special_poly_images_count: 100)
    end

    describe "default" do
      it "increments / decrements counter caches correctly" do
        expect(employee.poly_images_count).to eq(0)
        expect(product1.poly_images_count).to eq(0)
        img1 = PolyImage.create(imageable: employee)
        expect(employee.reload.poly_images_count).to eq(1)
        expect(product1.reload.poly_images_count).to eq(0)
        img2 = PolyImage.create(imageable: product1)
        expect(employee.reload.poly_images_count).to eq(1)
        expect(product1.reload.poly_images_count).to eq(1)
        img3 = PolyImage.create(imageable: product1)
        expect(employee.reload.poly_images_count).to eq(1)
        expect(product1.reload.poly_images_count).to eq(2)
        img3.destroy
        expect(employee.reload.poly_images_count).to eq(1)
        expect(product1.reload.poly_images_count).to eq(1)
        img2.imageable = employee
        img2.save!
        expect(employee.reload.poly_images_count).to eq(2)
        expect(product1.reload.poly_images_count).to eq(0)
      end

      it "decrements counter caches on update correctly" do
        img = PolyImage.create(imageable: product1)
        img.imageable = employee
        img.save!
        expect(product1.reload.poly_images_count).to eq(0)
        expect(employee.reload.poly_images_count).to eq(1)
      end

      it "can fix counts for polymorphic correctly" do
        2.times { PolyImage.create(imageable: employee) }
        1.times { PolyImage.create(imageable: product1) }
        mess_up_counts

        PolyImage.counter_culture_fix_counts

        expect(product2.reload.poly_images_count).to eq(0)
        expect(product1.reload.poly_images_count).to eq(1)
        expect(employee.reload.poly_images_count).to eq(2)
      end

      it "can handle nil values" do
        img = PolyImage.create(imageable: employee)
        PolyImage.create(imageable: nil)
        mess_up_counts

        PolyImage.counter_culture_fix_counts

        expect(employee.reload.poly_images_count).to eq(1)

        img.imageable = nil
        img.save!

        expect(employee.reload.poly_images_count).to eq(0)

        img.imageable = employee
        img.save!

        expect(employee.reload.poly_images_count).to eq(1)
      end
    end
    describe "custom column name" do
      it "increments counter cache on create" do
        expect(employee.poly_images_count_dup).to eq(0)
        expect(product1.poly_images_count_dup).to eq(0)
        img1 = PolyImage.create(imageable: employee)
        expect(employee.reload.poly_images_count_dup).to eq(1)
        expect(product1.reload.poly_images_count_dup).to eq(0)
        img2 = PolyImage.create(imageable: product1)
        expect(employee.reload.poly_images_count_dup).to eq(1)
        expect(product1.reload.poly_images_count_dup).to eq(1)
        img3 = PolyImage.create(imageable: product1)
        expect(employee.reload.poly_images_count_dup).to eq(1)
        expect(product1.reload.poly_images_count_dup).to eq(2)
        img3.destroy
        expect(employee.reload.poly_images_count_dup).to eq(1)
        expect(product1.reload.poly_images_count_dup).to eq(1)
        img2.imageable = employee
        img2.save!
        expect(employee.reload.poly_images_count_dup).to eq(2)
        expect(product1.reload.poly_images_count_dup).to eq(0)
      end

      it "decrements counter caches on update correctly" do
        img = PolyImage.create(imageable: product1)
        img.imageable = employee
        img.save!
        expect(employee.reload.poly_images_count_dup).to eq(1)
        expect(product1.reload.poly_images_count_dup).to eq(0)
      end

      it "can fix counts for polymorphic correctly" do
        2.times { PolyImage.create(imageable: employee) }
        1.times { PolyImage.create(imageable: product1) }
        mess_up_counts

        PolyImage.counter_culture_fix_counts

        expect(product2.reload.poly_images_count_dup).to eq(0)
        expect(product1.reload.poly_images_count_dup).to eq(1)
        expect(employee.reload.poly_images_count_dup).to eq(2)
      end
    end
    describe "conditional counts" do
      it "increments counter cache on create" do
        expect(employee.special_poly_images_count).to eq(0)
        expect(product1.special_poly_images_count).to eq(0)
        PolyImage.create(imageable: employee)
        expect(employee.reload.special_poly_images_count).to eq(0)
        expect(product1.special_poly_images_count).to eq(0)
        PolyImage.create(imageable: product1)
        expect(employee.reload.special_poly_images_count).to eq(0)
        expect(product1.reload.special_poly_images_count).to eq(0)
        img1 = PolyImage.create(imageable: employee, url: special_url)
        expect(employee.reload.special_poly_images_count).to eq(1)
        expect(product1.special_poly_images_count).to eq(0)
        img2 = PolyImage.create(imageable: product1, url: special_url)
        expect(employee.reload.special_poly_images_count).to eq(1)
        expect(product1.reload.special_poly_images_count).to eq(1)
        img2.destroy
        expect(employee.reload.special_poly_images_count).to eq(1)
        expect(product1.reload.special_poly_images_count).to eq(0)
        img1.imageable = product1
        img1.save!
        expect(employee.reload.special_poly_images_count).to eq(0)
        expect(product1.reload.special_poly_images_count).to eq(1)
      end

      it "can fix counts for polymorphic correctly" do
        4.times { PolyImage.create(imageable: employee) }
        2.times { PolyImage.create(imageable: employee, url: special_url) }
        1.times { PolyImage.create(imageable: product1) }
        1.times { PolyImage.create(imageable: product1, url: special_url) }
        mess_up_counts

        PolyImage.counter_culture_fix_counts

        expect(product2.reload.special_poly_images_count).to eq(0)
        expect(employee.reload.special_poly_images_count).to eq(2)
        expect(product1.reload.special_poly_images_count).to eq(1)
      end

      it "can deal with changes to condition" do
        img1 = PolyImage.create(imageable: employee)
        expect {img1.update_attributes!(url: special_url)}
          .to change { employee.reload.special_poly_images_count }.from(0).to(1)
      end

      it "can deal with changes to condition" do
        img1 = PolyImage.create(imageable: employee, url: special_url)
        expect {img1.update_attributes!(url: "normal url")}
          .to change { employee.reload.special_poly_images_count }.from(1).to(0)
      end
    end
  end

  describe "with papertrail support", versioning: true do
    it "creates a papertrail version when changed" do
      if Rails.version < "5.0.0"
        skip("Unsupported in this version of Rails")
      end
      if RUBY_VERSION < "2.3.0" && Rails.version >= "5.2.0"
        skip("Unsupported in this combination of Ruby and Rails")
      end

      user = User.create
      product = Product.create

      expect(product.reviews_count).to eq(0)
      expect(product.versions.count).to eq(1)

      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

      product.reload

      expect(product.reviews_count).to eq(1)
      expect(product.versions.count).to eq(2)

      attrs_from_versions = YAML.load(product.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['reviews_count']).to eq(0)

      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

      product.reload

      expect(product.reviews_count).to eq(2)
      expect(product.versions.count).to eq(3)

      attrs_from_versions = YAML.load(product.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['reviews_count']).to eq(1)
    end

    it "does not create a papertrail version when papertrail flag not set" do
      if Rails.version < "5.0.0"
        skip("Unsupported in this version of Rails")
      end
      if RUBY_VERSION < "2.3.0" && Rails.version >= "5.2.0"
        skip("Unsupported in this combination of Ruby and Rails")
      end

      user = User.create
      product = Product.create

      expect(user.reviews_count).to eq(0)
      expect(user.versions.count).to eq(1)

      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

      user.reload

      expect(user.reviews_count).to eq(1)
      expect(user.versions.count).to eq(1)
    end
  end
end
