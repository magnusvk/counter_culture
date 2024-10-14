class ConditionalMain < ActiveRecord::Base
  has_many :conditional_dependents
  has_many :conditional_dependent_shorthands
end
