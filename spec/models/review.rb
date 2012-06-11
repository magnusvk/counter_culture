class Review < ActiveRecord::Base
  belongs_to :user
  belongs_to :product

  counter_culture :product
  counter_culture :product, :column_name => 'rexiews_count'
  counter_culture :user
  counter_culture :user, :column_name => Proc.new { |model| model.review_type ? "#{model.review_type}_count" : nil }, :column_names => {"reviews.review_type = 'using'" => 'using_count', "reviews.review_type = 'tried'" => 'tried_count'}
  counter_culture [:user, :company]
  counter_culture [:user, :company, :industry]
  counter_culture [:user, :company, :industry], :column_name => 'rexiews_count'
  counter_culture [:user, :company, :industry], :column_name => Proc.new { |model| model.review_type ? "#{model.review_type}_count" : nil }
end
