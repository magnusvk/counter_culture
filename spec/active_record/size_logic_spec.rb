require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

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
require 'models/with_module/model1'
require 'models/with_module/model2'
require 'models/poly_image'
require 'models/poly_employee'
require 'models/poly_product'

require 'database_cleaner'
DatabaseCleaner.strategy = :deletion

describe 'ActiveRecord#size' do
  before(:each) do
    DatabaseCleaner.clean
  end

  context 'Company has_many Children' do
    it '#size should return the number of the cache column' do
      company = Company.create!
      Company.where(id: company.id).update_all(children_count: 99)
      company.reload

      expect(company.children_count).to eq(99)
      expect(company.children.size).to  eq(99)
    end
  end

  context 'Product (is Imageable and) has_many PolyImages' do
    it '#size should return the number of the cache column' do
      poly_product = PolyProduct.create!
      PolyProduct.where(pp_pk_id: poly_product.pp_pk_id).update_all(poly_images_count: 99)
      poly_product.reload

      expect(poly_product.poly_images_count).to eq(99)
      expect(poly_product.poly_images.size).to  eq(99)
    end
  end

  context 'ConditionalMain has_many ConditionalDependent' do
    it '#size should return the number of the cache column' do
      main = ConditionalMain.create!
      ConditionalMain.where(id: main.id).update_all(conditional_dependents_count: 99)
      main.reload

      expect(main.conditional_dependents_count).to eq(99)
      # skip 'This fails because klass.new.condition? returns false then the column name is nil.'
      expect(main.conditional_dependents.size).to  eq(99)
    end
  end
end
