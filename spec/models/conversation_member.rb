class ConversationMember < ActiveRecord::Base
  belongs_to :conversation
  belongs_to :member

  counter_culture :conversation,
    column_name: proc {|conv_member| conv_member.member.user_type == 'G' ? 'guest_count' : nil },
    joins: :member,
    column_names: {
      ["members.user_type = ?", 'G'] => 'guest_count'
    }
end