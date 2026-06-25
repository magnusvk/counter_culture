class ReservedWordParent < ActiveRecord::Base
  has_many :reserved_word_children
end
