class TwitterReview < Review
  counter_culture :product, column_name: 'twitter_reviews_count'

  counter_culture [:user, :manages_company]
  counter_culture [:admin_user, :manages_company], :column_name => 'admin_reviews_count'

end
