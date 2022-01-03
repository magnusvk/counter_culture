class SubGroup < ActiveRecord::Base
  has_many :group_items, foreign_key: 'sub_group_uuid'
  belongs_to :group

  before_create do
    self.uuid = SecureRandom.uuid
  end
end
