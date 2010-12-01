# == Schema Information
# Schema version: 20101116062125
#
# Table name: mposts
#
#  id         :integer         not null, primary key
#  user_id    :integer
#  meet_id    :integer
#  time       :datetime
#  created_at :datetime
#  updated_at :datetime
#  lerror     :float
#  user_dev   :string(255)
#  devs       :text
#  lng        :decimal(15, 10)
#  lat        :decimal(15, 10)
#  note       :string(255)
#

class Mpost < ActiveRecord::Base
  attr_accessible :time, :lng, :lat, :lerror, :user_dev, :devs, :note

  belongs_to :user
  belongs_to :meet

  validates :time,    :presence => { :message => "date time missing or unrecognized format" }
#  validates :user_id, :presence => true
  validates :lng, :presence => true,
                  :numericality => { :greater_than_or_equal_to => BigDecimal("-180.0"),
                                     :less_than_or_equal_to    => BigDecimal(" 180.0") }
  validates :lat, :presence => true,
                  :numericality => { :greater_than_or_equal_to => BigDecimal("-90.0"),
                                     :less_than_or_equal_to    => BigDecimal(" 90.0") }
  validates :lerror, :presence => true,
                     :numericality => { :greater_than_or_equal_to => 0.0 }
  validates :user_dev, :presence => true 
  #validates :user_dev, :presence => true, :length => { :in => 1..200 }  
  validates :devs   
  #validates :devs, :length => { :in => 0..40000 } # at least 200 devs  

  default_scope :order => 'mposts.created_at DESC'

  serialize :devs, Hash # shall use Set, but rails serialize does not work with it

  # The devs are fed as a comma seperated string. They are converted into a set and save
  # to db by marshal it into text. Fortunately, db marshal/unmarshl parts are handled by rails
  # automatically. Mpost relations are checked by device ids. It performs better by using Set
  # structure.
  # Assgin to devs_str instead of assigning devs directly: :devs_str=>"dev1,dev2,dev3"
  def devs=(str)
    devs = Hash.new
    str.split(/[ \t\n,;]+/).each {|dev| devs[dev] = nil} # assign to nil yield least yaml string
    write_attribute(:devs, devs)
  end

  # Following functions are by hong.zhao
  # They are required by backend processer.
  # Check processed or not (meet != nil => processed)
  def is_processed?
    return meet_id? # might be faster than check meet directly
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
  # Merge other_devs into this devs
  def add_devs(other_devs)
    devs.merge!(other_devs)
  end
  def add_dev(other_dev)
    devs[other_dev] = nil
  end

end
