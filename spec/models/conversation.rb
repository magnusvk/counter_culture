class Conversation < ActiveRecord::Base
  belongs_to :candidate

  delegate(
    :candidate_profile,
    to: :candidate
  )

  counter_culture [:candidate, :candidate_profile]
end
