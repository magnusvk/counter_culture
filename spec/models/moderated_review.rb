class ModeratedReview < ActiveRecord::Base
  belongs_to :user

  after_update :auto_approve

  counter_culture :user, :column_name => -> (review) { review.positive_and_approved? ? 'approved_positive_reviews_count' : nil }
  def positive_and_approved?
    up? && approved?
  end

  private

  def auto_approve
    unless approved?
      self.approved = true
      save
    end
  end
end
