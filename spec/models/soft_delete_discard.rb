require 'discard'

class SoftDeleteDiscard < ActiveRecord::Base
  include Discard::Model if defined?(Discard::Model)

  belongs_to :company
  counter_culture :company
  counter_culture :company, column_name: 'soft_delete_discard_values_sum', delta_column: 'value'
  counter_culture :company, column_name: 'soft_delete_discard_include_soft_deleted_count', include_soft_deleted: true
end
