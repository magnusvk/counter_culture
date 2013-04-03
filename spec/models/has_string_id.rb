class HasStringId < ActiveRecord::Base
  set_primary_key :id
  has_many :users
end
