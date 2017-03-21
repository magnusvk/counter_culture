class PolyEmployee < ActiveRecord::Base
  has_many :poly_images, as: :imageable
end
