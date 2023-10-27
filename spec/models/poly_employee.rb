class PolyEmployee < ActiveRecord::Base
  has_many :poly_images, as: :imageable
  has_many :poly_images_from_uids, as: :imageable_from_uid,
      class_name: 'PolyImage',
      foreign_key: :imageable_uid,
      foreign_type: :imageable_type,
      primary_key: :uid

  before_create :set_uid

  def set_uid
    self.uid = SecureRandom.uuid
  end
end
