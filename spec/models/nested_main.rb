class NestedMain < ActiveRecord::Base
  has_many :nested_dependents

  accepts_nested_attributes_for :nested_dependents, allow_destroy: true
end
