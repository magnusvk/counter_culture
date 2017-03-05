class Categ < ActiveRecord::Base
  CAT_1 = 0
  CAT_2 = 1

  self.primary_key = :cat_id

  has_many :subcategs, :foreign_key => :fk_subcat_id

  def cat_id
    # required for Rails 3.2 compatibility
    read_attribute(:cat_id)
  end
end
