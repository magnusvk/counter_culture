class PolyImage < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true
  belongs_to :imageable_from_uid, polymorphic: true, foreign_key: :imageable_uid, foreign_type: :imageable_type, primary_key: :uid
  counter_culture :imageable
  counter_culture :imageable_from_uid, column_name: 'poly_images_from_uids_count'
  counter_culture :imageable, column_name: 'poly_images_count_dup'
  counter_culture :imageable, column_name: ->(i){i.special? ? 'special_poly_images_count' : nil },
    column_names: {
        ["poly_images.url LIKE ?", '%special%'] => 'special_poly_images_count',
    }

  def special?
    url && url.include?('special')
  end
end
