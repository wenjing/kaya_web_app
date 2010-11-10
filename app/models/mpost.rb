# == Schema Information
# Schema version: 20101109025524
#
# Table name: mposts
#
#  id         :integer         not null, primary key
#  user_id    :integer
#  meet_id    :integer
#  time       :datetime
#  lng        :decimal(, )
#  lat        :decimal(, )
#  devs       :text
#  created_at :datetime
#  updated_at :datetime
#  lerror     :float
#  user_dev   :string(255)
#

class Mpost < ActiveRecord::Base
  attr_accessible :time, :lng, :lat, :devs

  belongs_to :user
  belongs_to :meet

  validates :time, :presence => true
  validates :user_id, :presence => true
  validates :lng, :presence => true
  validates :lat, :presence => true
  validates :lerror, :presence => true
  validates :user_dev, :presence => true, :length => { :maximum => 200 }  
  validates :devs, :presence => true, :length => { :maximum => 40000 } # at least 200 devs  

  default_scope :order => 'mposts.created_at DESC'

  # The devs are fed as a comma seperated string. They are converted into a set and save
  # to db by marshal it into text. Fortunately, db marshal/unmarshl parts are handled by rails
  # automatically. Mpost relations are checked by device ids. It performs better by using Set
  # structure.
  # Assgin to devs_str instead of assigning devs directly: :devs_str=>"dev1,dev2,dev3"
  def devs_str=(devs_str)
    self.devs = Set.new
    split(/[ \t\n,;]+/).each {|dev| devs << dev}
  end

  # Following functions are by hong.zhao
  # They are required by backend processer.
  # Check processed or not (meet != nil => processed)
  def is_processed?
    return meet_id != nil # might be faster than check meet directly
  end
  # Trigger time is when the mpost is sampled. Shall be same as time. This one
  # is used instead to make sure it is utc time.
  def trigger_time
    return time ? time.getutc : nil
  end
  # Return true if its devs include other's user_dev 
  def see?(other)
    return other ? devs.include?(other.user_dev) : false
  end
  def be_seen?(other)
    return other ? other.see?(self) : false
  end
  def see_or_be_seen?(other)
    return other ? (see?(other) && be_seen?(other)) : false
  end
  # Merge other_devs into devs
  def merge_devs(other_devs)
    devs.merge(other_devs)
  end

end
