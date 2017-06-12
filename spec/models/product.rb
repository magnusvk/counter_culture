class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => proc {|foreign_key_value| Category.pluck(:id) }

  has_paper_trail
end
