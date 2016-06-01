class SimpleDependent < ActiveRecord::Base
  belongs_to :simple_main

  counter_culture :simple_main
end
