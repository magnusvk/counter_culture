class SoftDeleteParanoia < ActiveRecord::Base
  acts_as_paranoid

  belongs_to :company
  counter_culture :company
end
