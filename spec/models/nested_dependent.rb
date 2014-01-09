class NestedDependent < ActiveRecord::Base
  belongs_to :nested_main
  counter_culture :nested_main
end
