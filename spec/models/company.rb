class Company < ActiveRecord::Base
  belongs_to :industry
  has_many :managers, :foreign_key => :manages_company_id


  belongs_to :parent, :class_name => 'Company', :foreign_key => 'parent_id'
  has_many :children, :class_name => 'Company', :foreign_key => 'parent_id'

  counter_culture :parent, :column_name => :children_count

  default_scope do
    if _default_scope_enabled
      query = joins(:industry)
      if Rails.version < "5.0.0"
        query = query.uniq
      else
        query = query.distinct
      end
    else
      if Rails.version < "4.0.0"
        scoped
      else
        all
      end
    end
  end

  class << self
    attr_accessor :_default_scope_enabled

    def with_default_scope
      @_default_scope_enabled = true
      yield
      @_default_scope_enabled = false
    end
  end
end
