class Subcateg < ActiveRecord::Base
  SUBCAT_1 = 0
  SUBCAT_2 = 1

  self.primary_key = :subcat_id

  if PapertrailSupport.supported_here?
    has_paper_trail
  end

  has_many :posts
  belongs_to :categ, :foreign_key => :fk_cat_id

  def subcat_id
    # required for Rails 3.2 compatibility
    read_attribute(:subcat_id)
  end
end
