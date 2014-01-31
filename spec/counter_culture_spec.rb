require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'models/company'
require 'models/industry'
require 'models/product'
require 'models/review'
require 'models/user'
require 'models/category'
require 'models/has_string_id'
require 'models/simple_main'
require 'models/simple_dependent'

require 'database_cleaner'
DatabaseCleaner.strategy = :deletion

describe "CounterCulture" do
  before(:each) do
    DatabaseCleaner.clean
  end

  it "increments counter cache on create" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    product.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13, :review_text => '+17'

    user.reload
    product.reload

    user.reviews_count.should == 1
    user.review_approvals_count.should == 13
    user.review_text_approvals_count.should == 17
    product.reviews_count.should == 1
  end

  it "decrements counter cache on destroy" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    product.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 69, :review_text => '+51'

    user.reload
    product.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1
    user.review_approvals_count.should == 69
    user.review_text_approvals_count.should == 51

    review.destroy

    user.reload
    product.reload

    user.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0
    product.reviews_count.should == 0
  end

  it "updates counter cache on update" do
    user1 = User.create
    user2 = User.create
    product = Product.create

    user1.reviews_count.should == 0
    user2.reviews_count.should == 0
    product.reviews_count.should == 0
    user1.review_approvals_count.should == 0
    user2.review_approvals_count.should == 0
    user1.review_text_approvals_count.should == 0
    user2.review_text_approvals_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 42, :review_text => '+48'

    user1.reload
    user2.reload
    product.reload

    user1.reviews_count.should == 1
    user2.reviews_count.should == 0
    product.reviews_count.should == 1
    user1.review_approvals_count.should == 42
    user2.review_approvals_count.should == 0
    user1.review_text_approvals_count.should == 48
    user2.review_text_approvals_count.should == 0

    review.user = user2
    review.save!

    user1.reload
    user2.reload
    product.reload

    user1.reviews_count.should == 0
    user2.reviews_count.should == 1
    product.reviews_count.should == 1
    user1.review_approvals_count.should == 0
    user2.review_approvals_count.should == 42
    user1.review_text_approvals_count.should == 0
    user2.review_text_approvals_count.should == 48

    review.update_attribute(:approvals, 69)
    user2.reload.review_approvals_count.should == 69
    review.update_attribute(:review_text, '+73')
    user2.reload.review_text_approvals_count.should == 73
  end

  it "treats null delta column values as 0" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    product.reviews_count.should == 0
    user.review_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => nil

    user.reload
    product.reload

    user.reviews_count.should == 1
    user.review_approvals_count.should == 0
    product.reviews_count.should == 1
  end

  it "increments second-level counter cache on create" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0
    company.review_approvals_count.should == 0
    company.review_text_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 314, :review_text => '+302'

    company.reload
    user.reload
    product.reload

    company.reviews_count.should == 1
    company.review_approvals_count.should == 314
    company.review_text_approvals_count.should == 302
    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "decrements second-level counter cache on destroy" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0
    company.review_approvals_count.should == 0
    company.review_text_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 314, :review_text => '+317'

    user.reload
    product.reload
    company.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1
    company.reviews_count.should == 1
    company.review_approvals_count.should == 314
    company.review_text_approvals_count.should == 317

    review.destroy

    user.reload
    product.reload
    company.reload

    user.reviews_count.should == 0
    product.reviews_count.should == 0
    company.reviews_count.should == 0
    company.review_approvals_count.should == 0
    company.review_text_approvals_count.should == 0
  end

  it "updates second-level counter cache on update" do
    company1 = Company.create
    company2 = Company.create
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    user1.reviews_count.should == 0
    user2.reviews_count.should == 0
    company1.reviews_count.should == 0
    company2.reviews_count.should == 0
    product.reviews_count.should == 0
    company1.review_approvals_count.should == 0
    company2.review_approvals_count.should == 0
    company1.review_text_approvals_count.should == 0
    company2.review_text_approvals_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 69, :review_text => '+85'

    user1.reload
    user2.reload
    company1.reload
    company2.reload
    product.reload

    user1.reviews_count.should == 1
    user2.reviews_count.should == 0
    company1.reviews_count.should == 1
    company2.reviews_count.should == 0
    product.reviews_count.should == 1
    company1.review_approvals_count.should == 69
    company2.review_approvals_count.should == 0
    company1.review_text_approvals_count.should == 85
    company2.review_text_approvals_count.should == 0

    review.user = user2
    review.save!

    user1.reload
    user2.reload
    company1.reload
    company2.reload
    product.reload

    user1.reviews_count.should == 0
    user2.reviews_count.should == 1
    company1.reviews_count.should == 0
    company2.reviews_count.should == 1
    product.reviews_count.should == 1
    company1.review_approvals_count.should == 0
    company2.review_approvals_count.should == 69
    company1.review_text_approvals_count.should == 0
    company2.review_text_approvals_count.should == 85

    review.update_attribute(:approvals, 42)
    company2.reload.review_approvals_count.should == 42
    review.update_attribute(:review_text, '+37')
    company2.reload.review_text_approvals_count.should == 37
  end

  it "increments custom counter cache column on create" do
    user = User.create
    product = Product.create

    product.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    product.rexiews_count.should == 1
  end

  it "decrements custom counter cache column on destroy" do
    user = User.create
    product = Product.create

    product.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    product.rexiews_count.should == 1

    review.destroy

    product.reload

    product.rexiews_count.should == 0
  end

  it "updates custom counter cache column on update" do
    user = User.create
    product1 = Product.create
    product2 = Product.create

    product1.rexiews_count.should == 0
    product2.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product1.id

    product1.reload
    product2.reload

    product1.rexiews_count.should == 1
    product2.rexiews_count.should == 0

    review.product = product2
    review.save!

    product1.reload
    product2.reload

    product1.rexiews_count.should == 0
    product2.rexiews_count.should == 1
  end

  it "handles nil column name in custom counter cache on create" do
    user = User.create
    product = Product.create

    user.using_count.should == 0
    user.tried_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil

    user.reload

    user.using_count.should == 0
    user.tried_count.should == 0
  end

  it "handles nil column name in custom counter cache on destroy" do
    user = User.create
    product = Product.create

    user.using_count.should == 0
    user.tried_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil

    product.reload

    user.using_count.should == 0
    user.tried_count.should == 0

    review.destroy

    product.reload

    user.using_count.should == 0
    user.tried_count.should == 0
  end

  it "handles nil column name in custom counter cache on update" do
    product = Product.create
    user1 = User.create
    user2 = User.create

    user1.using_count.should == 0
    user1.tried_count.should == 0
    user2.using_count.should == 0
    user2.tried_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id, :review_type => nil

    user1.reload
    user2.reload

    user1.using_count.should == 0
    user1.tried_count.should == 0
    user2.using_count.should == 0
    user2.tried_count.should == 0

    review.user = user2
    review.save!

    user1.reload
    user2.reload

    user1.using_count.should == 0
    user1.tried_count.should == 0
    user2.using_count.should == 0
    user2.tried_count.should == 0
  end

  describe "conditional counts on update" do
    let(:product) {Product.create!}
    let(:user) {User.create!}

    it "should increment and decrement if changing column name" do
      user.using_count.should == 0
      user.tried_count.should == 0

      review = Review.create :user_id => user.id, :product_id => product.id, :review_type => "using"
      user.reload

      user.using_count.should == 1
      user.tried_count.should == 0

      review.review_type = "tried"
      review.save!

      user.reload

      user.using_count.should == 0
      user.tried_count.should == 1
    end

    it "should increment if changing from a nil column name" do
      user.using_count.should == 0
      user.tried_count.should == 0

      review = Review.create :user_id => user.id, :product_id => product.id, :review_type => nil
      user.reload

      user.using_count.should == 0
      user.tried_count.should == 0

      review.review_type = "tried"
      review.save!

      user.reload

      user.using_count.should == 0
      user.tried_count.should == 1
    end

    it "should decrement if changing column name to nil" do
      user.using_count.should == 0
      user.tried_count.should == 0

      review = Review.create :user_id => user.id, :product_id => product.id, :review_type => "using"
      user.reload

      user.using_count.should == 1
      user.tried_count.should == 0

      review.review_type = nil
      review.save!

      user.reload

      user.using_count.should == 0
      user.tried_count.should == 0
    end
  end

  it "increments third-level counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.reviews_count.should == 0
    industry.review_approvals_count.should == 0
    industry.review_text_approvals_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42, :review_text => '+53'

    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 1
    industry.review_approvals_count.should == 42
    industry.review_text_approvals_count.should == 53
    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "decrements third-level counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.reviews_count.should == 0
    industry.review_approvals_count.should == 0
    industry.review_text_approvals_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42, :review_text => '+57'

    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 1
    industry.review_approvals_count.should == 42
    industry.review_text_approvals_count.should == 57
    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1

    review.destroy

    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 0
    industry.review_approvals_count.should == 0
    industry.review_text_approvals_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0
  end

  it "updates third-level counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    industry1.reviews_count.should == 0
    industry2.reviews_count.should == 0
    company1.reviews_count.should == 0
    company2.reviews_count.should == 0
    user1.reviews_count.should == 0
    user2.reviews_count.should == 0
    industry1.review_approvals_count.should == 0
    industry2.review_approvals_count.should == 0
    industry1.review_text_approvals_count.should == 0
    industry2.review_text_approvals_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id, :approvals => 42, :review_text => '+33'

    industry1.reload
    industry2.reload
    company1.reload
    company2.reload
    user1.reload
    user2.reload

    industry1.reviews_count.should == 1
    industry2.reviews_count.should == 0
    company1.reviews_count.should == 1
    company2.reviews_count.should == 0
    user1.reviews_count.should == 1
    user2.reviews_count.should == 0
    industry1.review_approvals_count.should == 42
    industry2.review_approvals_count.should == 0
    industry1.review_text_approvals_count.should == 33
    industry2.review_text_approvals_count.should == 0

    review.user = user2
    review.save!

    industry1.reload
    industry2.reload
    company1.reload
    company2.reload
    user1.reload
    user2.reload

    industry1.reviews_count.should == 0
    industry2.reviews_count.should == 1
    company1.reviews_count.should == 0
    company2.reviews_count.should == 1
    user1.reviews_count.should == 0
    user2.reviews_count.should == 1
    industry1.review_approvals_count.should == 0
    industry2.review_approvals_count.should == 42
    industry1.review_text_approvals_count.should == 0
    industry2.review_text_approvals_count.should == 33

    review.update_attribute(:approvals, 69)
    industry2.reload.review_approvals_count.should == 69
    review.update_attribute(:review_text, '-2')
    industry2.reload.review_text_approvals_count.should == -2
  end

  it "increments third-level custom counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id

    industry.reload

    industry.rexiews_count.should == 1
  end

  it "decrements third-level custom counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id

    industry.reload
    industry.rexiews_count.should == 1

    review.destroy

    industry.reload
    industry.rexiews_count.should == 0
  end

  it "updates third-level custom counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    industry1.rexiews_count.should == 0
    industry2.rexiews_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id

    industry1.reload
    industry1.rexiews_count.should == 1
    industry2.reload
    industry2.rexiews_count.should == 0

    review.user = user2
    review.save!

    industry1.reload
    industry1.rexiews_count.should == 0
    industry2.reload
    industry2.rexiews_count.should == 1
  end

  it "increments dynamic counter cache on create" do
    user = User.create
    product = Product.create

    user.using_count.should == 0
    user.tried_count.should == 0

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 0

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 1
  end

  it "decrements dynamic counter cache on destroy" do
    user = User.create
    product = Product.create

    user.using_count.should == 0
    user.tried_count.should == 0

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 0

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 1

    review_tried.destroy

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 0

    review_using.destroy

    user.reload

    user.using_count.should == 0
    user.tried_count.should == 0
  end

  it "increments third-level dynamic counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.using_count.should == 0
    industry.tried_count.should == 0

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    industry.reload

    industry.using_count.should == 1
    industry.tried_count.should == 0

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    industry.reload

    industry.using_count.should == 1
    industry.tried_count.should == 1
  end

  it "decrements third-level custom counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :manages_company_id => company.id
    product = Product.create

    industry.using_count.should == 0
    industry.tried_count.should == 0

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    industry.reload

    industry.using_count.should == 1
    industry.tried_count.should == 0

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    industry.reload

    industry.using_count.should == 1
    industry.tried_count.should == 1

    review_tried.destroy

    industry.reload

    industry.using_count.should == 1
    industry.tried_count.should == 0

    review_using.destroy

    industry.reload

    industry.using_count.should == 0
    industry.tried_count.should == 0
  end

  it "updates third-level custom counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :manages_company_id => company1.id
    user2 = User.create :manages_company_id => company2.id
    product = Product.create

    industry1.using_count.should == 0
    industry1.tried_count.should == 0
    industry2.using_count.should == 0
    industry2.tried_count.should == 0

    review_using = Review.create :user_id => user1.id, :product_id => product.id, :review_type => 'using'

    industry1.reload
    industry2.reload

    industry1.using_count.should == 1
    industry1.tried_count.should == 0
    industry2.using_count.should == 0
    industry2.tried_count.should == 0

    review_tried = Review.create :user_id => user1.id, :product_id => product.id, :review_type => 'tried'

    industry1.reload
    industry2.reload

    industry1.using_count.should == 1
    industry1.tried_count.should == 1
    industry2.using_count.should == 0
    industry2.tried_count.should == 0

    review_tried.user = user2
    review_tried.save!

    industry1.reload
    industry2.reload

    industry1.using_count.should == 1
    industry1.tried_count.should == 0
    industry2.using_count.should == 0
    industry2.tried_count.should == 1

    review_using.user = user2
    review_using.save!

    industry1.reload
    industry2.reload

    industry1.using_count.should == 0
    industry1.tried_count.should == 0
    industry2.using_count.should == 1
    industry2.tried_count.should == 1
  end

  it "should overwrite foreign-key values on create" do
    3.times { Category.create }
    Category.all {|category| category.products_count.should == 0 }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| category.products_count.should == 1 }
  end

  it "should overwrite foreign-key values on destroy" do
    3.times { Category.create }
    Category.all {|category| category.products_count.should == 0 }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| category.products_count.should == 1 }

    product.destroy
    Category.all {|category| category.products_count.should == 0 }
  end

  it "should overwrite foreign-key values on destroy" do
    3.times { Category.create }
    Category.all {|category| category.products_count.should == 0 }

    product = Product.create :category_id => Category.first.id
    Category.all {|category| category.products_count.should == 1 }

    product.category = nil
    product.save!
    Category.all {|category| category.products_count.should == 0 }
  end


  it "should fix a simple counter cache correctly" do
    user = User.create
    product = Product.create

    product.reviews_count.should == 0
    user.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 69, :review_text => '+91'

    user.reload
    product.reload

    product.reviews_count.should == 1
    user.reviews_count.should == 1
    user.review_approvals_count.should == 69
    user.review_text_approvals_count.should == 91

    product.reviews_count = 2
    user.reviews_count = 0
    user.review_approvals_count = 7
    user.review_text_approvals_count = 5

    product.save!
    user.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    puts fixed
    fixed.length.should == 4

    product.reload
    user.reload

    product.reviews_count.should == 1
    user.reviews_count.should == 1
    user.review_approvals_count.should == 69
    user.review_text_approvals_count.should == 91
  end

  it "should fix where the count should go back to zero correctly" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0

    user.reviews_count = -1
    user.review_approvals_count = -2
    user.review_text_approvals_count = -3
    user.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    fixed.length.should == 3

    user.reload

    user.reviews_count.should == 0
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0
  end

  it "should fix a second-level counter cache correctly" do
    company = Company.create
    user = User.create :manages_company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0
    company.review_approvals_count.should == 0
    company.review_text_approvals_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id, :approvals => 42, :review_text => '+23'

    company.reload
    user.reload
    product.reload

    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1
    company.review_approvals_count.should == 42
    company.review_text_approvals_count.should == 23

    company.reviews_count = 2
    company.review_approvals_count = 7
    company.review_text_approvals_count = 7
    user.reviews_count = 3
    product.reviews_count = 4
    company.save!
    user.save!
    product.save!

    Review.counter_culture_fix_counts :skip_unsupported => true
    company.reload
    user.reload
    product.reload

    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1
    company.review_approvals_count.should == 42
    company.review_text_approvals_count.should == 23
  end

  it "should fix a custom counter cache correctly" do
    user = User.create
    product = Product.create

    product.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id

    product.reload

    product.rexiews_count.should == 1

    product.rexiews_count = 2
    product.save!

    Review.counter_culture_fix_counts :skip_unsupported => true

    product.reload
    product.rexiews_count.should == 1
  end

  it "should fix a dynamic counter cache correctly" do
    user = User.create
    product = Product.create

    user.using_count.should == 0
    user.tried_count.should == 0

    review_using = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'using'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 0

    review_tried = Review.create :user_id => user.id, :product_id => product.id, :review_type => 'tried'

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 1

    user.using_count = 2
    user.tried_count = 3
    user.save!

    Review.counter_culture_fix_counts :skip_unsupported => true

    user.reload

    user.using_count.should == 1
    user.tried_count.should == 1
  end

  it "should fix a string counter cache correctly" do
    string_id = HasStringId.create({:id => "bbb"})

    user = User.create :has_string_id_id => string_id.id

    string_id.reload
    string_id.users_count.should == 1

    user2 = User.create :has_string_id_id => string_id.id

    string_id.reload
    string_id.users_count.should == 2

    string_id.users_count = 123
    string_id.save!

    string_id.reload
    string_id.users_count.should == 123

    User.counter_culture_fix_counts

    string_id.reload
    string_id.users_count.should == 2
  end

  it "should raise a good error message when calling fix_counts with no caches defined" do
    expect { Category.counter_culture_fix_counts }.to raise_error "No counter cache defined on Category"
  end

  it "should correctly fix the counter caches with thousands of records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    1000.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| main.simple_dependents_count.should == 3 }

    SimpleMain.order('random()').limit(50).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => 100

    SimpleMain.find_each { |main| main.simple_dependents_count.should == 3 }
  end

  it "should correctly fix the counter caches when no dependent record exists for some of main records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    1000.times do |i|
      main = SimpleMain.create
      (main.id % 4).times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| main.simple_dependents_count.should == main.id % 4 }

    SimpleMain.order('random()').limit(50).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => 100

    SimpleMain.find_each { |main| main.simple_dependents_count.should == main.id % 4 }
  end

  # This test is for the delta case the last object is a special ending condition.
  it "should correctly fix the last has many object with a belongs to and the following ones" do
    user1 = User.create
    user2 = User.create
    user3 = User.create

    user1.review_text_approvals_count.should == 0
    # Last object with a belongs to:
    user2.review_text_approvals_count.should == 0
    # After the last. Count must be 0:
    user3.review_text_approvals_count.should == 0

    review1 = Review.create :user_id => user1.id, :review_text => '+1'
    review2 = Review.create :user_id => user2.id, :review_text => '+2'

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 2
    user3.review_text_approvals_count.should == 0

    user1.review_text_approvals_count = 53
    user2.review_text_approvals_count = 67
    user3.review_text_approvals_count = 75

    user1.save!
    user2.save!
    user3.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    fixed.length.should == 3

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 2
    user3.review_text_approvals_count.should == 0
  end

  # This test is specially critical for `:delta`, since its counts may split across multiple batches.
  it "should correctly fix counters when there are more belong to elements than batch_size" do
    user = User.create
    user.review_approvals_count.should == 0
    user.review_text_approvals_count.should == 0

    review1 = Review.create :user_id => user.id, :approvals => 1, :review_text => '+3'
    review2 = Review.create :user_id => user.id, :approvals => 2, :review_text => '+4'

    user.reload
    user.review_approvals_count.should == 3
    user.review_text_approvals_count.should == 7

    user.review_approvals_count = -1
    user.review_text_approvals_count = -1
    user.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true, :batch_size => 1
    fixed.length.should == 2

    user.reload
    user.review_approvals_count.should == 3
    user.review_text_approvals_count.should == 7
  end

  # This test is specially critical for `:delta`, since its counts may split across multiple batches.
  it "should correctly fix counters when one has_many is split across multiple batches" do
    user1 = User.create
    user2 = User.create
    user3 = User.create

    user1.review_text_approvals_count.should == 0
    user2.review_text_approvals_count.should == 0
    user3.review_text_approvals_count.should == 0

    review1   = Review.create :user_id => user1.id, :review_text => '+1'
    review2   = Review.create :user_id => user2.id, :review_text => '+2'
    review3_1 = Review.create :user_id => user3.id, :review_text => '+4'
    # END OF FIRST BATCH. Next reviews falls on next batch.
    review3_2 = Review.create :user_id => user3.id, :review_text => '+8'
    review3_3 = Review.create :user_id => user3.id, :review_text => '+16'

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 2
    user3.review_text_approvals_count.should == 28

    user1.review_text_approvals_count = 57
    user2.review_text_approvals_count = 62
    user3.review_text_approvals_count = -4

    user1.save!
    user2.save!
    user3.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true, :batch_size => 3
    fixed.length.should == 3

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 2
    user3.review_text_approvals_count.should == 28
  end

  # This test is specially critical for `:delta`, since special code must take care of the zero case.
  it "should correctly fix counters when one has_many in the middle of the batch has no belongs_to" do
    user1 = User.create
    user2 = User.create
    user3 = User.create

    user1.review_text_approvals_count.should == 0
    # This user (has_many) will have no reviews (belongs_to):
    user2.review_text_approvals_count.should == 0
    user3.review_text_approvals_count.should == 0

    review1 = Review.create :user_id => user1.id, :review_text => '+1'
    review3 = Review.create :user_id => user3.id, :review_text => '+2'

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 0
    user3.review_text_approvals_count.should == 2

    user1.review_text_approvals_count = 57
    user2.review_text_approvals_count = 62
    user3.review_text_approvals_count = -4

    user1.save!
    user2.save!
    user3.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true, :batch_size => 3
    fixed.length.should == 3

    user1.reload
    user2.reload
    user3.reload

    user1.review_text_approvals_count.should == 1
    user2.review_text_approvals_count.should == 0
    user3.review_text_approvals_count.should == 2
  end

  it "should correctly sum up float values" do
    user = User.create

    r1 = Review.create :user_id => user.id, :value => 3.4

    user.reload
    user.review_value_sum.round(1).should == 3.4

    r2 = Review.create :user_id => user.id, :value => 7.2

    user.reload
    user.review_value_sum.round(1).should == 10.6

    r3 = Review.create :user_id => user.id, :value => 5

    user.reload
    user.review_value_sum.round(1).should == 15.6

    r2.destroy

    user.reload
    user.review_value_sum.round(1).should == 8.4

    r3.destroy

    user.reload
    user.review_value_sum.round(1).should == 3.4

    r1.destroy

    user.reload
    user.review_value_sum.round(1).should == 0
  end

  it "should work correctly for relationships with custom names" do
    company = Company.create
    user1 = User.create :manages_company_id => company.id

    company.reload
    company.managers_count.should == 1

    user2 = User.create :manages_company_id => company.id

    company.reload
    company.managers_count.should == 2

    user2.destroy

    company.reload
    company.managers_count.should == 1

    company2 = Company.create
    user1.manages_company_id = company2.id
    user1.save!

    company.reload
    company.managers_count.should == 0
  end

  it "should work correctly with string keys" do
    string_id = HasStringId.create(id: "1")
    string_id2 = HasStringId.create(id: "abc")

    user = User.create :has_string_id_id => string_id.id

    string_id.reload
    string_id.users_count.should == 1

    user2 = User.create :has_string_id_id => string_id.id

    string_id.reload
    string_id.users_count.should == 2

    user2.has_string_id_id = string_id2.id
    user2.save!

    string_id.reload
    string_id2.reload
    string_id.users_count.should == 1
    string_id2.users_count.should == 1

    user2.destroy
    string_id.reload
    string_id2.reload
    string_id.users_count.should == 1
    string_id2.users_count.should == 0

    user.destroy
    string_id.reload
    string_id2.reload
    string_id.users_count.should == 0
    string_id2.users_count.should == 0
  end

  it "should update the timestamp if touch: true is set" do
    user = User.create
    product = Product.create

    sleep 1

    review = Review.create :user_id => user.id, :product_id => product.id

    user.reload; product.reload

    user.created_at.to_i.should == user.updated_at.to_i
    product.created_at.to_i.should < product.updated_at.to_i
  end

  describe "#previous_model" do
    let(:user){User.create :name => "John Smith", :manages_company_id => 1}

    it "should return a copy of the original model" do
      user.name = "Joe Smith"
      user.manages_company_id = 2
      prev = user.send(:previous_model)

      prev.name.should == "John Smith"
      prev.manages_company_id.should == 1

      user.name.should =="Joe Smith"
      user.manages_company_id.should == 2
    end
  end

end
