class Game < ActiveRecord::Base
  has_many :players
  
  def modify_player_scores
    players.each do |p|
      p.update(score: p.raw_score * 2)
    end
  end
end
