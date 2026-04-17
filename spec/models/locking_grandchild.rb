class LockingGrandchild < ActiveRecord::Base
  belongs_to :locking_child

  counter_culture :locking_child, :column_name => :grandchildren_count
  counter_culture [:locking_child, :locking_parent], :column_name => :grandchildren_count
end
