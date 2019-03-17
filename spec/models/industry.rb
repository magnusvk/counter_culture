class Industry < ActiveRecord::Base
  has_many :companies
  has_many :managers, :through => :companies
end
