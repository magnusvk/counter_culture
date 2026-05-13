require 'spec_helper'

RSpec.describe "CounterCulture advanced features (float sums, touch, nested attrs, relation primary keys, after_commit, has_one)" do
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
end
