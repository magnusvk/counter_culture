class GroupItem < ActiveRecord::Base
  counter_culture %i[sub_group group]
  belongs_to :sub_group, foreign_key: 'sub_group_uuid'
end
