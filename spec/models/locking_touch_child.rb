class LockingTouchChild < ActiveRecord::Base
  self.table_name = "locking_children"

  belongs_to :locking_parent, :touch => true
  has_many :locking_grandchildren, :foreign_key => :locking_child_id

  counter_culture :locking_parent, :column_name => :children_count
end
