class TwitterReview < Review
  counter_culture :product, column_name: 'twitter_reviews_count'
end
