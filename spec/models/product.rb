class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => Proc.new {|foreign_key_value| Category.pluck(:id) }
end
