class AnotherPostComment < ActiveRecord::Base
  belongs_to :post, class_name: 'AnotherPost', foreign_key: 'another_post_id', primary_key: 'another_id'
  counter_culture :post
end
