require 'spec_helper'

# Regression test for fixing counter caches stored in columns whose names are
# SQL reserved words (e.g. `order`). The reconciler used to build raw SQL update
# strings with unquoted identifiers (`"#{column_name} = #{count}"`), which
# produces invalid SQL for such columns on sqlite, mysql and postgres. It now
# passes a Hash to `update_all` and lets Rails (Arel) qualify and quote the
# identifiers, consistent with the Arel-based updates used in Counter (#425).
RSpec.describe "CounterCulture fix_counts with a reserved-word counter column" do
  it "fixes a counter cache stored in a reserved-word column" do
    parent = ReservedWordParent.create
    ReservedWordChild.create(reserved_word_parent: parent)

    # deliberately corrupt the counter so fix_counts has work to do
    parent.update_column(:order, 5)

    expect {
      ReservedWordChild.counter_culture_fix_counts
    }.to change { parent.reload.read_attribute(:order) }.from(5).to(1)
  end

  it "fixes a reserved-word counter column while also touching timestamps" do
    parent = ReservedWordParent.create
    ReservedWordChild.create(reserved_word_parent: parent)

    parent.update_column(:order, 5)
    parent.reload
    old_updated_at = parent.updated_at

    Timecop.travel(1.second.from_now) do
      ReservedWordChild.counter_culture_fix_counts(touch: true)

      parent.reload
      expect(parent.read_attribute(:order)).to eq(1)
      expect(parent.updated_at).to be > old_updated_at
    end
  end
end
