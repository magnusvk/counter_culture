class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => proc {|foreign_key_value| Category.pluck(:id) }

  if Rails.version >= "5.0.0"
    has_paper_trail
  end
end
