class Conversation < ActiveRecord::Base
  belongs_to :candidate
  counter_culture [:candidate, :candidate_profile]
end
