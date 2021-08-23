class UserFollower < ActiveRecord::Base
    belongs_to :follower, foreign_key: :follower_id, class_name: 'User', touch: true, inverse_of: :users_followed
    belongs_to :followed, foreign_key: :followed_id, class_name: 'User', touch: true, inverse_of: :user_followers
    counter_culture :followed,
        column_name: proc { |model|
            !model.follower.banned ? :active_followers_count : nil
        },
        extra_join: ' INNER JOIN `users` as user_2 ON user_followers.follower_id = user_2.id ',
        column_names: {
          ['user_2.banned = 0'] => :active_followers_count,
        }
end