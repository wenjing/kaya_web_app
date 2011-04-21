# == Schema Information
# Schema version: 20110227025014
#
# Table name: mposts
#
#  id            :integer         primary key
#  user_id       :integer
#  meet_id       :integer
#  time          :timestamp
#  created_at    :timestamp
#  updated_at    :timestamp
#  lerror        :float
#  user_dev      :string(255)
#  devs          :text
#  lng           :decimal(, )
#  lat           :decimal(, )
#  note          :string(255)
#  host_mode     :integer
#  collision     :boolean
#  host_id       :string(255)
#  status        :integer         default(0)
#  invitation_id :integer
#  cirkle_id     :integer
#

# Status
# 0 or nil: ordinary mpost (meet, user)
# 1       : deleted mpost
# 2       : invitation pending mpost

require 'meet_processer'

class Mpost < ActiveRecord::Base
  CIRKLE_MARKER = '#cirkle#'
  DEV_TIME_TOLERANCE = 3.0 # time diff tolerance when 2 BT saw each other

  attr_accessible :time, :lng, :lat, :lerror, :user_dev,
                  :devs, :note, :host_mode, :host_id, :collision, :cirkle_id
  attr_accessor   :compatible_mode

  belongs_to :user, :inverse_of => :mposts
  belongs_to :meet, :inverse_of => :mposts
  belongs_to :invitation

  validates :time, :presence => { :message => "date time missing or unrecognized format" }
  #validates :user_id, :presence => true
  validates :lng,  :numericality => { :allow_nil => true,
                                      :greater_than_or_equal_to => BigDecimal("-180.0"),
                                      :less_than_or_equal_to    => BigDecimal(" 180.0") }
  validates :lat,  :numericality => { :allow_nil => true,
                                      :greater_than_or_equal_to => BigDecimal("-90.0"),
                                      :less_than_or_equal_to    => BigDecimal(" 90.0") }
  validates :lerror, :numericality => { :allow_nil => true, :greater_than_or_equal_to => 0.0 }
  validates :user_dev, :presence => true, :length => { :in => 1..200 }  
  validates :devs, :length => { :allow_nil =>true, :in => 0..40000 } # at least 200 devs  
  #validates :host_mode, :presence => true

  default_scope :order => 'mposts.created_at DESC'
  scope :user_meet_mposts, lambda {|user, meet|
    where("mposts.user_id = ? AND mposts.meet_id = ? AND mposts.status = ?",
          user.id, meet.id, 0)
  }
  scope :pending_user_meet_mposts, lambda {|user, meet|
    where("mposts.user_id = ? AND mposts.meet_id = ? AND mposts.status = ?",
          user.id, meet.id, 2)
  }
  scope :join_owner, lambda {|join_guest|
    where("mposts.host_id = ? AND mposts.host_mode = ?", join_guest.host_id, 3)
  }
  scope :join_client, lambda {|join_guest|
    where("mposts.host_id = ? AND mposts.host_mode = ?", join_guest.host_id, 4)
  }
  scope :join_owner_or_client, lambda {|join_guest|
    where("mposts.host_id = ? AND mposts.host_mode IN (?)", join_guest.host_id, [3,4])
  }

  serialize :devs, Hash # shall use Set, but rails serialize does not work with it

  def active?
    return status == 0
  end
  def deleted?
    return status == 1
  end
  def pending?
    return status == 2
  end
  def delete
    self.status = 1
    return self
  end
  def recovery
    self.status = 0
    return self
  end

  def collision?
    return !collision.nil? && collision != 0 && collision != false
  end

  # The devs are fed as a comma seperated string. They are converted into a set and save
  # to db by marshal it into text. Fortunately, db marshal/unmarshl parts are handled by rails
  # automatically. Mpost relations are checked by device ids. It performs better by using Set
  # structure.
  # Assgin to devs_str instead of assigning devs directly: :devs_str=>"dev1,dev2,dev3"
  def devs=(str)
    devs0 = {}
    str.split(/[,]+/).each {|dev|
      dev_items = dev.split(DEV_DELIMITER)
      dev_time = dev_items.pop # the last item is always timestamp, seperate it from the rest
      dev = dev_items.join(DEV_DELIMITER)
      devs0[dev] = dev_time.to_i
    }
    write_attribute(:devs, devs0)
  end

  # Following functions are by hong.zhao
  # They are required by backend processer.
  # Check processed or not (meet != nil => processed)
  def is_processed?
    return meet_id? # might be faster than check meet directly
  end
  def is_peer_mode?
    return host_mode.blank? || host_mode == 0
  end
  def is_host_owner?
    return host_mode.present? && host_mode == 1 && host_id.present?
  end
  def is_host_guest?
    return host_mode.present? && host_mode == 2 && host_id.present?
  end
  def is_join_owner?
    return host_mode.present? && host_mode == 3 && host_id.present?
  end
  def is_join_guest?
    return host_mode.present? && host_mode == 4 && host_id.present?
  end
  def force_to_peer_mode 
    self.host_mode = 0
    self.host_id = nil
  end

  # For new api interface, it is different from the old version of host mode
  def check_compatible
    @compatible_mode = Mpost.is_compatible_user_dev?(user_dev)
  end
  def is_none_host_mode?
    # The new host mode API is completely different from the old one. It is
    # more like a special version peer mode.
    return !Mpost.is_compatible_user_dev?(user_dev) || is_peer_mode?
  end
  def is_cirkle_hoster?
    return host_mode == 1 && host_id.nil?
  end
  def is_cirkle_guest?
    return host_mode == 2 && host_id.nil?
  end
  def is_cirkle_creater?
    return host_mode == 3 && host_id.nil?
  end

  CIRKLE_DEV_ITEM_COUNT = 5 # user_name:user_id:meet_name:meet_id:timestamp
  PEER_DEV_ITEM_COUNT = 4 # user_name:user_id:meet_name:timestamp
  DEV_DELIMITER = ":"
  def self.is_compatible_user_dev?(dev)
    dev.split(DEV_DELIMITER).size == 2
  end
  def self.is_peer_user_dev?(dev)
    dev.split(DEV_DELIMITER).size == PEER_DEV_ITEM_COUNT
  end
  def self.is_cirkle_user_dev?(dev)
    dev.split(DEV_DELIMITER).size == CIRKLE_DEV_ITEM_COUNT
  end
  def self.is_peer_devs?(dev)
    dev.split(DEV_DELIMITER).size == PEER_DEV_ITEM_COUNT-1
  end
  def self.is_cirkle_devs?(dev)
    dev.split(DEV_DELIMITER).size == CIRKLE_DEV_ITEM_COUNT-1
  end
  def self.user_id_from_dev(dev)
    dev.split(DEV_DELIMITER).second.to_i
  end
  def self.cirkle_name_from_dev(dev)
    dev.split(DEV_DELIMITER).third
  end
  def self.cirkle_id_from_dev(dev)
    dev.split(DEV_DELIMITER).fourth.to_i
  end
  def self.timestamp_from_dev(dev) # always the last one regardless its mdoe
    dev.split(DEV_DELIMITER).last.to_i
  end

  # Some data directly from API have to be processed before can proceed further.
  def process_from_api
    # No further process for older version API
    is_peer_dev = Mpost.is_peer_user_dev?(user_dev)
    is_cirkle_dev = Mpost.is_cirkle_user_dev?(user_dev)
    return unless is_peer_dev || is_cirkle_dev

    delta_time = Time.now.utc - time # estimate time difference between server and client
    # Ajust devs' client time to match those in server's
    self.devs ||= ""
    devs.each_key {|dev| self.devs[dev] += delta_time}

    # The time is mpost's send time. Now all time adjustments are done, change it to event time so
    # it is consistent to older version of mpost.
    self.time = Time.at(Mpost.timestamp_from_dev(user_dev)).getutc

    # Process host_mode and related data
    self.host_mode = 0 # default to peer mode
    if is_cirkle_dev # hoster or creater
      cirkle_id0 = Mpost.cirkle_id_from_dev(user_dev)
      if cirkle_id0 == 0 # cirkle creater
        self.host_mode = 3
      else
        self.host_mode = 1 # cirkle hoster
        self.cirkle_id = cirkle_id0
      end
    else # peer mode or cirkle guest
      # Check if a guest by probing its devs list for any cirkle hoster
      hoster_dev = devs.find {|dev,tm| Mpost.is_cirkle_devs?(dev)}
      if hoster_dev # set to cirkle guest mode and only keep the hoster's dev in devs list
        self.host_mode = 2
        self.devs = hoster_dev.join(DEV_DELIMITER)
        self.cirkle_id = Mpost.cirkle_id_from_dev(hoster_dev[0])
      end
    end
  end

  # hoster_id is same as user_dev (hoster) and devs (guest)
  def hoster_from_host_id # extract hoster's user_id from host_id
    return (is_host_owner? || is_host_guest?) ? host_id.split(DEV_DELIMITER).second.to_i : nil
  end
  def meet_name_from_host_id # extract meet_name from host_id
    return (is_host_owner? || is_host_guest?) ? host_id.split(DEV_DELIMITER).third : nil
  end
  def meet_from_host_id # extract meet_id from host_id
    return host_id.present? ? host_id.split(DEV_DELIMITER).fourth.to_i : nil
  end

  # Trigger time is when the mpost is sampled. Shall be same as time. This one
  # is used instead to make sure it is utc time.
  # Also, make sure trigger time is no later than created time
  def trigger_time
    return !time? ? created_at.getutc : [time.getutc, created_at.getutc].min
  end

  # Extract base part of user_dev (compatible to previous veresion) by removing timestamp
  def base_dev
    items = user_dev.split(DEV_DELIMITER)
    if (items.size == CIRKLE_DEV_ITEM_COUNT || items.size == PEER_DEV_ITEM_COUNT)
      items.pop # remove the last item which is timestamp
    end
    return items.join(DEV_DELIMITER)
  end
  # Return true if its devs include other's user_dev. No time consideration.
  def see_dev?(other_dev)
    return other_dev ? (base_dev == other_dev || devs.include?(other_dev)) : false
  end
  def see?(other)
    other_base = other.base_dev
    return other ? (base_dev == other_base || devs.include?(other_base)) : false
  end
  def seen_by?(other)
    return other ? other.see?(self) : false
  end
  def see_or_seen_by?(other)
    return other ? (see?(other) || seen_by?(other)) : false
  end
  def see_common?(other) # see a common dev?
    if other
      devs.each {|dev| return true if other.devs.include?(dev)}
    end
    return false
  end
  # This is not simply A see B and B see A. A and B must see each other at same time.
  # Once special case, return true if A and B has exact same user_dev
  def see_each_other?(other)
    # If from same user and exact same session (user_dev has session builtin), return true
    return true if user_dev == other.user_dev

    # However, if from same user but with different session, return false
    base_dev0 = base_dev
    other_base = other.base_dev
    return false if base_dev0 == other_base

    time_from_other = other.devs.include?(base_dev0) ? (other.devs[base_dev0]||0) : nil
    other_time = devs.include?(other_base) ? (devs[other_base]||0) : nil
    return time_from_other && other_time &&
           (time_from_other - other_time).abs <= DEV_TIME_TOLERANCE
  end

  def is_cirkle_mpost?
    return host_id == Mpost::CIRKLE_MARKER && user_dev = Mpost::CIRKLE_MARKER
  end
  def cirkle_ref_count
    return host_mode
  end
  def cirkle_ref_count=(ref_count)
    self.host_mode = ref_count
  end

  # 0 : pending to be processed
  # 1 : meet created succesfully
  # 2 : meet cancelled by collision
  # 3 : meet cancelled by user or admin delete action
  # 4 : invitation pending
  def processing_status
    if meet.present?
      if deleted? && meet.collision?
        return 2
      elsif deleted? && !meet.collision?
        return 3
      elsif pending?
        return 4
      else
        return 1
      end
    else
      if collision?
        return 2
      elsif deleted?
        return 3
      else
        return 0
      end
    end
  end

  def perform
    # this is what the worker will call
    logger.debug "calling perform mpost"
    MeetWrapper.new.process_mpost(id, created_at.getutc)
  end

end
