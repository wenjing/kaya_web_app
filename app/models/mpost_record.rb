# == Schema Information
# Schema version: 20101109025524
#
# Table name: mpost_records
#
#  id         :integer         not null, primary key
#  mpost_id   :integer
#  time       :datetime
#  created_at :datetime
#  updated_at :datetime
#

# Use database to record history to be replayed for debugging purpose
# Has to index basing on :time
class MpostRecord < ActiveRecord::Base

  validates :time, :presence => true

end
