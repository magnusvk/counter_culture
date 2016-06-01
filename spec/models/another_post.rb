class AnotherPost < ActiveRecord::Base
  has_many :comments, class_name: 'AnotherPostComment', foreign_key: 'another_post_id', primary_key: 'another_id'

  before_save :assign_another_id, :if => :new_record?

  private
  def assign_another_id
    loop do
      self.another_id = Random.rand(65535)
      break unless self.class.where(another_id: another_id).exists?
    end
  end
end
