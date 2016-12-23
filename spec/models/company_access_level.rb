class CompanyAccessLevel < ActiveRecord::Base
  belongs_to :company
  belongs_to :recruiter
end
