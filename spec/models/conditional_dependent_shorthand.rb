class ConditionalDependentShorthand < ActiveRecord::Base
  belongs_to :conditional_main
  scope :condition, -> { where(condition: true) } 

  counter_culture :conditional_main, if: :condition?, column_names: -> { {
    ConditionalDependentShorthand.condition => :conditional_dependent_shorthands_count,
  } }
end
