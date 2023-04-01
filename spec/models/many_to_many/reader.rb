class Reader < ActiveRecord::Base
  has_many :readers_articles, dependent: :destroy
  has_many :articles, through: :readers_articles, dependent: :destroy
end
