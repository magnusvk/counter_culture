module WithModule
  class Model1 < ActiveRecord::Base
    self.table_name_prefix = 'with_module_'

    belongs_to :model2
    counter_culture :model2
  end
end
