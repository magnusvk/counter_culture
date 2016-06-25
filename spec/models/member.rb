class Member < ActiveRecord::Base
  has_many :conversation_members
  has_many :contacts, through: :conversation_members, foreign_key: :member_id
end