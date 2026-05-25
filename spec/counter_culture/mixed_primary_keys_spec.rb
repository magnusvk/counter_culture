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

  it "should use relation primary_key correctly" do
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)

    post = Post.new
    post.subcateg = subcateg
    post.save!

    subcateg.reload
    expect(subcateg.posts_count).to eq(1)
  end

  it "should use relation primary key on counter destination table correctly when fixing counts" do
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)
    post = Post.new
    post.subcateg = subcateg
    post.save!

    subcateg.posts_count = -1
    subcateg.save!

    fixed = Post.counter_culture_fix_counts :only => :subcateg

    expect(fixed.length).to eq(1)
    expect(subcateg.reload.posts_count).to eq(1)
  end

  it "should use primary key on counted records table correctly when fixing counts" do
    subcateg = Subcateg.create!
    subcateg.update(subcat_id: Subcateg::SUBCAT_1)
    post = Post.new
    post.subcateg = subcateg
    post.save!

    post_comment = PostComment.create!(:post_id => post.id)

    post.comments_count = -1
    post.save!

    fixed = PostComment.counter_culture_fix_counts
    expect(fixed.length).to eq(1)
    expect(post.reload.comments_count).to eq(1)
  end

  it "should use multi-level relation primary key on counter destination table correctly when fixing counts" do
    categ = Categ.create!
    categ.update(cat_id: Categ::CAT_1)

    subcateg = Subcateg.create!
    subcateg.update(
      subcat_id: Subcateg::SUBCAT_1,
      categ: categ
    )

    Post.create!(subcateg: subcateg)

    categ.update(posts_count: -1)

    fixed = Post.counter_culture_fix_counts :only => [[:subcateg, :categ]]

    expect(fixed.length).to eq(1)
    expect(categ.reload.posts_count).to eq(1)
  end

  it "should work correctly with string keys" do
    string_id = HasStringId.create(id: "1")
    string_id2 = HasStringId.create(id: "abc")

    user = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(1)

    user2 = User.create :has_string_id_id => string_id.id

    string_id.reload
    expect(string_id.users_count).to eq(2)

    user2.has_string_id_id = string_id2.id
    user2.save!

    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(1)
    expect(string_id2.users_count).to eq(1)

    user2.destroy
    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(1)
    expect(string_id2.users_count).to eq(0)

    user.destroy
    string_id.reload
    string_id2.reload
    expect(string_id.users_count).to eq(0)
    expect(string_id2.users_count).to eq(0)
  end
end
