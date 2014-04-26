class Player < ActiveRecord::Base
  belongs_to :game
  counter_culture :game, :column_name => 'total_score', :delta_column => 'score'
    
  after_create do
    game.modify_player_scores
  end
end
