require 'spec_helper'

RSpec.describe "CounterCulture with aggregate_counter_updates" do
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
