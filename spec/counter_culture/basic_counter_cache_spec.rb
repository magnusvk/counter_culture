require 'spec_helper'

RSpec.describe "CounterCulture basic counter cache" do
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

  it "should correctly increment and decrement conditional counters of associated objects" do
    conditional_main = ConditionalMain.create
    conditional_dependent = conditional_main.conditional_dependents.create(condition: false)

    expect(conditional_main.conditional_dependents_count).to eq(0)

    conditional_dependent.update(condition: true)

    expect(conditional_main.conditional_dependents_count).to eq(1)

    conditional_dependent.update(condition: false)

    expect(conditional_main.conditional_dependents_count).to eq(0)
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

  it "should update counts correctly when creating using nested attributes" do
    user = User.create(:reviews_attributes => [{:some_text => 'abc'}, {:some_text => 'xyz'}])
    user.reload
    expect(user.reviews_count).to eq(2)
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
end
