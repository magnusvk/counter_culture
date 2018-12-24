class Company < ActiveRecord::Base
  belongs_to :industry
  has_many :managers, :foreign_key => :manages_company_id


  belongs_to :parent, :class_name => 'Company', :foreign_key => 'parent_id', inverse_of: :children
  has_many :children, :class_name => 'Company', :foreign_key => 'parent_id', inverse_of: :parent

  counter_culture :parent, :column_name => :children_count

end
