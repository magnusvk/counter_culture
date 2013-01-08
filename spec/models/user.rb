class User < ActiveRecord::Base
  belongs_to :employer

  belongs_to :manages_company, :class_name => "Company"
  counter_culture :manages_company, :column_name => "managers_count"
end
