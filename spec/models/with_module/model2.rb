module WithModule
  class Model2 < ActiveRecord::Base
    has_many :model1s
  end
end
