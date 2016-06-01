class Subcateg < ActiveRecord::Base
  SUBCAT_1 = 0
  SUBCAT_2 = 1

  self.primary_key = :subcat_id

  has_many :posts
  belongs_to :categ, :foreign_key => :fk_cat_id
end
