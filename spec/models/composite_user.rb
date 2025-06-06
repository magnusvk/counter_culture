class CompositeUser < ActiveRecord::Base
  has_many :composite_group_users, dependent: :destroy
  has_many :composite_groups,
    through: :composite_group_users
end
