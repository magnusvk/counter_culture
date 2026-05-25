require 'spec_helper'

RSpec.describe "CounterCulture foreign_key_values option" do
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

  it "should overwrite foreign-key values on dissociation" do
    categories = 3.times.map { Category.create }
    categories.each {|category| expect(category.products_count).to eq(0) }

    product = Product.create :category_id => Category.first.id
    categories.each {|category| expect(category.reload.products_count).to eq(1) }

    product.category = nil
    product.save!
    categories.each {|category| expect(category.reload.products_count).to eq(0) }
  end
end
