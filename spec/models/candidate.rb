class Candidate < ActiveRecord::Base
  has_one :candidate_profile, inverse_of: :candidate
end
