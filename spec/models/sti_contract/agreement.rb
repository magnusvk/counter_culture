# STI model that acts as the parent in the counter_culture relationship
# Both Agreement and Base share the same table (sti_contracts)
module StiContract
  class Agreement < ActiveRecord::Base
    self.table_name = 'sti_contracts'

    has_many :contracts, class_name: 'StiContract::Base',
                         foreign_key: 'agreement_id',
                         inverse_of: :agreement
  end
end

