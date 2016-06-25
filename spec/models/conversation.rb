class Conversation < ActiveRecord::Base
  has_many   :conversation_members
  has_many   :members, through: :conversation_members
  has_many   :guest_users, -> { where(user_type: 'G') }, through: :conversation_members, source: :member #, class_name: 'Member' #, conditions: ["users.user_type = ?", 'G']
end