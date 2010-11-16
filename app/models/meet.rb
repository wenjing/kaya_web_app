# == Schema Information
# Schema version: 20101111214254
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
#  users_count    :integer
#  image_url      :string(255)
#  created_at     :datetime
#  updated_at     :datetime
#  lng            :decimal(15, 10)
#  lat            :decimal(15, 10)
#  lerror         :float
#

require 'kaya_base'

class Meet < ActiveRecord::Base

  attr_accessible :name, :description, :time, 
                  :location, :street_address, :city, 
                  :state, :zip, :country, 
                  :users_count, :lng, :lat, :lerror,
                  :image_url

  has_many :mposts
  has_many :users,  :through => :mposts, :uniq => true

  validates :name,  :presence => true, :length   => { :maximum => 250 }
  validates :time,  :presence => { :message => "date time missing or unrecognized format" }
  #validates :lng,  :presence => true,
  validates :lng,   :numericality => { :greater_than_or_equal_to => BigDecimal("-180.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 180.0"),
                                       :allow_nil => true }
  #validates :lat,  :presence => true
  validates :lat,   :numericality => { :greater_than_or_equal_to => BigDecimal("-90.0"),
                                       :less_than_or_equal_to    => BigDecimal(" 90.0"),
                                       :allow_nil => true }
  #validates :users_count, :presence => true,
  #                        :numericality => { :greater_than_or_equal_to => 0 }

  #default_scope :order => 'meets.created_at DESC'
  default_scope :order => 'meets.time DESC'

  # Following functions are created by hong.zhao
  # They are required by backend processer.
  # Eearliest and oldest occure time of the meet. Use the :time instead but have
  # to make sure it is converted into utc time. It can also be extracted from
  # mpost dynamically.
  def occured_earliest
    return time? ? time.getutc : nil
  end
  def occured_latest
    return time? ? time.getutc : nil
  end

  def extract_information
    # Extract meeting time (average time)
    times = Array.new
    zones = Hash.new
    unique_users = Set.new
    notes = Hash.new
    mposts.each {|mpost|
      times << mpost.time.to_i
      if !zones[mpost.time.zone]
        zones[mpost.time.zone] = 1
      else
        zones[mpost.time.zone] += 1
      end
      unique_users << mpost.user_id
      if notes[mpost]
        notes[mpost] += 1
      else
        notes[mpost] = 1
      end
    }
    self.time = Time.at(times.average).getutc unless times.empty?
    self.time ||= Time.now.getutc

    # Extract location
    extract_location

    # Create a default name and description
    zone = get_time_zone_from_location(lat, lng)
    zone ||= (zones.max_by{|h| h[1]})[0] unless zones.empty? # from most common time zone in users
    zone ||= time.zone
    zone_time = time.in_time_zone(zone) # convert to meet local time
    note = (notes.max_by {|h| h[1]})[0]
    if note
      self.name = note # user majority notes
    else
      self.name = format("Meeting_%s", zone_time.strftime("%Y-%m-%d"))
    end
    # Can not call users before it is saved. It may not be availabe and may confuse rails.
    # Instead, count number of users through unique_users.
    self.description = format("Meeting %s %swith %s",
                       zone_time.strftime("on %Y-%m-%d %I:%M%p"),
                       !location.blank? ? "at #{location} " : "",
                       pluralize(unique_users.count, "attendent"))
  end

  def check_geocode(retry_times=0) # check geocode information, try to aquire if missing
    if (!location || location == "")
      extract_geocode(retry_times)
    end
  end

private

  def extract_location
    # Calculate weighted average lng+lat
    lngs, lats, lweights = Array.new, Array.new, Array.new
    # Fist we try to get from mpost with accurate location info, which is defined as error
    # is less than 30feet, 100feet
    [30.0, 100.0, -1.0].each {|val|
      mposts.each {|mpost|
        if (mpost.lng? && mpost.lat? && mpost.lerror? &&
            (val <= 0.0 || mpost.lerror < val))
          lngs << mpost.lng
          lats << mpost.lat
          lweights << (1.0/[mpost.lerror,0.01].max)**2
        end
      }
      break unless lngs.empty?
    }
    if !lngs.empty?
      self.lng = lngs.mean_sigma_with_weight(lweights)[0]
      self.lat = lats.mean_sigma_with_weight(lweights)[0]
      self.lerror = [(1.0/Math.sqrt(lweights.mean)+0.4999).round,1.0].max
    else
      # self.lng, self.lat = nil, nil # keep the original
    end
    extract_geocode
  end

  def extract_geocode(retry_times=0)
    # Pending ...
    self.location = ""
    self.street_address = ""
    self.city= "" 
    self.state = ""
    self.zip = ""
    self.country = "" 
    #self.image_url = ""
  end

  def get_time_zone_from_location(lat, lng)
    return nil if (!lat || !lng)
    # Pending ...
    return nil
  end

end
