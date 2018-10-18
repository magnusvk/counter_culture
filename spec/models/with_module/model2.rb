module WithModule
  class Model2 < ActiveRecord::Base
    self.table_name_prefix = 'with_module_'

    has_many :model1s, class_name: 'WithModule::Model1',
      foreign_key: :with_module_model2_id
  end
end
