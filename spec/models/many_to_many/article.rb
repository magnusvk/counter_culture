class Article < ActiveRecord::Base
  has_many :readers_articles, dependent: :destroy
  has_many :authors_articles, dependent: :destroy

  has_many :readers, through: :readers_articles, dependent: :destroy
  has_many :authors, through: :authors_articles, dependent: :destroy
end
