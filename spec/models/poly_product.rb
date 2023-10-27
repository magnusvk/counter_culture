class PolyProduct < ActiveRecord::Base
  self.primary_key = :pp_pk_id
  has_many :poly_images, as: :imageable
  has_many :poly_images_from_uids, as: :imageable_from_uid,
      class_name: 'PolyImage',
      foreign_key: :imageable_uid,
      primary_key: :uid

  before_create :set_uid

  def set_uid
    self.uid = SecureRandom.uuid
  end
end
