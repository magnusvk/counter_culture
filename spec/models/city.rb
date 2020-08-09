class City < ActiveRecord::Base
  belongs_to :prefecture
  scope :big, -> { where('population > ?', 100000) }
  scope :small, -> { where('population < ?', 10000) }
  scope :medium, -> { where('population > ? AND population < ?', 10000, 100000) }
  scope :small_and_big_cities, -> { where('population > ? OR population < ?', 100000, 10000) }

  counter_culture(
    :prefecture,
    column_names: { 
      City.big => :big_cities_count,
      City.small => :small_cities_count,
      City.medium => :medium_cities_count,
      City.small_and_big_cities => :small_and_big_cities_count
    }
  )
end
