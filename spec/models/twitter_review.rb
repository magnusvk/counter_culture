class TwitterReview < Review
  counter_culture :product, column_name: 'twitter_reviews_count'
  counter_culture :user, column_name: 'review_value_sum', delta_magnitude: Proc.new {|model| model.weight}

  counter_culture [:manages_company]

  def weight
    if review_type == 'using'
      2
    else
      1
    end
  end
end
