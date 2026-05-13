require 'spec_helper'

RSpec.describe "CounterCulture when relation is an array but has different primary keys along the chain" do
  it "should update correctly" do
    group = Group.create
    sub_group = SubGroup.create(group: group)

    expect(group.group_items_count).to eq(0)
    group_item = GroupItem.create(sub_group: sub_group)

    expect(group.reload.group_items_count).to eq(1)
  end

  it "should fix counts correctly" do
    group = Group.create
    sub_group = SubGroup.create(group: group)
    group_item = GroupItem.create(sub_group: sub_group)

    expect(group.reload.group_items_count).to eq(1)

    group.update!(group_items_count: -1)

    GroupItem.counter_culture_fix_counts

    expect(group.reload.group_items_count).to eq(1)
  end
end
