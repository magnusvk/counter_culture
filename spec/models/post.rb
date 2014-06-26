class Post < ActiveRecord::Base
	self.primary_key = :post_id

	belongs_to :category
	counter_culture :category, :column_name => :posts_count
end
