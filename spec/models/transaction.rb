class Transaction < ActiveRecord::Base
  belongs_to :person

  counter_culture [:person],
    :column_name => proc {|model| model.earns_money? ? 'money_earned_total' : 'money_spent_total' },
    :column_names => {
          ["transactions.monetary_value > 0"] => 'money_earned_total',
          ["transactions.monetary_value <= 0"] => 'money_spent_total'
      },
    :delta_column => 'monetary_value'

  def earns_money?
    monetary_value > 0
  end
end
