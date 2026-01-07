# STI model where the base class and association target share the same table
# This tests the Rails 8.1+ UPDATE...FROM alias issue with PostgreSQL
module StiContract
  class Base < ActiveRecord::Base
    self.table_name = 'sti_contracts'

    belongs_to :agreement, class_name: 'StiContract::Agreement',
                           foreign_key: 'agreement_id',
                           inverse_of: :contracts,
                           optional: true

    counter_culture :agreement, column_name: :contracts_count
  end
end

