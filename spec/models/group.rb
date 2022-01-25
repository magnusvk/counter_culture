class Group < ActiveRecord::Base
  has_many :sub_groups
end
