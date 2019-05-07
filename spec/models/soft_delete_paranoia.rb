require 'paranoia'

class SoftDeleteParanoia < ActiveRecord::Base
  acts_as_paranoid if respond_to?(:acts_as_paranoid)

  belongs_to :company
  counter_culture :company
  counter_culture :company, column_name: 'soft_delete_paranoia_values_sum', delta_column: 'value'
end
