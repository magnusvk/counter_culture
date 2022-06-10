class City < ActiveRecord::Base
  belongs_to :prefecture
  scope :big, -> { where('population > ?', 100000) }
  scope :small, -> { where('population <= ?', 100000) }

  counter_culture(
    :prefecture,
    column_name:  ->(model) { model.big? ? :big_cities_count : nil },
    column_names: { City.big => :big_cities_count }
  )

  counter_culture(
    :prefecture,
    column_name:  ->(model) { model.small? ? :small_cities_count : nil },
    column_names: -> { { City.small => :small_cities_count } }
  )

  def big?
    population > 100000
  end

  def small?
    !big?
  end
end
