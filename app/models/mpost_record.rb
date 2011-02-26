# == Schema Information
# Schema version: 20110125155037
#
# Table name: mpost_records
#
#  id         :integer         primary key
#  mpost_id   :integer
#  time       :timestamp
#  created_at :timestamp
#  updated_at :timestamp
#

# Use database to record history to be replayed for debugging purpose
# Has to index basing on :time
class MpostRecord < ActiveRecord::Base

  validates :mpost_id, :numericality => { :allow_nil => true, :greater_than => 0, :only_integer => true }
  validates :time, :presence => { :message => "date time missing or unrecognized format" }

end
