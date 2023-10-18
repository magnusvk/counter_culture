class ReadersArticle < ActiveRecord::Base
  belongs_to :reader
  belongs_to :article
  
  counter_culture [:article, :authors], column_name: :readers_count
end
