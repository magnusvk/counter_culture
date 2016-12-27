class PolyImage < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true
  counter_culture :imageable, polymorphic_associated_models: ['PolyEmployee', 'PolyProduct']
end
