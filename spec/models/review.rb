class Review < ActiveRecord::Base
  belongs_to :user
  belongs_to :product

  counter_culture :product, :touch => true, :with_papertrail => Rails.version >= "5.0.0"
  counter_culture :product, :column_name => 'rexiews_count', touch: :rexiews_updated_at
  counter_culture :user
  counter_culture :user, :column_name => proc { |model| model.review_type && model.review_type != 'null' ? "#{model.review_type}_count" : nil }, :column_names => {"reviews.review_type = 'using'" => 'using_count', "reviews.review_type = 'tried'" => 'tried_count', "reviews.review_type = 'null'" => nil}
  counter_culture :user, :column_name => 'review_approvals_count', :delta_column => 'approvals'
  counter_culture :user, :column_name => 'review_value_sum', :delta_column => 'value'
  counter_culture :user, :column_name => 'dynamic_delta_count', delta_magnitude: proc {|model| model.weight }
  counter_culture :user, :column_name => 'custom_delta_count', delta_magnitude: 3
  counter_culture [:user, :manages_company]
  counter_culture [:user, :manages_company], :column_name => 'review_approvals_count', :delta_column => 'approvals'
  counter_culture [:user, :manages_company, :industry]
  counter_culture [:user, :manages_company, :industry], :column_name => 'rexiews_count'
  counter_culture [:user, :manages_company, :industry], :column_name => proc { |model| model.review_type ? "#{model.review_type}_count" : nil }
  counter_culture [:user, :manages_company, :industry], :column_name => 'review_approvals_count', :delta_column => 'approvals'

  after_create :update_some_text
  after_create :update_read_only_text

  def update_some_text
    return unless Gem::Version.new(Rails.version) >= Gem::Version.new('5.1.5')
    update_attribute(:some_text, rand(36**12).to_s(36))
  end

  def update_read_only_text
    self[:read_only_text] = SecureRandom.uuid
  end

  def weight
    if heavy?
      2
    else
      1
    end
  end

  private

  def read_only_text=(*)
    raise 'This is a read_only field'
  end
end
