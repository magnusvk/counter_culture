require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'models/company'
require 'models/industry'
require 'models/product'
require 'models/review'
require 'models/user'
require 'models/category'

describe "CounterCulture" do
  it "increments counter cache on create" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    user.reload
    product.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "decrements counter cache on destroy" do
    user = User.create
    product = Product.create

    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    user.reload
    product.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1

    review.destroy

    user.reload
    product.reload

    user.reviews_count.should == 0
    product.reviews_count.should == 0
  end

  it "updates counter cache on update" do
    user1 = User.create
    user2 = User.create
    product = Product.create

    user1.reviews_count.should == 0
    user2.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id
    
    user1.reload
    user2.reload
    product.reload

    user1.reviews_count.should == 1
    user2.reviews_count.should == 0
    product.reviews_count.should == 1

    review.user = user2
    review.save!

    user1.reload
    user2.reload
    product.reload

    user1.reviews_count.should == 0
    user2.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "increments second-level counter cache on create" do
    company = Company.create
    user = User.create :company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    company.reload
    user.reload
    product.reload

    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "decrements second-level counter cache on destroy" do
    company = Company.create
    user = User.create :company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    user.reload
    product.reload
    company.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1
    company.reviews_count.should == 1

    review.destroy

    user.reload
    product.reload
    company.reload

    user.reviews_count.should == 0
    product.reviews_count.should == 0
    company.reviews_count.should == 0
  end

  it "updates second-level counter cache on update" do
    company1 = Company.create
    company2 = Company.create
    user1 = User.create :company_id => company1.id
    user2 = User.create :company_id => company2.id
    product = Product.create

    user1.reviews_count.should == 0
    user2.reviews_count.should == 0
    company1.reviews_count.should == 0
    company2.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id
    
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
    user = User.create :company_id => company.id
    product = Product.create

    industry.reviews_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 1
    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "decrements third-level counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :company_id => company.id
    product = Product.create

    industry.reviews_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 1
    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1

    review.destroy

    industry.reload
    company.reload
    user.reload
    product.reload

    industry.reviews_count.should == 0
    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0
  end

  it "updates third-level counter cache on update" do
    industry1 = Industry.create
    industry2 = Industry.create
    company1 = Company.create :industry_id => industry1.id
    company2 = Company.create :industry_id => industry2.id
    user1 = User.create :company_id => company1.id
    user2 = User.create :company_id => company2.id
    product = Product.create

    industry1.reviews_count.should == 0
    industry2.reviews_count.should == 0
    company1.reviews_count.should == 0
    company2.reviews_count.should == 0
    user1.reviews_count.should == 0
    user2.reviews_count.should == 0

    review = Review.create :user_id => user1.id, :product_id => product.id
    
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
  end

  it "increments third-level custom counter cache on create" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :company_id => company.id
    product = Product.create

    industry.rexiews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    industry.reload

    industry.rexiews_count.should == 1
  end

  it "decrements third-level custom counter cache on destroy" do
    industry = Industry.create
    company = Company.create :industry_id => industry.id
    user = User.create :company_id => company.id
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
    user1 = User.create :company_id => company1.id
    user2 = User.create :company_id => company2.id
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
    user = User.create :company_id => company.id
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
    user = User.create :company_id => company.id
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
    user1 = User.create :company_id => company1.id
    user2 = User.create :company_id => company2.id
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

    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    user.reload
    product.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1

    user.reviews_count = 0
    product.reviews_count = 2
    user.save!
    product.save!

    fixed = Review.counter_culture_fix_counts :skip_unsupported => true
    fixed.length.should == 2

    user.reload
    product.reload

    user.reviews_count.should == 1
    product.reviews_count.should == 1
  end

  it "should fix a second-level counter cache correctly" do
    company = Company.create
    user = User.create :company_id => company.id
    product = Product.create

    company.reviews_count.should == 0
    user.reviews_count.should == 0
    product.reviews_count.should == 0

    review = Review.create :user_id => user.id, :product_id => product.id
    
    company.reload
    user.reload
    product.reload

    company.reviews_count.should == 1
    user.reviews_count.should == 1
    product.reviews_count.should == 1

    company.reviews_count = 2
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

end
