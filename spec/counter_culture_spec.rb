require_relative 'spec_helper'

require 'models/company'
require 'models/comment'
require 'models/industry'
require 'models/product'
require 'models/review'
require 'models/simple_review'
require 'models/twitter_review'
require 'models/user'
require 'models/category'
require 'models/has_string_id'
require 'models/has_non_pk_id'
require 'models/simple_main'
require 'models/simple_dependent'
require 'models/conditional_main'
require 'models/conditional_dependent'
require 'models/post'
require 'models/post_comment'
require 'models/post_like'
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
require 'models/with_module/model1'
require 'models/with_module/model2'
require 'models/prefecture'
require 'models/city'
require 'models/group'
require 'models/sub_group'
require 'models/group_item'
require 'models/article_group'
require 'models/article'

if CounterCulture.supports_composite_keys?
  require 'models/composite_group'
  require 'models/composite_group_user'
  require 'models/composite_user'
end


if ENV['DB'] == 'postgresql'
  require 'models/purchase_order'
  require 'models/purchase_order_item'
end

require 'database_cleaner'
DatabaseCleaner.strategy = :deletion

RSpec.describe "CounterCulture" do
  def yaml_load(yaml)
    YAML.safe_load(yaml, permitted_classes: [Time])
  end

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

  it "increments counter cache on create without reload" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    user.reviews.create :user => user, :product => product, :approvals => 13

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
    expect(product.reviews_count).to eq(1)

    # NOTE: check if counters from the DB equal to the cached
    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(13)
    expect(product.reviews_count).to eq(1)
  end

  it "updates counter caches on change belongs_to association" do
    simple_main1 = SimpleMain.create
    simple_main2 = SimpleMain.create
    simple_dependent = SimpleDependent.create :simple_main_id => simple_main1.id

    simple_dependent.simple_main = simple_main2
    simple_dependent.save!

    expect(simple_main1.simple_dependents_count).to eq(0)
    expect(simple_main2.simple_dependents_count).to eq(1)

    # NOTE: check if counters from the DB equal to the cached
    simple_main1.reload
    simple_main2.reload

    expect(simple_main1.simple_dependents_count).to eq(0)
    expect(simple_main2.simple_dependents_count).to eq(1)
  end

  it "skips zero delta_magnitude update on create" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    expect_queries(0, filter: /COALESCE\("review_approvals_count", 0\) \+ 0/) do
      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 0
    end

    user.reload
    product.reload

    expect(user.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(1)
  end

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

    # this does not decrement counter cache
    review.destroy

    user.reload
    product.reload

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(0)
  end

  it "if associated object is frozen, the counter cache attribute of the associated object will not be decremented without a reload" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    review = Review.create :user => user, :product => product, :approvals => 69

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    user.freeze
    product.freeze
    review.destroy

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    # this does not decrement counter cache
    review.destroy

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    # NOTE: check if counters from the DB equal to the cached
    user.reload
    product.reload

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
  end

  it "decrements counter cache on destroy without reload" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(product.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    review = Review.create :user => user, :product => product, :approvals => 69

    expect(user.reviews_count).to eq(1)
    expect(product.reviews_count).to eq(1)
    expect(user.review_approvals_count).to eq(69)

    review.destroy

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(0)

    # this does not decrement counter cache
    review.destroy

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)
    expect(product.reviews_count).to eq(0)

    # NOTE: check if counters from the DB equal to the cached
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

  it "works with multiple saves in one transaction" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(user.review_approvals_count).to eq(0)

    Review.transaction do
      review1 = Review.create!(user_id: user.id, product_id: product.id, approvals: 0)

      user.reload
      expect(user.reviews_count).to eq(1)
      expect(user.review_approvals_count).to eq(0)

      review1.update!(approvals: 42)

      user.reload
      expect(user.reviews_count).to eq(1)
      expect(user.review_approvals_count).to eq(42)

      review2 = Review.create!(user_id: user.id, product_id: product.id, approvals: 1)

      user.reload
      expect(user.reviews_count).to eq(2)
      expect(user.review_approvals_count).to eq(43)
    end
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
    categories = 3.times.map { Category.create }
    categories.each {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    categories.each {|category| expect(category.reload.products_count).to eq(1) }
  end

  it "should overwrite foreign-key values on destroy" do
    categories = 3.times.map { Category.create }
    categories.each {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    categories.each {|category| expect(category.reload.products_count).to eq(1) }

    product.destroy
    categories.each {|category| expect(category.reload.products_count).to eq(0) }
  end

  it "should overwrite foreign-key values on destroy" do
    categories = 3.times.map { Category.create }
    categories.each {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    categories.each {|category| expect(category.reload.products_count).to eq(1) }

    product.category = nil
    product.save!
    categories.each {|category| expect(category.reload.products_count).to eq(0) }
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

  it "should fix a counter cache with no DB-level primary_key index correctly" do
    non_pk_id = HasNonPkId.create(id: (HasNonPkId.maximum(:id) || 1) + 1)

    user = User.create(has_non_pk_id_id: non_pk_id.id)

    non_pk_id.reload
    expect(non_pk_id.users_count).to eq(1)

    user2 = User.create(has_non_pk_id_id: non_pk_id.id)

    non_pk_id.reload
    expect(non_pk_id.users_count).to eq(2)

    non_pk_id.users_count = 123
    non_pk_id.save!

    non_pk_id.reload
    expect(non_pk_id.users_count).to eq(123)

    User.counter_culture_fix_counts

    non_pk_id.reload
    expect(non_pk_id.users_count).to eq(2)
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

    user.update(:custom_delta_count => 5)

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

  context "when relation is an array but has different primary keys along the chain" do
    it "should update correctly" do
      group = Group.create
      sub_group = SubGroup.create(group: group)

      expect(group.group_items_count).to eq(0)
      group_item = GroupItem.create(sub_group: sub_group)

      expect(group.reload.group_items_count).to eq(1)
    end

    it "should fix counts correctly" do
      group = Group.create
      sub_group = SubGroup.create(group: group)
      group_item = GroupItem.create(sub_group: sub_group)

      expect(group.reload.group_items_count).to eq(1)

      group.update!(group_items_count: -1)

      GroupItem.counter_culture_fix_counts

      expect(group.reload.group_items_count).to eq(1)
    end
  end

  it "should raise a good error message when calling fix_counts with no caches defined" do
    expect { Category.counter_culture_fix_counts }.to raise_error "No counter cache defined on Category"
  end

  it "should log if verbose option is true" do
    logger = ActiveRecord::Base.logger
    io = StringIO.new
    io_logger = Logger.new(io)
    ActiveRecord::Base.logger = io_logger

    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    2.times do
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleDependent.counter_culture_fix_counts :batch_size => 1, verbose: true

    expect(io.string).to include(
      "Performing reconciling of SimpleDependent#simple_main.")
    expect(io.string).to include(
      "Processing batch #1.")
    expect(io.string).to include(
      "Finished batch #1.")
    expect(io.string).to include(
      "Processing batch #2.")
    expect(io.string).to include(
      "Finished batch #2.")
    expect(io.string).to include(
      "Finished reconciling of SimpleDependent#simple_main.")
    ActiveRecord::Base.logger = logger
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

  it "should request a reading and not a writing database connection" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    A_FEW.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    # Counts are correct at this point so no update should happen

    requested_reading_connection = false
    requested_writing_connection = false
    SimpleDependent.counter_culture_fix_counts db_connection_builder: lambda{|reading, block|
      if reading
        requested_reading_connection = true
      else
        requested_writing_connection = true
      end
      block.call
    }
    expect(requested_reading_connection).to be(true)
    expect(requested_writing_connection).to be(false)
  end

  it "should request a reading and a writing database connection" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    A_FEW.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    # Damage the counts so an update happens
    SimpleMain.update_all(simple_dependents_count: -1)

    requested_reading_connection = false
    requested_writing_connection = false
    SimpleDependent.counter_culture_fix_counts db_connection_builder: lambda{|reading, block|
      if reading
        requested_reading_connection = true
      else
        requested_writing_connection = true
      end
      block.call
    }
    expect(requested_reading_connection).to be(true)
    expect(requested_writing_connection).to be(true)
  end

  it "should correctly fix the counter caches with conditionals" do
    updated = SimpleMain.create
    updated.simple_dependents.create
    not_updated = SimpleMain.create
    not_updated.simple_dependents.create
    SimpleMain.all.update_all simple_dependents_count: 3

    SimpleDependent.counter_culture_fix_counts only: :simple_main, where: { simple_mains: { id: updated.id } }

    expect(updated.reload.simple_dependents_count).to eq(1)
    expect(not_updated.reload.simple_dependents_count).to eq(3)
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

    SimpleMain.order(db_random).limit(A_FEW).update_all simple_dependents_count: 1
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

    ConditionalMain.order(db_random).limit(A_FEW).update_all :conditional_dependents_count => 1
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

    SimpleMain.order(db_random).limit(A_FEW).update_all simple_dependents_count: 1
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
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)

    post = Post.new
    post.subcateg = subcateg
    post.save!

    subcateg.reload
    expect(subcateg.posts_count).to eq(1)
  end

  it "should use relation primary key on counter destination table correctly when fixing counts" do
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)
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
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)
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
    categ = Categ.create!
    categ.update(cat_id: Categ::CAT_1)

    subcateg = Subcateg.create!
    subcateg.update(
      subcat_id: Subcateg::SUBCAT_1,
      categ: categ
    )

    Post.create!(subcateg: subcateg)

    categ.update(posts_count: -1)

    fixed = Post.counter_culture_fix_counts :only => [[:subcateg, :categ]]

    expect(fixed.length).to eq(1)
    expect(categ.reload.posts_count).to eq(1)
  end

  it "works with after_commit" do
    subcateg1 = Subcateg.create!
    subcateg2 = Subcateg.create!
    expect(subcateg1.posts_after_commit_count).to eq(0)
    expect(subcateg1.posts_dynamic_commit_count).to eq(0)
    expect(subcateg2.posts_after_commit_count).to eq(0)
    expect(subcateg2.posts_dynamic_commit_count).to eq(0)

    post = Post.create!(subcateg: subcateg1)

    subcateg1.reload
    subcateg2.reload

    expect(subcateg1.posts_after_commit_count).to eq(1)
    expect(subcateg1.posts_dynamic_commit_count).to eq(1)
    expect(subcateg2.posts_after_commit_count).to eq(0)
    expect(subcateg2.posts_dynamic_commit_count).to eq(0)

    Post.transaction do
      post.update(subcateg: subcateg2)

      subcateg1.reload
      subcateg2.reload

      expect(subcateg1.posts_after_commit_count).to eq(1)
      expect(subcateg1.posts_dynamic_commit_count).to eq(1)
      expect(subcateg1.posts_count).to eq(0)
      expect(subcateg2.posts_after_commit_count).to eq(0)
      expect(subcateg2.posts_dynamic_commit_count).to eq(0)
      expect(subcateg2.posts_count).to eq(1)
    end

    subcateg1.reload
    subcateg2.reload

    expect(subcateg1.posts_after_commit_count).to eq(0)
    expect(subcateg1.posts_dynamic_commit_count).to eq(0)
    expect(subcateg2.posts_after_commit_count).to eq(1)
    expect(subcateg2.posts_dynamic_commit_count).to eq(1)

    post.destroy!

    subcateg1.reload
    subcateg2.reload

    expect(subcateg1.posts_after_commit_count).to eq(0)
    expect(subcateg1.posts_dynamic_commit_count).to eq(0)
    expect(subcateg2.posts_after_commit_count).to eq(0)
    expect(subcateg2.posts_dynamic_commit_count).to eq(0)
  end

  it "works with dynamic after_commit" do
    subcateg1 = Subcateg.create!
    subcateg2 = Subcateg.create!
    expect(subcateg1.posts_after_commit_count).to eq(0)
    expect(subcateg1.posts_dynamic_commit_count).to eq(0)
    expect(subcateg2.posts_after_commit_count).to eq(0)
    expect(subcateg2.posts_dynamic_commit_count).to eq(0)

    post = Post.create!(subcateg: subcateg1)

    subcateg1.reload
    subcateg2.reload

    expect(subcateg1.posts_after_commit_count).to eq(1)
    expect(subcateg1.posts_dynamic_commit_count).to eq(1)
    expect(subcateg2.posts_after_commit_count).to eq(0)
    expect(subcateg2.posts_dynamic_commit_count).to eq(0)

    Post.transaction do
      DynamicAfterCommit.update_counter_cache_in_transaction do
        post.update(subcateg: subcateg2)
      end

      subcateg1.reload
      subcateg2.reload

      expect(subcateg1.posts_after_commit_count).to eq(1)
      expect(subcateg1.posts_dynamic_commit_count).to eq(0)
      expect(subcateg1.posts_count).to eq(0)
      expect(subcateg2.posts_after_commit_count).to eq(0)
      expect(subcateg2.posts_dynamic_commit_count).to eq(1)
      expect(subcateg2.posts_count).to eq(1)
    end

    subcateg1.reload
    subcateg2.reload

    expect(subcateg1.posts_after_commit_count).to eq(0)
    expect(subcateg1.posts_dynamic_commit_count).to eq(0)
    expect(subcateg2.posts_after_commit_count).to eq(1)
    expect(subcateg2.posts_dynamic_commit_count).to eq(1)
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
      user.save!

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

    it "decrements counter cache on destroy_all" do
      company = Company.create!
      5.times { company.children << Company.create! }

      company.reload
      expect(company.children_count).to eq(5)

      company.children.destroy_all

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

    it "fixes counter cache for polymorphic self reference" do
      comment = Comment.create!
      comment.comments << Comment.create!

      comment.comments_count = -1
      comment.save!

      fixed = Comment.counter_culture_fix_counts
      expect(fixed.length).to eq(1)
      expect(comment.reload.comments_count).to eq(1)
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
      company = Company.create!
      expect(company.soft_delete_discards_count).to eq(0)
      sd = SoftDeleteDiscard.create!(company_id: company.id)
      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      sd.reload
      expect(sd).to be_discarded
      expect(company.reload.soft_delete_discards_count).to eq(0)

      company.update(soft_delete_discards_count: 100)
      expect(company.reload.soft_delete_discards_count).to eq(100)
      SoftDeleteDiscard.counter_culture_fix_counts
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.undiscard
      expect(company.reload.soft_delete_discards_count).to eq(1)
    end

    it "runs destroy callback only once" do

      company = Company.create!
      sd = SoftDeleteDiscard.create!(company_id: company.id)

      expect(company.reload.soft_delete_discards_count).to eq(1)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)

      sd.discard
      expect(company.reload.soft_delete_discards_count).to eq(0)
    end

    it "runs restore callback only once" do
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

    describe "when calling hard-destroy" do
      it "does not run destroy callback for discarded records" do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id)

        expect(company.reload.soft_delete_discards_count).to eq(1)

        sd.discard
        expect(company.reload.soft_delete_discards_count).to eq(0)

        sd.destroy
        expect(company.reload.soft_delete_discards_count).to eq(0)
      end

      it "runs destroy callback for undiscarded records" do
        company = Company.create!
        sd = SoftDeleteDiscard.create!(company_id: company.id)

        expect(company.reload.soft_delete_discards_count).to eq(1)

        sd.destroy
        expect(company.reload.soft_delete_discards_count).to eq(0)
      end
    end

    describe "dynamic column names with totaling instead of counting" do
      describe 'when updating discarded records' do
        it 'does not update sum' do
          company = Company.create!
          sd = SoftDeleteDiscard.create!(company_id: company.id, value: 5)

          expect(company.reload.soft_delete_discard_values_sum).to eq(5)

          sd.discard
          expect(company.reload.soft_delete_discard_values_sum).to eq(0)

          sd.update value: 10
          expect(company.reload.soft_delete_discard_values_sum).to eq(0)
        end
      end

      describe 'when updating undiscarded records' do
        it 'updates sum' do
          company = Company.create!
          sd = SoftDeleteDiscard.create!(company_id: company.id, value: 5)

          expect(company.reload.soft_delete_discard_values_sum).to eq(5)

          sd.update value: 10
          expect(company.reload.soft_delete_discard_values_sum).to eq(10)
        end
      end
    end
  end

  describe "when using paranoia for soft deletes" do
    it "works" do
      company = Company.create!
      expect(company.soft_delete_paranoia_count).to eq(0)
      sd = SoftDeleteParanoia.create!(company_id: company.id)
      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      sd.reload
      expect(sd.deleted_at).to be_truthy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      company.update(soft_delete_paranoia_count: 100)
      expect(company.reload.soft_delete_paranoia_count).to eq(100)
      SoftDeleteParanoia.counter_culture_fix_counts
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.restore
      expect(company.reload.soft_delete_paranoia_count).to eq(1)
    end

    it "runs destroy callback only once" do
      company = Company.create!
      sd = SoftDeleteParanoia.create!(company_id: company.id)

      expect(company.reload.soft_delete_paranoia_count).to eq(1)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)

      sd.destroy
      expect(company.reload.soft_delete_paranoia_count).to eq(0)
    end

    it "runs restore callback only once" do
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

    describe "when calling paranoia really destroy" do
      it "does not run destroy callback for paranoia destroyed records" do
        company = Company.create!
        sd = SoftDeleteParanoia.create!(company_id: company.id)

        expect(company.reload.soft_delete_paranoia_count).to eq(1)

        sd.destroy
        expect(company.reload.soft_delete_paranoia_count).to eq(0)

        sd.really_destroy!
        expect(company.reload.soft_delete_paranoia_count).to eq(0)
      end

      it "runs really destroy callback for paranoia undestroyed records" do
        company = Company.create!
        expect(company.soft_delete_paranoia_count).to eq(0)
        sd = SoftDeleteParanoia.create!(company_id: company.id)
        expect(company.reload.soft_delete_paranoia_count).to eq(1)

        sd.really_destroy!
        expect{ sd.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(company.reload.soft_delete_paranoia_count).to eq(0)
      end
    end

    describe "dynamic column names with totaling instead of counting" do
      describe 'when updating soft deleted records' do
        it 'does not update sum' do
          company = Company.create!
          sd = SoftDeleteParanoia.create!(company_id: company.id, value: 5)

          expect(company.reload.soft_delete_paranoia_values_sum).to eq(5)

          sd.destroy
          expect(company.reload.soft_delete_paranoia_values_sum).to eq(0)

          sd.update value: 10
          expect(company.reload.soft_delete_paranoia_values_sum).to eq(0)
        end
      end

      describe 'when updating undestroyed records' do
        it 'updates sum' do
          company = Company.create!
          sd = SoftDeleteParanoia.create!(company_id: company.id, value: 5)

          expect(company.reload.soft_delete_paranoia_values_sum).to eq(5)

          sd.update value: 10
          expect(company.reload.soft_delete_paranoia_values_sum).to eq(10)
        end
      end
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

      it "can fix counts for a specified polymorphic correctly" do
        2.times { PolyImage.create(imageable: employee) }
        1.times { PolyImage.create(imageable: product1) }
        mess_up_counts

        PolyImage.counter_culture_fix_counts(polymorphic_classes: PolyEmployee)

        expect(product1.reload.poly_images_count_dup).to eq(100) # unchanged
        expect(employee.reload.poly_images_count_dup).to eq(2)
      end

      it "can fix counts for multiple specified polymorphics correctly" do
        2.times { PolyImage.create(imageable: employee) }
        1.times { PolyImage.create(imageable: product1) }
        mess_up_counts

        PolyImage.counter_culture_fix_counts(
          polymorphic_classes: [PolyEmployee, PolyProduct]
        )

        expect(product1.reload.poly_images_count_dup).to eq(1)
        expect(employee.reload.poly_images_count_dup).to eq(2)
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

    describe 'using custom indexes as primary keys' do
      it "increments / decrements counter caches correctly" do
        expect(employee.poly_images_from_uids_count).to eq(0)
        expect(product1.poly_images_from_uids_count).to eq(0)
        img1 = PolyImage.create(imageable_from_uid: employee)
        expect(employee.reload.poly_images_from_uids_count).to eq(1)
        expect(product1.reload.poly_images_from_uids_count).to eq(0)
        img2 = PolyImage.create(imageable_from_uid: product1)
        expect(employee.reload.poly_images_from_uids_count).to eq(1)
        expect(product1.reload.poly_images_from_uids_count).to eq(1)
        img3 = PolyImage.create(imageable_from_uid: product1)
        expect(employee.reload.poly_images_from_uids_count).to eq(1)
        expect(product1.reload.poly_images_from_uids_count).to eq(2)
        img3.destroy
        expect(employee.reload.poly_images_from_uids_count).to eq(1)
        expect(product1.reload.poly_images_from_uids_count).to eq(1)
        img2.imageable_from_uid = employee
        img2.save!
        expect(employee.reload.poly_images_from_uids_count).to eq(2)
        expect(product1.reload.poly_images_from_uids_count).to eq(0)
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
        expect {img1.update!(url: special_url)}
          .to change { employee.reload.special_poly_images_count }.from(0).to(1)
      end

      it "can deal with changes to condition" do
        img1 = PolyImage.create(imageable: employee, url: special_url)
        expect {img1.update!(url: "normal url")}
          .to change { employee.reload.special_poly_images_count }.from(1).to(0)
      end
    end
  end

  describe "with papertrail support", versioning: true do
    it "creates a papertrail version when changed" do
      unless PapertrailSupport.supported_here?
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

      attrs_from_versions = yaml_load(product.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['reviews_count']).to eq(0)

      user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

      product.reload

      expect(product.reviews_count).to eq(2)
      expect(product.versions.count).to eq(3)

      attrs_from_versions = yaml_load(product.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['reviews_count']).to eq(1)
    end

    it "works with after_commit" do
      unless PapertrailSupport.supported_here?
        skip("Unsupported in this combination of Ruby and Rails")
      end

      subcateg = Subcateg.create!

      expect(subcateg.posts_after_commit_count).to eq(0)
      expect(subcateg.posts_dynamic_commit_count).to eq(0)
      expect(subcateg.versions.count).to eq(1)

      User.transaction do
        Post.create!(subcateg: subcateg)

        subcateg.reload

        expect(subcateg.posts_after_commit_count).to eq(0)
        expect(subcateg.posts_dynamic_commit_count).to eq(0)
        expect(subcateg.versions.count).to eq(1)
      end

      subcateg.reload

      expect(subcateg.posts_after_commit_count).to eq(1)
      expect(subcateg.posts_dynamic_commit_count).to eq(1)
      expect(subcateg.versions.count).to eq(3)

      attrs_from_versions = yaml_load(subcateg.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['posts_after_commit_count']).to eq(0)
      expect(attrs_from_versions['posts_dynamic_commit_count']).to eq(0)
    end

    it "works with dynamic after_commit" do
      unless PapertrailSupport.supported_here?
        skip("Unsupported in this combination of Ruby and Rails")
      end

      subcateg = Subcateg.create!

      expect(subcateg.posts_after_commit_count).to eq(0)
      expect(subcateg.posts_dynamic_commit_count).to eq(0)
      expect(subcateg.versions.count).to eq(1)

      User.transaction do
        DynamicAfterCommit.update_counter_cache_in_transaction do
          Post.create!(subcateg: subcateg)
        end

        subcateg.reload

        expect(subcateg.posts_after_commit_count).to eq(0)
        expect(subcateg.posts_dynamic_commit_count).to eq(1)
        expect(subcateg.versions.count).to eq(2)
      end

      subcateg.reload

      expect(subcateg.posts_after_commit_count).to eq(1)
      expect(subcateg.posts_dynamic_commit_count).to eq(1)
      expect(subcateg.versions.count).to eq(3)

      attrs_from_versions = yaml_load(subcateg.versions.reorder(:id).last.object)
      # should be the value before the counter change
      expect(attrs_from_versions['posts_after_commit_count']).to eq(0)
      expect(attrs_from_versions['posts_dynamic_commit_count']).to eq(0)
    end

    context "counter-cache model versioning" do
      let!(:main_obj) { SimpleMain.create(created_at: 1.day.ago, updated_at: 1.day.ago) }

      it "updates the updated_at of the parent variant" do
        unless PapertrailSupport.supported_here?
          skip("Unsupported in this combination of Ruby and Rails")
        end

        the_time = Time.now.utc
        Timecop.freeze(the_time) do
          main_obj.simple_dependents.create!
          expect(main_obj.reload.updated_at.to_i).to eq(the_time.to_i)
        end
      end

      it "sets the created_at time of the new version row to the current time" do
        unless PapertrailSupport.supported_here?
          skip("Unsupported in this combination of Ruby and Rails")
        end

        the_time = Time.now.utc
        Timecop.freeze(the_time) do
          main_obj.simple_dependents.create!
          expect(main_obj.versions.last.created_at.to_i).to eq(the_time.to_i)
        end
      end
    end

    it "does not create a papertrail version when papertrail flag not set" do
      unless PapertrailSupport.supported_here?
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

    context "with composite primary keys" do
      before do
        unless PapertrailSupport.supported_here?
          skip("Unsupported in this combination of Ruby and Rails")
        end

        unless CounterCulture.supports_composite_keys?
          skip("composite primary keys are not supported in this version of Rails")
        end
      end

      it "increments / decrements counter caches correctly" do
        group = CompositeGroup.create!(secondary_id: 123)

        expect(group.composite_users_count).to eq(0)
        expect(group.composite_users.count).to eq(0)
        group.composite_users << CompositeUser.create!

        expect(group.composite_users.count).to eq(1)
        expect(group.composite_users_count).to eq(1)
        group.composite_users.first.destroy

        group.reload
        expect(group.composite_users_count).to eq(0)
      end
    end
  end

  describe "with a module for the model" do
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

  describe "fix counts by scope" do
    let(:prefecture) { Prefecture.new name: 'Tokyo' }

    before do
      prefecture.save!
      City.create!(name: 'Sibuya', prefecture: prefecture, population: 221800)
      City.create!(name: 'Oku Tama', prefecture: prefecture, population: 6045)

      prefecture.reload
    end

    it "raises an error when column_names is invalid" do
      expect {
        City.counter_culture :prefecture, column_name: :foo,
          column_names: :foo
      }.to raise_error(
        ArgumentError,
        ":column_names must be a Hash of conditions and column names, or a Proc that when called returns such a Hash",
      )
    end

    context "when column_names value is a Symbol" do
      before do
        prefecture.update_columns(big_cities_count: 0, small_cities_count: 0)
      end

      it "updates the column" do
        expect(prefecture.reload.big_cities_count).to be(0)
        City.counter_culture_fix_counts(only: :prefecture,
                                        column_name: :big_cities_count)
        expect(prefecture.reload.big_cities_count).to be(1)
      end
    end

    context "when column_names is a Hash" do
      it "can fix counts by scope" do
        expect(prefecture.big_cities_count).to eq(1)

        prefecture.big_cities_count = 999
        prefecture.save!

        City.counter_culture_fix_counts
        expect(prefecture.reload.big_cities_count).to eq(1)
      end
    end

    context "when column_names is a Proc" do
      context "when column_names uses context" do
        let(:column_names) do
          proc { |context|
            @called = context
            { City.big => :big_cities_count }
          }
        end

        it "injects options inside block" do
          @called = false
          City.counter_culture :prefecture, column_name: :big_cities_count, column_names: column_names

          City.counter_culture_fix_counts(context: true)

          expect(@called).to eq(true)
        end
      end

      context "when the return value is not a hash" do
        it "does not call the proc right away" do
          called = false
          City.counter_culture :prefecture, column_name: :big_cities_count,
               column_names: -> { called = true; :foo }
          expect(called).to eq(false)
        end

        it "raises an error when called later" do
          City.counter_culture :prefecture, column_name: :big_cities_count,
               column_names: -> { :foo }
          expect { City.counter_culture_fix_counts }.to raise_error(
            ":column_names must be a Hash of conditions and column names"
          )
        end
      end

      it "can fix counts by scope" do
        expect(prefecture.small_cities_count).to eq(1)

        prefecture.small_cities_count = 999
        prefecture.save!

        City.counter_culture_fix_counts

        expect(prefecture.reload.small_cities_count).to eq(1)
      end
    end
  end

  it "support fix counts using batch limits start and finish" do
    companies_group = 3.times.map do
      company = Company.create!
      company.children << Company.create!
      company.children_count = -1
      company.save!
      company
    end

    company_out_of_first_group = Company.create!
    company_out_of_first_group.children << Company.create!
    company_out_of_first_group.children_count = -1
    company_out_of_first_group.save!

    start = companies_group.first.id
    finish = companies_group.last.id

    fixed = Company.counter_culture_fix_counts start: start, finish: finish
    expect(fixed.length).to eq(3)
    expect(company_out_of_first_group.reload.children_count).to eq(-1)

    companies_group.each do |company|
      expect(company.reload.children_count).to eq(1)
    end

    Company.counter_culture_fix_counts start: company_out_of_first_group.id

    expect(company_out_of_first_group.reload.children_count).to eq(1)
  end

  it "should fix the counter caches for a specified column only" do
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

    Review.counter_culture_fix_counts :skip_unsupported => true, :column_name => :review_approvals_count
    company.reload
    user.reload
    product.reload

    expect(company.reviews_count).to eq(2)
    expect(user.reviews_count).to eq(3)
    expect(product.reviews_count).to eq(4)
    expect(company.review_approvals_count).to eq(42)
  end

  it "should work with pg money type" do
    if ENV['DB'] != 'postgresql'
      skip("money type only supported in PostgreSQL")
    end

    po = PurchaseOrder.create

    expect(po.total_amount).to eq(0.0)

    item = po.purchase_order_items.build(amount: 100.00)
    item.save

    po.reload
    expect(po.total_amount).to eq(100.0)

    item = po.purchase_order_items.build(amount: 100.00)
    item.save

    po.reload
    expect(po.total_amount).to eq(200.0)

    item.destroy

    po.reload
    expect(po.total_amount).to eq(100.0)

    po.purchase_order_items.destroy_all
    po.reload
    expect(po.total_amount).to eq(0.0)
  end

  it "should touch the record when the counter cache is updated" do
    post = Post.create!
    Timecop.travel(2.second.from_now) do
      expect { PostLike.create!(post: post) }.to change { post.reload.updated_at }
    end
  end

  context "with composite primary keys" do
    before do
      unless CounterCulture.supports_composite_keys?
        skip("composite primary keys not supported in this version of Rails")
      end
    end

    it "should increment / decrement the counter" do
      group = CompositeGroup.create!(secondary_id: 123)

      expect(group.composite_users.count).to eq(0)
      expect(group.composite_users_count).to eq(0)
      group.composite_users << CompositeUser.create!

      expect(group.composite_users.count).to eq(1)
      expect(group.composite_users_count).to eq(1)
      group.composite_users.first.destroy

      group.reload
      expect(group.composite_users_count).to eq(0)
    end

    it "should fix the counter caches" do
      group = CompositeGroup.create!(secondary_id: 123)
      user1 = CompositeUser.create!
      user2 = CompositeUser.create!

      group.composite_users << user1
      group.composite_users << user2

      expect(group.composite_users_count).to eq(2)

      # mess up the count
      group.update_column(:composite_users_count, -1)
      user1.update_column(:composite_groups_count, -1)

      CompositeGroupUser.counter_culture_fix_counts

      group.reload
      user1.reload
      expect(group.composite_users_count).to eq(2)
      expect(user1.composite_groups_count).to eq(1)
    end
  end

  context "with aggregate_counter_updates" do
    it "aggregates SQL queries" do
      user = User.create
      user2 = User.create
      product1 = Product.create
      product2 = Product.create

      expect(user.reviews_count).to eq(0)
      expect(user2.reviews_count).to eq(0)
      expect(product1.reviews_count).to eq(0)
      expect(product2.reviews_count).to eq(0)
      expect(user.review_approvals_count).to eq(0)
      expect(user2.review_approvals_count).to eq(0)

      Timecop.freeze do
        expect_queries(2, filter: /UPDATE users/) do # user updates
          expect_queries(2, filter: /rexiews_updated_at/) do # product updates
            CounterCulture.aggregate_counter_updates do
              user.reviews.create :user_id => user.id, :product_id => product1.id, :approvals => 5
              user2.reviews.create :user_id => user2.id, :product_id => product1.id, :approvals => 5
              user.reviews.create :user_id => user.id, :product_id => product2.id, :approvals => 5
            end
          end
        end

        user.reload
        user2.reload
        product1.reload
        product2.reload

        expect(user.reviews_count).to eq(2)
        expect(user.using_count).to eq(2)
        expect(user.review_approvals_count).to eq(10)
        expect(user.dynamic_delta_count).to eq(2)
        expect(user.custom_delta_count).to eq(6)
        expect(user2.reviews_count).to eq(1)
        expect(user2.using_count).to eq(1)
        expect(user2.review_approvals_count).to eq(5)
        expect(user2.dynamic_delta_count).to eq(1)
        expect(user2.custom_delta_count).to eq(3)
        expect(product1.reviews_count).to eq(2)
        expect(product1.rexiews_count).to eq(2)
        expect(product2.reviews_count).to eq(1)
        expect(product2.rexiews_count).to eq(1)
        expect(product1.updated_at.to_i).to eq(Time.now.utc.to_i)
        expect(product1.rexiews_updated_at.to_i).to eq(Time.now.utc.to_i)
        expect(product2.updated_at.to_i).to eq(Time.now.utc.to_i)
        expect(product2.rexiews_updated_at.to_i).to eq(Time.now.utc.to_i)
      end
    end

    it "skips aggregated counter updates with zero increment" do
      user = User.create
      product1 = Product.create

      expect(user.reviews_count).to eq(0)
      expect(product1.reviews_count).to eq(0)
      expect(user.review_approvals_count).to eq(0)

      Timecop.freeze do
        expect_queries(0, filter: /UPDATE users/) do # all columns are incremented by 0 so no query
          expect_queries(1, filter: /rexiews_updated_at/) do
            expect_queries(0, filter: /rexiews_count/) do # only the timestamp column is updated because counters are incremented by 0
              CounterCulture.aggregate_counter_updates do
                review = user.reviews.create :user_id => user.id, :product_id => product1.id, :approvals => 5
                review.destroy!
              end
            end
          end
        end

        user.reload
        product1.reload

        expect(user.reviews_count).to eq(0)
        expect(user.using_count).to eq(0)
        expect(user.review_approvals_count).to eq(0)
        expect(user.dynamic_delta_count).to eq(0)
        expect(user.custom_delta_count).to eq(0)
        expect(product1.reviews_count).to eq(0)
        expect(product1.rexiews_count).to eq(0)
        expect(product1.updated_at.to_i).to eq(Time.now.utc.to_i)
        expect(product1.rexiews_updated_at.to_i).to eq(Time.now.utc.to_i)
      end
    end

    it "updates counter caches" do
      user = User.create
      product1 = Product.create
      product2 = Product.create
      product3 = Product.create

      expect(user.reviews_count).to eq(0)
      expect(product1.reviews_count).to eq(0)
      expect(product2.reviews_count).to eq(0)
      expect(product3.reviews_count).to eq(0)
      expect(user.review_approvals_count).to eq(0)

      review_to_delete = CounterCulture.aggregate_counter_updates do
        user.reviews.create :user_id => user.id, :product_id => product1.id, :approvals => 5
      end

      user.reload
      product1.reload

      expect(user.reviews_count).to eq(1)
      expect(user.using_count).to eq(1)
      expect(user.review_approvals_count).to eq(5)
      expect(user.dynamic_delta_count).to eq(1)
      expect(user.custom_delta_count).to eq(3)
      expect(product1.reviews_count).to eq(1)
      expect(product1.rexiews_count).to eq(1)

      CounterCulture.aggregate_counter_updates do
        user.reviews.create :user_id => user.id, :product_id => product2.id, :approvals => 10
        user.reviews.create :user_id => user.id, :product_id => product3.id, :approvals => 10
        review_to_delete.destroy!
        review_to_delete.destroy # this does not decrement counter cache a second time
      end

      user.reload
      product1.reload
      product2.reload
      product3.reload

      expect(user.reviews_count).to eq(2)
      expect(user.using_count).to eq(2)
      expect(user.review_approvals_count).to eq(20)
      expect(user.dynamic_delta_count).to eq(2)
      expect(user.custom_delta_count).to eq(6)
      expect(product1.reviews_count).to eq(0)
      expect(product1.rexiews_count).to eq(0)
      expect(product2.reviews_count).to eq(1)
      expect(product2.rexiews_count).to eq(1)
      expect(product3.reviews_count).to eq(1)
      expect(product3.rexiews_count).to eq(1)
    end

    it "skips incrementing counter cache" do
      user = User.create
      category = Category.create

      expect(user.reviews_count).to eq(0)
      expect(user.review_approvals_count).to eq(0)
      expect(category.products_count).to eq(0)

      CounterCulture.aggregate_counter_updates do
        Product.skip_counter_culture_updates do
          Review.skip_counter_culture_updates do
            product = category.products.create
            user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13
          end
        end
      end

      user.reload
      category.reload

      expect(user.reviews_count).to eq(0)
      expect(user.review_approvals_count).to eq(0)
      expect(category.products_count).to eq(0)
    end

    it "increments second-level counter cache" do
      company = Company.create
      user = User.create :manages_company_id => company.id
      product = Product.create

      expect(company.reviews_count).to eq(0)
      expect(user.reviews_count).to eq(0)
      expect(product.reviews_count).to eq(0)
      expect(company.review_approvals_count).to eq(0)

      CounterCulture.aggregate_counter_updates do
        Review.create :user_id => user.id, :product_id => product.id, :approvals => 314
      end

      company.reload
      user.reload
      product.reload

      expect(company.reviews_count).to eq(1)
      expect(company.review_approvals_count).to eq(314)
      expect(user.reviews_count).to eq(1)
      expect(product.reviews_count).to eq(1)
    end

    it "updates the timestamp if touch: true is set" do
      Timecop.freeze do
        user1 = nil
        user2 = nil
        product = nil
        review1 = nil
        review2 = nil

        CounterCulture.aggregate_counter_updates do
          Timecop.travel(10.seconds.ago) do
            user1 = User.create
            user2 = User.create
            product = Product.create

            review1 = Review.create :user_id => user1.id, :product_id => product.id
          end

          review2 = Review.create :user_id => user2.id, :product_id => product.id
        end

        user1.reload; user2.reload; product.reload

        expect(user1.created_at.to_i).to eq(user1.updated_at.to_i)
        expect(user2.created_at.to_i).to eq(user2.updated_at.to_i)
        expect(product.created_at.to_i).to be < product.updated_at.to_i
        expect(product.updated_at.to_i).to eq(review2.created_at.to_i)
        expect(user1.reviews_count).to eq(1)
        expect(user2.reviews_count).to eq(1)
        expect(product.reviews_count).to eq(2)
      end
    end

    it "updates counter correctly when creating using nested attributes" do
      user = CounterCulture.aggregate_counter_updates do
        User.create(:reviews_attributes => [{:some_text => 'abc'}, {:some_text => 'xyz'}])
      end

      user.reload
      expect(user.reviews_count).to eq(2)
    end


    it "increments self-referential counter cache" do
      company = Company.create!

      CounterCulture.aggregate_counter_updates do
        company.children << Company.create!
      end

      company.reload
      expect(company.children_count).to eq(1)
    end

    it "correctly sums up the values for dynamic column names with totaling instead of counting" do
      person = Person.create!

      earning_transaction = CounterCulture.aggregate_counter_updates do
        Transaction.create(monetary_value: 10, person: person)
      end

      person.reload
      expect(person.money_earned_total).to eq(10)

      spending_transaction = CounterCulture.aggregate_counter_updates do
        Transaction.create(monetary_value: -20, person: person)
      end

      person.reload
      expect(person.money_spent_total).to eq(-20)
    end

    it "increments / decrements counter caches correctly for polymorphic association" do
      require 'models/poly_image'
      require 'models/poly_employee'
      require 'models/poly_product'

      employee = PolyEmployee.create(id: 3000)
      product1 = PolyProduct.create()

      expect(employee.poly_images_count).to eq(0)
      expect(product1.poly_images_count).to eq(0)

      img1 = CounterCulture.aggregate_counter_updates do
        PolyImage.create(imageable: employee)
      end

      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(0)

      img2 = CounterCulture.aggregate_counter_updates do
        PolyImage.create(imageable: product1)
      end

      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(1)

      img3 = CounterCulture.aggregate_counter_updates do
        PolyImage.create(imageable: product1)
      end

      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(2)

      CounterCulture.aggregate_counter_updates do
        img3.destroy
      end

      expect(employee.reload.poly_images_count).to eq(1)
      expect(product1.reload.poly_images_count).to eq(1)

      CounterCulture.aggregate_counter_updates do
        img2.imageable = employee
        img2.save!
      end

      expect(employee.reload.poly_images_count).to eq(2)
      expect(product1.reload.poly_images_count).to eq(0)
    end

    it "works with pg money type" do
      if ENV['DB'] != 'postgresql'
        skip("money type only supported in PostgreSQL")
      end

      item = nil
      po = PurchaseOrder.create

      expect(po.total_amount).to eq(0.0)

      CounterCulture.aggregate_counter_updates do
        item = po.purchase_order_items.build(amount: 100.00)
        item.save
      end

      po.reload
      expect(po.total_amount).to eq(100.0)

      CounterCulture.aggregate_counter_updates do
        item = po.purchase_order_items.build(amount: 100.00)
        item.save
      end

      po.reload
      expect(po.total_amount).to eq(200.0)

      CounterCulture.aggregate_counter_updates do
        item.destroy
      end

      po.reload
      expect(po.total_amount).to eq(100.0)

      CounterCulture.aggregate_counter_updates do
        po.purchase_order_items.destroy_all
      end

      po.reload
      expect(po.total_amount).to eq(0.0)
    end

    context "with composite primary keys" do
      before do
      unless CounterCulture.supports_composite_keys?
          skip("composite primary keys not supported in this version of Rails")
        end
      end

      it "increments / decrements the counter cache" do
        group = CompositeGroup.create!(secondary_id: 123)
        user1 = CompositeUser.create!
        user2 = CompositeUser.create!

        expect(group.composite_users_count).to eq(0)

        group_user1 = CounterCulture.aggregate_counter_updates do
          CompositeGroupUser.create!(
            composite_group_id: group.id,
            secondary_id: group.secondary_id,
            composite_user_id: user1.id
          )
        end

        group.reload
        expect(group.composite_users_count).to eq(1)

        group_user2 = CounterCulture.aggregate_counter_updates do
          CompositeGroupUser.create!(
            composite_group_id: group.id,
            secondary_id: group.secondary_id,
            composite_user_id: user2.id
          )
        end

        group.reload
        expect(group.composite_users_count).to eq(2)

        CounterCulture.aggregate_counter_updates do
          group_user1.destroy!
        end

        group.reload
        expect(group.composite_users_count).to eq(1)

        CounterCulture.aggregate_counter_updates do
          group_user2.destroy!
        end

        group.reload
        expect(group.composite_users_count).to eq(0)
      end

      it "optimizes SQL queries when aggregating updates" do
        group = CompositeGroup.create!(secondary_id: 123)
        user1 = CompositeUser.create!
        user2 = CompositeUser.create!
        user3 = CompositeUser.create!

        expect(group.composite_users_count).to eq(0)

        # with aggregation, this should generate only 1 UPDATE query for the group
        expect_queries(1, filter: /UPDATE composite_groups/) do
          CounterCulture.aggregate_counter_updates do
            CompositeGroupUser.create!(
              composite_group_id: group.id,
              secondary_id: group.secondary_id,
              composite_user_id: user1.id
            )
            CompositeGroupUser.create!(
              composite_group_id: group.id,
              secondary_id: group.secondary_id,
              composite_user_id: user2.id
            )
            CompositeGroupUser.create!(
              composite_group_id: group.id,
              secondary_id: group.secondary_id,
              composite_user_id: user3.id
            )
          end
        end
      end
    end
  end

  describe "skip not exists attribute in saved_changes" do
    it "works with not exists attribute in saved_changes", :aggregate_failures do
      article_group = ArticleGroup.create(name: 'group1')

      article = Article.new
      article.article_group_id = article_group.id
      article.title = { 'en' => 'test1', 'ja' => 'テスト１' }
      article.save!

      article_group.reload
      expect(article_group.articles_count).to eq(1)

      article.title = { 'en' => 'test2', 'ja' => 'テスト１' }
      article.save!
      article_group.reload
      expect(article_group.articles_count).to eq(1)
    end
  end

  context "with read replica configuration" do
    let(:company) { Company.create! }

    before do
      company.children << Company.create!
      company.update_column(:children_count, -1)
    end

    context "with Rails 7.1+" do
      before do
        allow_any_instance_of(CounterCulture::WithConnection)
          .to receive(:rails_7_1_or_greater?)
          .and_return(true)
        allow_any_instance_of(CounterCulture::Configuration)
          .to receive(:rails_supports_read_replica?)
          .and_return(true)
      end

      it "uses read replica when enabled" do
        CounterCulture.configure do |config|
          config.use_read_replica = true
        end

        roles_used = []
        allow(ActiveRecord::Base).to receive(:connected_to).and_wrap_original do |original, **kwargs, &block|
          roles_used << kwargs[:role]
          block.call if block
        end

        Company.counter_culture_fix_counts

        expect(roles_used).to include(:reading)
        expect(roles_used - [:reading]).to all(eq(:writing))
      end

      it "does not use read replica when disabled" do
        CounterCulture.configure do |config|
          config.use_read_replica = false
        end

        roles_used = []
        allow(ActiveRecord::Base).to receive(:connected_to).and_wrap_original do |original, **kwargs, &block|
          roles_used << kwargs[:role]
          block.call if block
        end

        Company.counter_culture_fix_counts

        expect(roles_used).to include(:writing)
      end
    end

    context "with Rails < 7.1" do
      before do
        allow_any_instance_of(CounterCulture::WithConnection)
          .to receive(:rails_7_1_or_greater?)
          .and_return(false)
        allow_any_instance_of(CounterCulture::Configuration)
          .to receive(:rails_supports_read_replica?)
          .and_return(false)
      end

      it "works without read replica support" do
        # Should raise error when trying to enable read replica
        expect {
          CounterCulture.configure do |config|
            config.use_read_replica = true
          end
        }.to raise_error("Counter Culture's read replica support requires Rails 7.1 or higher")

        # Should not use connected_to at all
        expect(ActiveRecord::Base).not_to receive(:connected_to)

        Company.counter_culture_fix_counts
        expect(company.reload.children_count).to eq(1)
      end
    end
  end
end
