class Author < ActiveRecord::Base
  has_many :authors_articles, dependent: :destroy
  has_many :articles, through: :authors_articles, dependent: :destroy
end
