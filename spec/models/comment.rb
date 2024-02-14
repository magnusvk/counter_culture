class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true
  has_many :comments, as: :commentable, inverse_of: :commentable

  counter_culture :commentable, :column_name => :comments_count
end
