require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'models/conversation'
require 'models/conversation_member'
require 'models/member'

require 'database_cleaner'
DatabaseCleaner.strategy = :deletion

describe "CounterCulture" do
  before(:each) do
    DatabaseCleaner.clean
  end

  describe "option :: joins" do
    let!(:conversation) {Conversation.create(name: 'Chat with Bob')}

    let!(:bob)      {Member.create(name: 'Bob')}
    let!(:mr_guest) {Member.create(name: 'Mr. Guest', user_type: 'G')}

    let!(:conv_memb_bob)   {ConversationMember.create(conversation_id: conversation.id, member_id: bob.id)}
    let!(:conv_memb_guest) {ConversationMember.create(conversation_id: conversation.id, member_id: mr_guest.id)}

	  describe "conditional counts" do
	    it "should give me correct guest count" do
	    	conversation.reload
	    	conversation.guest_count.should == 1
	  	end

	    it "should update the count on delete" do
	    	conv_memb_guest.destroy
	    	conversation.reload

	    	conversation.guest_count.should == 0
	  	end
	  end

	  describe "fix_counts" do
	  	let!(:mr_x)      { Member.create(name: 'Mr. X', user_type: 'G') }
	  	let!(:conv_mr_x) {ConversationMember.create(conversation_id: conversation.id, member_id: mr_x.id)}

	  	it "should give me correct count for legacy data" do
	  		conversation.update_column(:guest_count, 0)
	  		conversation.reload

	  		conversation.guest_count.should == 0

	  		ConversationMember.counter_culture_fix_counts

	  		conversation.reload

	  		conversation.guest_count.should == 3
	  	end

	  	it "should update of delete" do
	  		ConversationMember.delete_all

	  		conversation.reload

	  		conversation.guest_count.should_not eq(0)

	  		ConversationMember.counter_culture_fix_counts

	  		conversation.reload

	  		conversation.guest_count.should == 0
	  	end
	  end
	end
end