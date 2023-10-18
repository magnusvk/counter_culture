class AuthorsArticle < ActiveRecord::Base
  belongs_to :author
  belongs_to :article
  
  counter_culture :author, column_name: :articles_count
end
