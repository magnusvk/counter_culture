module WithModule
  class Model2 < ActiveRecord::Base
    self.table_name_prefix = 'with_module_'

    has_many :model1s
  end
end
