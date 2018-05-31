class SoftDeleteDiscard < ActiveRecord::Base
  include Discard::Model

  belongs_to :company
  counter_culture :company
end
