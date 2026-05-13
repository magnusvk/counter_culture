require 'spec_helper'

RSpec.describe "CounterCulture touch option" do
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

  it "should touch the record when the counter cache is updated" do
    post = Post.create!
    Timecop.travel(2.second.from_now) do
      expect { PostLike.create!(post: post) }.to change { post.reload.updated_at }
    end
  end
end
