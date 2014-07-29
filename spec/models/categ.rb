class Categ < ActiveRecord::Base
  CAT_1 = 0
  CAT_2 = 1

  self.primary_key = :cat_id

  has_many :subcategs, :foreign_key => :subcat_id
end
