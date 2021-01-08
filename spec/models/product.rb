class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => proc {|foreign_key_value| Category.pluck(:id) }

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end
