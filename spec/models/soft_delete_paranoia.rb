require 'paranoia'

class SoftDeleteParanoia < ActiveRecord::Base
  acts_as_paranoid if respond_to?(:acts_as_paranoid)

  belongs_to :company
  counter_culture :company
  counter_culture :company, column_name: 'soft_delete_paranoia_values_sum', delta_column: 'value'
  counter_culture :company, column_name: 'soft_delete_paranoia_include_soft_deleted_count', include_soft_deleted: true
  counter_culture :company,
    column_name: ->(r) { r.deleted_at.present? ? 'soft_delete_paranoia_deleted_count' : nil },
    column_names: {
      ["soft_delete_paranoia.deleted_at IS NOT NULL"] => 'soft_delete_paranoia_deleted_count'
    },
    include_soft_deleted: true
end
