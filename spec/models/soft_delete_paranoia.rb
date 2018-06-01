class SoftDeleteParanoia < ActiveRecord::Base
  acts_as_paranoid if respond_to?(:acts_as_paranoid)

  belongs_to :company
  counter_culture :company
end
