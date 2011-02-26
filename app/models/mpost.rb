# == Schema Information
# Schema version: 20110125155037
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
#

# Status, access through user<=>meet relation. Do not use directly.
# 0 or nil: ordinary mpost (meet, user)
# 1       : deleted mpost
# 2       : invitation pending mpost
class Mpost < ActiveRecord::Base
  attr_accessible :time, :lng, :lat, :lerror, :user_dev, :devs, :note, :host_mode, :host_id, :collision

  belongs_to :user, :inverse_of => :mposts
  belongs_to :meet, :inverse_of => :mposts
  belongs_to :invitation

  validates :time,    :presence => { :message => "date time missing or unrecognized format" }
  #validates :user_id, :presence => true
  validates :lng, :presence => true,
                  :numericality => { :greater_than_or_equal_to => BigDecimal("-180.0"),
                                     :less_than_or_equal_to    => BigDecimal(" 180.0") }
  validates :lat, :presence => true,
                  :numericality => { :greater_than_or_equal_to => BigDecimal("-90.0"),
                                     :less_than_or_equal_to    => BigDecimal(" 90.0") }
  validates :lerror, :presence => true,
                     :numericality => { :greater_than_or_equal_to => 0.0 }
  validates :user_dev, :presence => true,
                       :length => { :in => 1..200 }  
  validates :devs, :presence => true,
                   :length => { :in => 0..40000 } # at least 200 devs  
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
    devs = Hash.new
    str.split(/[,]+/).each {|dev| devs[dev] = nil} # assign to nil yield least yaml string
    write_attribute(:devs, devs)
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

  def meet_from_host_id # extract meet_id from host_id
    return host_id.present? ? host_id.split(":").last : nil
  end
  def hoster_from_host_id # extract hoster's user_id from host_id
    return (is_host_owner? || is_host_guest?) ? host_id.split(":").second : nil
  end
  def meet_name_from_host_id # extract meet_name from host_id
    return (is_host_owner? || is_host_guest?) ? host_id.split(":").third : nil
  end

  # Trigger time is when the mpost is sampled. Shall be same as time. This one
  # is used instead to make sure it is utc time.
  # Also, make sure trigger time is no later than created time
  def trigger_time
    return !time? ? created_at.getutc : [time.getutc, created_at.getutc].min
  end
  # Return true if its devs include other's user_dev 
  def see_dev?(other_dev)
    return other_dev ? (user_dev == other_dev || devs.include?(other_dev)) : false
  end
  def see?(other)
    return other ? (user_dev == other.user_dev || devs.include?(other.user_dev)) : false
  end
  def seen_by?(other)
    return other ? other.see?(self) : false
  end
  def see_or_seen_by?(other)
    return other ? (see?(other) || seen_by?(other)) : false
  end
  def see_each_other?(other)
    return other ? (see?(other) && seen_by?(other)) : false
  end
  def see_common?(other) # see a common dev?
    if other
      devs.each {|dev| return true if other.devs.include?(dev)}
    end
    return false
  end
  # Merge other_devs into this devs
  def add_devs(other_devs)
    devs.merge!(other_devs)
  end
  def add_dev(other_dev)
    devs[other_dev] = nil
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

end
