require 'spec_helper'

RSpec.describe "CounterCulture self referential counter cache" do
  it "increments counter cache on create" do
    company = Company.create!
    company.children << Company.create!

    company.reload
    expect(company.children_count).to eq(1)
  end

  it "decrements counter cache on destroy" do
    company = Company.create!
    company.children << Company.create!

    company.reload
    expect(company.children_count).to eq(1)

    company.children.first.destroy

    company.reload
    expect(company.children_count).to eq(0)
  end

  it "decrements counter cache on destroy_all" do
    company = Company.create!
    5.times { company.children << Company.create! }

    company.reload
    expect(company.children_count).to eq(5)

    company.children.destroy_all

    company.reload
    expect(company.children_count).to eq(0)
  end

  it "fixes counter cache" do
    company = Company.create!
    company.children << Company.create!

    company.children_count = -1
    company.save!

    fixed = Company.counter_culture_fix_counts
    expect(fixed.length).to eq(1)
    expect(company.reload.children_count).to eq(1)
  end

  it "fixes counter cache for polymorphic self reference" do
    comment = Comment.create!
    comment.comments << Comment.create!

    comment.comments_count = -1
    comment.save!

    fixed = Comment.counter_culture_fix_counts
    expect(fixed.length).to eq(1)
    expect(comment.reload.comments_count).to eq(1)
  end
end
