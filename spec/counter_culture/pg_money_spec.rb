require 'spec_helper'

RSpec.describe "CounterCulture with PostgreSQL money type" do
  before do
    skip("money type only supported in PostgreSQL") unless ENV['DB'] == 'postgresql'
  end

  it "should work with pg money type" do
    po = PurchaseOrder.create

    expect(po.total_amount).to eq(0.0)

    item = po.purchase_order_items.build(amount: 100.00)
    item.save

    po.reload
    expect(po.total_amount).to eq(100.0)

    item = po.purchase_order_items.build(amount: 100.00)
    item.save

    po.reload
    expect(po.total_amount).to eq(200.0)

    item.destroy

    po.reload
    expect(po.total_amount).to eq(100.0)

    po.purchase_order_items.destroy_all
    po.reload
    expect(po.total_amount).to eq(0.0)
  end

  it "works with pg money type under aggregate_counter_updates" do
    item = nil
    po = PurchaseOrder.create

    expect(po.total_amount).to eq(0.0)

    CounterCulture.aggregate_counter_updates do
      item = po.purchase_order_items.build(amount: 100.00)
      item.save
    end

    po.reload
    expect(po.total_amount).to eq(100.0)

    CounterCulture.aggregate_counter_updates do
      item = po.purchase_order_items.build(amount: 100.00)
      item.save
    end

    po.reload
    expect(po.total_amount).to eq(200.0)

    CounterCulture.aggregate_counter_updates do
      item.destroy
    end

    po.reload
    expect(po.total_amount).to eq(100.0)

    CounterCulture.aggregate_counter_updates do
      po.purchase_order_items.destroy_all
    end

    po.reload
    expect(po.total_amount).to eq(0.0)
  end
end
