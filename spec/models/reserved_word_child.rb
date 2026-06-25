class ReservedWordChild < ActiveRecord::Base
  belongs_to :reserved_word_parent

  # `order` is a SQL reserved word, so the counter cache column requires
  # identifier quoting when fix_counts writes to it.
  counter_culture :reserved_word_parent, column_name: :order
end
