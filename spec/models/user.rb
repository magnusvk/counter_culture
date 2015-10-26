class User < ActiveRecord::Base
  belongs_to :employer

  belongs_to :manages_company, :class_name => "Company"
  counter_culture :manages_company, :column_name => "managers_count"
  belongs_to :has_string_id
  counter_culture :has_string_id

  has_many :reviews
  accepts_nested_attributes_for :reviews, :allow_destroy => true

  def self.with_default_scope!
    default_scope { joins("LEFT OUTER JOIN companies").uniq }
  end

  def self.without_default_scope!
    default_scope { all }
  end
end
