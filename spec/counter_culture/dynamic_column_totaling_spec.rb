require 'spec_helper'

RSpec.describe "CounterCulture dynamic column names with totaling instead of counting" do
  it "should correctly sum up the values" do
    person = Person.create!

    earning_transaction = Transaction.create(monetary_value: 10, person: person)

    person.reload
    expect(person.money_earned_total).to eq(10)

    spending_transaction = Transaction.create(monetary_value: -20, person: person)
    person.reload
    expect(person.money_spent_total).to eq(-20)
  end

  it "should show the correct changes when changes are present" do
    person = Person.create(id:100)

    earning_transaction = Transaction.create(monetary_value: 10, person: person)
    spending_transaction = Transaction.create(monetary_value: -20, person: person)

    # Overwrite the values for the person so they are incorrect
    person.reload
    person.money_earned_total = 0
    person.money_spent_total = 0
    person.save

    fixed = Transaction.counter_culture_fix_counts
    expect(fixed.length).to eq(2)
    expect(fixed).to eq([
      {:entity=>"Person", :id=>person.id, :what=>"money_earned_total", :wrong=>0, :right=>10},
      {:entity=>"Person", :id=>person.id, :what=>"money_spent_total", :wrong=>0, :right=>-20}
    ])
  end
end
