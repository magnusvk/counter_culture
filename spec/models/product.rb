class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => proc {|foreign_key_value| Category.pluck(:id) }

end
