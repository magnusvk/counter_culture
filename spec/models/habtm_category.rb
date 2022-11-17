class HabtmCategory < ActiveRecord::Base
  has_many :habtm_categories_products
  has_many :habtm_products, through: :habtm_categories_products, class_name: 'HabtmProduct'
end