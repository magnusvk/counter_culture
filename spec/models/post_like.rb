class PostLike < ActiveRecord::Base
  belongs_to :post, :foreign_key => 'post_id'
  counter_culture :post, :column_name => :likes_count, touch: true
end