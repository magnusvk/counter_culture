class SimpleDependent < ActiveRecord::Base
  belongs_to :simple_main

  counter_culture :simple_main, with_papertrail: Rails.version >= '5.0.0'
end
