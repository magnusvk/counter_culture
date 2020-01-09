class City < ActiveRecord::Base
  belongs_to :prefecture

  counter_culture(
    :prefecture,
    column_name:  ->(model) { model.big? ? :big_cities_count : nil },
    column_names: { big: :big_cities_count }
  )

  scope :big, -> { where('population > ?', 100000) }

  def big?
    population > 100000
  end
end
