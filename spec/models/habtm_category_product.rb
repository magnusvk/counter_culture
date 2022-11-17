class HabtmCategoriesProduct < ActiveRecord::Base
  belongs_to :habtm_product
  belongs_to :habtm_category

  counter_culture :habtm_category,
                  column_name: ->(model) { model.habtm_product.visible? ? 'products_count' : nil },
                  column_names: {
                    HabtmProduct.visible => 'products_count'
                  },
                  touch: true
end