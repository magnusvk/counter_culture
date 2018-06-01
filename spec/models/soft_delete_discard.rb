class SoftDeleteDiscard < ActiveRecord::Base
  include Discard::Model if defined?(Discard::Model)

  belongs_to :company
  counter_culture :company
end
