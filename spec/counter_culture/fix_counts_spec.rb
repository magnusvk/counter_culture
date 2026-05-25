require 'spec_helper'

RSpec.describe "CounterCulture fix_counts" do
  it "should raise a good error message when calling fix_counts with no caches defined" do
    expect { Category.counter_culture_fix_counts }.to raise_error "No counter cache defined on Category"
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

  it "should fix counter cache with multiple STI models in association chain correctly" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    admin = AdminUser.create :manages_company_id => company.id

    expect(company.admin_reviews_count).to eq(0)

    TwitterReview.create :user_id => user.id
    TwitterReview.create :admin_user_id => admin.id

    company.reload

    expect(company.admin_reviews_count).to eq(1)

    company.admin_reviews_count = 2
    company.save!

    TwitterReview.counter_culture_fix_counts :skip_unsupported => true

    company.reload

    expect(company.admin_reviews_count).to eq(1)
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
end
