class Company < ActiveRecord::Base
  belongs_to :industry
  has_many :managers, :foreign_key => :manages_company_id
end
