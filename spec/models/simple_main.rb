class SimpleMain < ActiveRecord::Base
  has_many :simple_dependents

  if Rails.version >= "5.0.0"
    has_paper_trail
  end
end
