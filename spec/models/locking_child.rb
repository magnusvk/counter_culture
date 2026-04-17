class LockingChild < ActiveRecord::Base
  belongs_to :locking_parent
  has_many :locking_grandchildren

  counter_culture :locking_parent, :column_name => :children_count
end
