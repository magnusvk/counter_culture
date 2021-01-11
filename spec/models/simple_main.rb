class SimpleMain < ActiveRecord::Base
  has_many :simple_dependents

  if PapertrailSupport.supported_here?
    has_paper_trail
  end
end
