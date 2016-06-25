class ConditionalDependent < ActiveRecord::Base
  belongs_to :conditional_main

  counter_culture :conditional_main,
    column_name: proc {|m| m.condition? ? 'conditional_dependents_count' : nil },
    column_names: { ['conditional_dependents.condition = ?', true] => 'conditional_dependents_count' }
end
