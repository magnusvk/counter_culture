class PostComment < ActiveRecord::Base
  self.primary_key = :post_id

  belongs_to :post, :foreign_key => 'post_id'
  counter_culture :post, :column_name => :comments_count, touch: { custom_touch_field: -> (comment) { comment.id + 42 } }
end
