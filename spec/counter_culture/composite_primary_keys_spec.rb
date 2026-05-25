require 'spec_helper'

RSpec.describe "CounterCulture with composite primary keys" do
  before do
    unless CounterCulture.supports_composite_keys?
      skip("composite primary keys not supported in this version of Rails")
    end
  end

  it "should increment / decrement the counter" do
    group = CompositeGroup.create!(secondary_id: 123)

    expect(group.composite_users.count).to eq(0)
    expect(group.composite_users_count).to eq(0)
    group.composite_users << CompositeUser.create!

    expect(group.composite_users.count).to eq(1)
    expect(group.composite_users_count).to eq(1)
    group.composite_users.first.destroy

    group.reload
    expect(group.composite_users_count).to eq(0)
  end

  it "should fix the counter caches" do
    group = CompositeGroup.create!(secondary_id: 123)
    user1 = CompositeUser.create!
    user2 = CompositeUser.create!

    group.composite_users << user1
    group.composite_users << user2

    expect(group.composite_users_count).to eq(2)

    # mess up the count
    group.update_column(:composite_users_count, -1)
    user1.update_column(:composite_groups_count, -1)

    CompositeGroupUser.counter_culture_fix_counts

    group.reload
    user1.reload
    expect(group.composite_users_count).to eq(2)
    expect(user1.composite_groups_count).to eq(1)
  end
end
