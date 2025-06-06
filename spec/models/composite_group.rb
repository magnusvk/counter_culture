class CompositeGroup < ActiveRecord::Base
  has_many :composite_group_users,
    primary_key: [:id, :secondary_id],
    foreign_key: [:composite_group_id, :secondary_id]

  has_many :composite_users,
    through: :composite_group_users

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end
