require 'spec_helper'

RSpec.describe "CounterCulture with optimistic locking" do
  describe "should not increment lock_version on counter update" do
    it "on create" do
      parent = LockingParent.create!
      LockingChild.create!(:locking_parent => parent)
      parent.reload

      expect(parent.children_count).to eq(1)
      expect(parent.lock_version).to eq(0)
    end

    it "on destroy" do
      parent = LockingParent.create!
      child = LockingChild.create!(:locking_parent => parent)
      child.destroy!
      parent.reload

      expect(parent.children_count).to eq(0)
      expect(parent.lock_version).to eq(0)
    end

    it "with multiple children" do
      parent = LockingParent.create!
      5.times { LockingChild.create!(:locking_parent => parent) }
      parent.reload

      expect(parent.children_count).to eq(5)
      expect(parent.lock_version).to eq(0)
    end

    it "on update that changes parent" do
      parent1 = LockingParent.create!
      parent2 = LockingParent.create!
      child = LockingChild.create!(:locking_parent => parent1)

      child.update!(:locking_parent => parent2)
      parent1.reload
      parent2.reload

      expect(parent1.children_count).to eq(0)
      expect(parent1.lock_version).to eq(0)
      expect(parent2.children_count).to eq(1)
      expect(parent2.lock_version).to eq(0)
    end

    it "with multi-level counter" do
      parent = LockingParent.create!
      child = LockingChild.create!(:locking_parent => parent)
      LockingGrandchild.create!(:locking_child => child)
      parent.reload

      expect(parent.grandchildren_count).to eq(1)
      expect(parent.lock_version).to eq(0)
    end

    it "with aggregate counter updates" do
      parent = LockingParent.create!

      CounterCulture.aggregate_counter_updates do
        3.times { LockingChild.create!(:locking_parent => parent) }
      end

      parent.reload
      expect(parent.children_count).to eq(3)
      expect(parent.lock_version).to eq(0)
    end

    it "with multi-level aggregate counter updates" do
      parent = LockingParent.create!
      child = LockingChild.create!(:locking_parent => parent)

      CounterCulture.aggregate_counter_updates do
        3.times { LockingGrandchild.create!(:locking_child => child) }
      end

      parent.reload
      expect(parent.grandchildren_count).to eq(3)
      expect(parent.lock_version).to eq(0)
    end
  end

  describe "should not raise StaleObjectError with touch: true on belongs_to" do
    it "on create" do
      parent = LockingParent.create!
      expect { LockingTouchChild.create!(:locking_parent => parent) }.not_to raise_error
      expect(parent.reload.children_count).to eq(1)
    end

    it "on destroy" do
      parent = LockingParent.create!
      child = LockingTouchChild.create!(:locking_parent => parent)
      expect { child.destroy! }.not_to raise_error
      expect(parent.reload.children_count).to eq(0)
    end

    it "with multiple children" do
      parent = LockingParent.create!
      expect {
        5.times { LockingTouchChild.create!(:locking_parent => parent) }
      }.not_to raise_error
      expect(parent.reload.children_count).to eq(5)
    end

    it "allows touch on parent after counter update" do
      parent = LockingParent.create!
      LockingTouchChild.create!(:locking_parent => parent)
      expect { parent.touch }.not_to raise_error
    end

    it "allows save on parent after counter update" do
      parent = LockingParent.create!(:name => "original")
      LockingTouchChild.create!(:locking_parent => parent)

      parent.name = "updated"
      expect { parent.save! }.not_to raise_error
      expect(parent.reload.name).to eq("updated")
    end

    it "allows multiple touches after multiple counter updates" do
      parent = LockingParent.create!
      3.times { LockingTouchChild.create!(:locking_parent => parent) }

      expect { parent.touch }.not_to raise_error
      expect { parent.touch }.not_to raise_error
    end

    it "allows touch after create and destroy cycle" do
      parent = LockingParent.create!
      child = LockingTouchChild.create!(:locking_parent => parent)
      child.destroy!

      expect { parent.touch }.not_to raise_error
      expect(parent.reload.children_count).to eq(0)
    end

    it "with aggregate counter updates" do
      parent = LockingParent.create!

      CounterCulture.aggregate_counter_updates do
        3.times { LockingTouchChild.create!(:locking_parent => parent) }
      end

      expect { parent.touch }.not_to raise_error
      expect(parent.reload.children_count).to eq(3)
    end
  end

  describe "should preserve normal optimistic locking behavior" do
    it "increments lock_version on regular save" do
      parent = LockingParent.create!
      parent.update!(:name => "updated")
      expect(parent.lock_version).to eq(1)
    end

    it "increments lock_version on touch" do
      parent = LockingParent.create!
      parent.touch
      expect(parent.lock_version).to eq(1)
    end

    it "raises StaleObjectError on concurrent edits" do
      parent = LockingParent.create!
      stale_parent = LockingParent.find(parent.id)

      parent.update!(:name => "first edit")
      expect {
        stale_parent.update!(:name => "second edit")
      }.to raise_error(ActiveRecord::StaleObjectError)
    end

    it "increments lock_version via touch: true from child, not from counter" do
      parent = LockingParent.create!
      LockingTouchChild.create!(:locking_parent => parent)
      parent.reload

      expect(parent.lock_version).to eq(1)
      expect(parent.children_count).to eq(1)
    end
  end
end
