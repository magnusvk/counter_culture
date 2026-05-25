require 'spec_helper'

RSpec.describe "CounterCulture fix_counts at scale" do
  MANY = CI_TEST_RUN ? 1000 : 20
  A_FEW = CI_TEST_RUN ? 50:  10
  A_BATCH = CI_TEST_RUN ? 100: 10

  it "should log if verbose option is true" do
    logger = ActiveRecord::Base.logger
    io = StringIO.new
    io_logger = Logger.new(io)
    ActiveRecord::Base.logger = io_logger

    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    2.times do
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleDependent.counter_culture_fix_counts :batch_size => 1, verbose: true

    expect(io.string).to include(
      "Performing reconciling of SimpleDependent#simple_main.")
    expect(io.string).to include(
      "Processing batch #1.")
    expect(io.string).to include(
      "Finished batch #1.")
    expect(io.string).to include(
      "Processing batch #2.")
    expect(io.string).to include(
      "Finished batch #2.")
    expect(io.string).to include(
      "Finished reconciling of SimpleDependent#simple_main.")
    ActiveRecord::Base.logger = logger
  end

  it "should support batch processing" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    expect_any_instance_of(CounterCulture::Reconciler::Reconciliation).to receive(:update_count_for_batch).exactly(MANY/A_BATCH).times

    MANY.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH
  end

  it "should correctly fix the counter caches with thousands of records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    MANY.times do |i|
      main = SimpleMain.create
      3.times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(3) }

    SimpleMain.order(db_random).limit(A_FEW).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(3) }
  end

  it "should correctly fix the counter caches for thousands of records when counter is conditional" do
    # first, clean up
    ConditionalDependent.delete_all
    ConditionalMain.delete_all

    MANY.times do |i|
      main = ConditionalMain.create
      3.times { main.conditional_dependents.create(:condition => main.id % 2 == 0) }
    end

    ConditionalMain.find_each { |main| expect(main.conditional_dependents_count).to eq(main.id % 2 == 0 ? 3 : 0) }

    ConditionalMain.order(db_random).limit(A_FEW).update_all :conditional_dependents_count => 1
    ConditionalDependent.counter_culture_fix_counts :batch_size => A_BATCH

    ConditionalMain.find_each { |main| expect(main.conditional_dependents_count).to eq(main.id % 2 == 0 ? 3 : 0) }
  end

  it "should correctly fix the counter caches when no dependent record exists for some of main records" do
    # first, clean up
    SimpleDependent.delete_all
    SimpleMain.delete_all

    MANY.times do |i|
      main = SimpleMain.create
      (main.id % 4).times { main.simple_dependents.create }
    end

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(main.id % 4) }

    SimpleMain.order(db_random).limit(A_FEW).update_all simple_dependents_count: 1
    SimpleDependent.counter_culture_fix_counts :batch_size => A_BATCH

    SimpleMain.find_each { |main| expect(main.simple_dependents_count).to eq(main.id % 4) }
  end
end
