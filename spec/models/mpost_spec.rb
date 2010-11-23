require 'spec_helper'

describe Mpost do

  before(:each) do
    @user = Factory(:user)
    @attr = {
      :time => Time.now.iso8601,
      :lat => 37.793621,
      :lng => -122.395899,
      :lerror => 30,
      :user_dev => "11:11:11:11:11:11",
      :devs => "11:22:33:44:55:66, aa:bb:cc:dd:ee:ff"
    }
  end

  it "should create a new instance given valid attributes" do
    @user.mposts.create!(@attr)
  end

  describe "user associations" do

    before(:each) do
      @mpost = @user.mposts.create(@attr)
    end

    it "should have a user attribute" do
      @mpost.should respond_to(:user)
    end

    it "should have the right associated user" do
      @mpost.user_id.should == @user.id
      @mpost.user.should == @user
    end
  end
end
