class CompositeGroupUser < ActiveRecord::Base
  belongs_to :composite_group,
    primary_key: [:id, :secondary_id],
    foreign_key: [:composite_group_id, :secondary_id]
  belongs_to :composite_user

  counter_culture :composite_group, column_name: 'composite_users_count'
  counter_culture :composite_group, column_name: 'composite_users_pt_count',
    :with_papertrail => PapertrailSupport.supported_here?

  counter_culture :composite_user, column_name: 'composite_groups_count'
end
