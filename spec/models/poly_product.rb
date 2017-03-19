class PolyProduct < ActiveRecord::Base
  self.primary_key = :pp_pk_id
  has_many :poly_images, as: :imageable
end
