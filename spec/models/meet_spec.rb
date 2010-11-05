require 'spec_helper'

describe Meet do

  before(:each) do
    @attr = {
      :name => "Bessy's birthday party",
      :description => "Bessy's 16th birthday party was held in The Mountain Winery, Saratoga, at 17:00 - 20:00, on this Saturday. Share your experience here.",
      :time => Time.now,
      :location => "The Mountain Winery",
      :street_address => "14831 Pierce Road",
      :city => "Saratoga",
      :state => "CA",
      :zip => "95070",
      :country => "USA",
      :lng => -90.123456,
      :lat => 106.123456,
      :image_url => "http://www.mountainwinery.com/images/mountainwinery.com/Image/About%20Us/Winery%20Building%20Front.jpg",
      :users_count => 2
    }
  end
  
  it "should create a new instance given valid attributes" do
    Meet.create!(@attr)
  end

  it "should require a time" do
    no_time_meet = Meet.new(@attr.merge(:time => nil))
    no_time_meet.should_not be_valid
  end

  it "should require a (latitude, longitude) coordinate" do
    no_cood_meet = Meet.new(@attr.merge(:lat => nil))
    no_cood_meet.should_not be_valid
    no_cood_meet = Meet.new(@attr.merge(:lng => nil))
    no_cood_meet.should_not be_valid
  end

end
