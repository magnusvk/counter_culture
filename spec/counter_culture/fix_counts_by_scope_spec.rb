require 'spec_helper'

RSpec.describe "CounterCulture fix counts by scope" do
  let(:prefecture) { Prefecture.new name: 'Tokyo' }

  before do
    prefecture.save!
    City.create!(name: 'Sibuya', prefecture: prefecture, population: 221800)
    City.create!(name: 'Oku Tama', prefecture: prefecture, population: 6045)

    prefecture.reload
  end

  it "raises an error when column_names is invalid" do
    expect {
      City.counter_culture :prefecture, column_name: :foo,
        column_names: :foo
    }.to raise_error(
      ArgumentError,
      ":column_names must be a Hash of conditions and column names, or a Proc that when called returns such a Hash",
    )
  end

  context "when column_names value is a Symbol" do
    before do
      prefecture.update_columns(big_cities_count: 0, small_cities_count: 0)
    end

    it "updates the column" do
      expect(prefecture.reload.big_cities_count).to be(0)
      City.counter_culture_fix_counts(only: :prefecture,
                                      column_name: :big_cities_count)
      expect(prefecture.reload.big_cities_count).to be(1)
    end
  end

  context "when column_names is a Hash" do
    it "can fix counts by scope" do
      expect(prefecture.big_cities_count).to eq(1)

      prefecture.big_cities_count = 999
      prefecture.save!

      City.counter_culture_fix_counts
      expect(prefecture.reload.big_cities_count).to eq(1)
    end
  end

  context "when column_names is a Proc" do
    context "when column_names uses context" do
      let(:column_names) do
        proc { |context|
          @called = context
          { City.big => :big_cities_count }
        }
      end

      it "injects options inside block" do
        @called = false
        City.counter_culture :prefecture, column_name: :big_cities_count, column_names: column_names

        City.counter_culture_fix_counts(context: true)

        expect(@called).to eq(true)
      end
    end

    context "when the return value is not a hash" do
      it "does not call the proc right away" do
        called = false
        City.counter_culture :prefecture, column_name: :big_cities_count,
             column_names: -> { called = true; :foo }
        expect(called).to eq(false)
      end

      it "raises an error when called later" do
        City.counter_culture :prefecture, column_name: :big_cities_count,
             column_names: -> { :foo }
        expect { City.counter_culture_fix_counts }.to raise_error(
          ":column_names must be a Hash of conditions and column names"
        )
      end
    end

    it "can fix counts by scope" do
      expect(prefecture.small_cities_count).to eq(1)

      prefecture.small_cities_count = 999
      prefecture.save!

      City.counter_culture_fix_counts

      expect(prefecture.reload.small_cities_count).to eq(1)
    end
  end
end
