class HabtmProduct < ActiveRecord::Base
  has_many :habtm_categories_products, dependent: :destroy
  has_many :habtm_categories, through: :habtm_categories_products, class_name: 'HabtmCategory'
  
  scope :visible, -> { where(visible: true) } # to be able to mix with conditional counts

end