require 'spec_helper'

RSpec.describe "CounterCulture with papertrail support", versioning: true do
  before do
    skip("Unsupported in this combination of Ruby and Rails") unless PapertrailSupport.supported_here?
  end

  it "creates a papertrail version when changed" do
    user = User.create
    product = Product.create

    expect(product.reviews_count).to eq(0)
    expect(product.versions.count).to eq(1)

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    product.reload

    expect(product.reviews_count).to eq(1)
    expect(product.versions.count).to eq(2)

    attrs_from_versions = yaml_load(product.versions.reorder(:id).last.object)
    # should be the value before the counter change
    expect(attrs_from_versions['reviews_count']).to eq(0)

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    product.reload

    expect(product.reviews_count).to eq(2)
    expect(product.versions.count).to eq(3)

    attrs_from_versions = yaml_load(product.versions.reorder(:id).last.object)
    # should be the value before the counter change
    expect(attrs_from_versions['reviews_count']).to eq(1)
  end

  it "works with after_commit" do
    subcateg = Subcateg.create!

    expect(subcateg.posts_after_commit_count).to eq(0)
    expect(subcateg.posts_dynamic_commit_count).to eq(0)
    expect(subcateg.versions.count).to eq(1)

    User.transaction do
      Post.create!(subcateg: subcateg)

      subcateg.reload

      expect(subcateg.posts_after_commit_count).to eq(0)
      expect(subcateg.posts_dynamic_commit_count).to eq(0)
      expect(subcateg.versions.count).to eq(1)
    end

    subcateg.reload

    expect(subcateg.posts_after_commit_count).to eq(1)
    expect(subcateg.posts_dynamic_commit_count).to eq(1)
    expect(subcateg.versions.count).to eq(3)

    attrs_from_versions = yaml_load(subcateg.versions.reorder(:id).last.object)
    # should be the value before the counter change
    expect(attrs_from_versions['posts_after_commit_count']).to eq(0)
    expect(attrs_from_versions['posts_dynamic_commit_count']).to eq(0)
  end

  it "works with dynamic after_commit" do
    subcateg = Subcateg.create!

    expect(subcateg.posts_after_commit_count).to eq(0)
    expect(subcateg.posts_dynamic_commit_count).to eq(0)
    expect(subcateg.versions.count).to eq(1)

    User.transaction do
      DynamicAfterCommit.update_counter_cache_in_transaction do
        Post.create!(subcateg: subcateg)
      end

      subcateg.reload

      expect(subcateg.posts_after_commit_count).to eq(0)
      expect(subcateg.posts_dynamic_commit_count).to eq(1)
      expect(subcateg.versions.count).to eq(2)
    end

    subcateg.reload

    expect(subcateg.posts_after_commit_count).to eq(1)
    expect(subcateg.posts_dynamic_commit_count).to eq(1)
    expect(subcateg.versions.count).to eq(3)

    attrs_from_versions = yaml_load(subcateg.versions.reorder(:id).last.object)
    # should be the value before the counter change
    expect(attrs_from_versions['posts_after_commit_count']).to eq(0)
    expect(attrs_from_versions['posts_dynamic_commit_count']).to eq(0)
  end

  # Regression tests: with_papertrail routes counter updates through
  # paper_trail.save_with_version instead of an atomic increment, which skips
  # ActiveRecord's automatic timestamping — counter_culture must set the
  # timestamps explicitly on that path.
  context "when with_papertrail saves a new version" do
    let!(:main_obj) { SimpleMain.create(created_at: 1.day.ago, updated_at: 1.day.ago) }

    it "sets updated_at on the parent record" do
      the_time = Time.now.utc
      Timecop.freeze(the_time) do
        main_obj.simple_dependents.create!
        expect(main_obj.reload.updated_at.to_i).to eq(the_time.to_i)
      end
    end

    it "sets created_at on the new version row" do
      the_time = Time.now.utc
      Timecop.freeze(the_time) do
        main_obj.simple_dependents.create!
        expect(main_obj.versions.last.created_at.to_i).to eq(the_time.to_i)
      end
    end
  end

  it "does not create a papertrail version when papertrail flag not set" do
    user = User.create
    product = Product.create

    expect(user.reviews_count).to eq(0)
    expect(user.versions.count).to eq(1)

    user.reviews.create :user_id => user.id, :product_id => product.id, :approvals => 13

    user.reload

    expect(user.reviews_count).to eq(1)
    expect(user.versions.count).to eq(1)
  end

  context "with composite primary keys" do
    before do
      skip("composite primary keys are not supported in this version of Rails") unless CounterCulture.supports_composite_keys?
    end

    it "increments / decrements counter caches correctly" do
      group = CompositeGroup.create!(secondary_id: 123)

      expect(group.composite_users_count).to eq(0)
      expect(group.composite_users.count).to eq(0)
      group.composite_users << CompositeUser.create!

      expect(group.composite_users.count).to eq(1)
      expect(group.composite_users_count).to eq(1)
      group.composite_users.first.destroy

      group.reload
      expect(group.composite_users_count).to eq(0)
    end
  end
end
