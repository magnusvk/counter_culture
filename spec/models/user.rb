class User < ActiveRecord::Base
  belongs_to :employer

  belongs_to :manages_company, :class_name => "Company"
  counter_culture :manages_company, :column_name => "managers_count"

  belongs_to :has_string_id
  counter_culture :has_string_id

  belongs_to :has_non_pk_id
  counter_culture :has_non_pk_id

  has_many :reviews
  accepts_nested_attributes_for :reviews, :allow_destroy => true

  if PapertrailSupport.supported_here?
    has_paper_trail
  end

  default_scope do
    if _default_scope_enabled
      query = joins("LEFT OUTER JOIN companies ON users.company_id = companies.id")
      Rails.version < "5.0.0" ? query.uniq : query.distinct
    else
      all
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
