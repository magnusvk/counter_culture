require 'discard'

class SoftDeleteDiscard < ActiveRecord::Base
  include Discard::Model if defined?(Discard::Model)

  belongs_to :company
  counter_culture :company
  counter_culture :company, column_name: 'soft_delete_discard_values_sum', delta_column: 'value'
  counter_culture :company, column_name: 'soft_delete_discard_include_soft_deleted_count', include_soft_deleted: true
  counter_culture :company,
    column_name: ->(r) { r.discarded_at.present? ? 'soft_delete_discard_deleted_count' : nil },
    column_names: {
      ["soft_delete_discards.discarded_at IS NOT NULL"] => 'soft_delete_discard_deleted_count'
    },
    include_soft_deleted: true
end
