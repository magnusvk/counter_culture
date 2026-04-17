class LockingParent < ActiveRecord::Base
  has_many :locking_children
  has_many :locking_grandchildren, through: :locking_children
end
