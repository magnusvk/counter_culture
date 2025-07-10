class Product < ActiveRecord::Base
  belongs_to :category

  counter_culture :category, :foreign_key_values => lambda { |foreign_key_value|
    if foreign_key_value.present?
      Category.pluck(:id)
    else
      nil
    end
  }

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end
