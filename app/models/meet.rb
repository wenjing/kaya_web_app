# == Schema Information
# Schema version: 20101027191028
#
# Table name: meets
#
#  id             :integer         not null, primary key
#  name           :string(255)
#  description    :text
#  time           :datetime
#  location       :string(255)
#  street_address :string(255)
#  city           :string(255)
#  state          :string(255)
#  zip            :string(255)
#  country        :string(255)
#  lng            :decimal(, )
#  lat            :decimal(, )
#  users_count    :integer
#  image_url      :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#

class Meet < ActiveRecord::Base

  attr_accessible :name, :description, :time, 
                  :location, :street_address, :city, 
                  :state, :zip, :country, 
                  :users_count, :lng, :lat,
                  :image_url

  has_many :mposts
  has_many :users,  :through => :mposts

  validates :name,  :presence => true,
                    :length   => { :maximum => 250 }
  validates :time,  :presence => true
  #validates :lng,  :presence => true
  #validates :lat,  :presence => true
  validates :users_count, :presence => true

  #default_scope :order => 'meets.created_at DESC'
  default_scope :order => 'meets.time DESC'

  # Following functions are by hong.zhao
  # They are required by backend processer.
  # Eearliest and oldest occure time of the meet. Use the :time instead but have
  # to make sure it is converted into utc time. It can also be extracted from
  # mpost dynamically.
  def occured_earliest
    return time ? time.getutc : nil
  end
  def occured_oldest
    return time ? time.getutc : nil
  end
  def extract_information
    # Get users information, make sure it is unique. Extract time (average time as well)
    users.clear
    unique_users = Set.new
    times = Array.new
    mposts.each {|mpost| unique_user << mpost.user; times << mpost.time.to_i}
    unique_users.each {|user| users << user}
    self.users_count = users.size 
    self.time = !times.empty ? Time.at(times.average) : Time.now
    # Extract location
    extract_location
    # Create a default name
    self.name = format("Meeting on %s %swith %d %s",
                       strftime("on %m/%d/%Y"),
                       location ? location : "",
                       users.size, pluralize(users.size, "attendent"))

  end
  def extract_location
    # Calculate weighted average lng+lat
    lngs, lats = Array.new, Array.new
    # Fist we try to get from mpost with accurate location info, which is defined as error
    # is less than 30feet
    mposts.each {|mpost|
      if (mpost.lng && mpost.lat && mpost.lerror < 30.0)
        lngs << mpost.lng
        lats << mpost.lat
      end
    }
    if !lngs.empty?
      mposts.each {|mpost|
        if (mpost.lng && mpost.lat)
          lngs << mpost.lng
          lats << mpost.lat
        end
      }
    end
    if !lngs.empty?
      self.lng, self.lat = lngs.average, lats.average
    else
      self.lng, self.lat = nil, nil
    end
    extract_geocode
  end
  def extract_geocode(retry_times=0)
    # Pending
    self.location = ""
    self.street_address = ""
    self.city= "" 
    self.state = ""
    self.zip = ""
    self.country = "" 
    self.users_count = ""
  end
  def check_geocode(retry_times=0) # check geocode information, try to aquire if missing
    if (!location || location == "")
      extract_geocode(retry_times)
    end
  end

end
