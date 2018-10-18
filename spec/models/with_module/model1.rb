module WithModule
  class Model1 < ActiveRecord::Base
    belongs_to :model2
    counter_culture :model2
  end
end
