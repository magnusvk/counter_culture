class ConversationMember < ActiveRecord::Base
  belongs_to :conversation
  belongs_to :member

  counter_culture :conversation,
    column_name: proc {|conv_member| conv_member.member.user_type == 'G' ? 'guest_count' : nil },
    column_names: {
      ["members.user_type = ?", 'G'] => 'guest_count'
    }

  counter_culture :conversation,
                  column_name: proc { |conv_member| conv_member.member.user_type == 'V' ? 'vip_count' : nil },
                  column_names: {
                    ["members.user_type = ?", 'V'] => "vip_count"
                  }

  counter_culture :conversation,
                  column_name: proc { |conv_member| conv_member.approved? ? 'approved_count' : nil },
                  column_names: {
                    ["conversation_members.approved = ?", true] => "approved_count"
                  }
end
