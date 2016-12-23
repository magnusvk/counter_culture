class Recruiter < ActiveRecord::Base
  has_one :company_access_level

  counter_culture [:company_access_level, :company]
end
