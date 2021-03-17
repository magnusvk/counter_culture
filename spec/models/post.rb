class Post < ActiveRecord::Base
  self.primary_key = :post_id

  belongs_to :subcateg, :foreign_key => :fk_subcat_id

  has_many :post_comments
  counter_culture :subcateg, :column_name => :posts_count
  counter_culture :subcateg, :column_name => :posts_after_commit_count,
    :execute_after_commit => true,
    :with_papertrail => PapertrailSupport.supported_here?

  counter_culture [:subcateg, :categ]
end
