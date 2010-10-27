class Mpost < ActiveRecord::Base
  attr_accessible :time, :lng, :lat, :devs

  belongs_to :user

  validates :time, :presence => true
  validates :user_id, :presence => true
  validates :lng, :presence => true
  validates :lat, :presence => true
  validates :devs, :presence => true, :length => { :maximum => 200 }  

  default_scope :order => 'mposts.created_at DESC'
end
