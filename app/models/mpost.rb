# == Schema Information
# Schema version: 20101027191028
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
#

class Mpost < ActiveRecord::Base
  attr_accessible :time, :lng, :lat, :devs

  belongs_to :user
  belongs_to :meet

  validates :time, :presence => true
  validates :user_id, :presence => true
  validates :lng, :presence => true
  validates :lat, :presence => true
  validates :devs, :presence => true, :length => { :maximum => 200 }  

  default_scope :order => 'mposts.created_at DESC'
end
