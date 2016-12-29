class PolyImage < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true
  counter_culture :imageable, polymorphic_associated_models: ['PolyEmployee', 'PolyProduct']
  counter_culture :imageable, column_name: 'poly_images_count_dup',
    polymorphic_associated_models: ['PolyEmployee', 'PolyProduct']
  counter_culture :imageable, column_name: ->(i){i.special? ? 'special_poly_images_count' : nil },
    polymorphic_associated_models: ['PolyEmployee', 'PolyProduct'],
    column_names: {
        ["poly_images.url LIKE ?", '%special%'] => 'special_poly_images_count',
    }


  def special?
    url && url.include?('special')
  end

end
