class Invitation < ActiveRecord::Base
  attr_accessible :user_id, :meet_id, :invitee

  belongs_to :user
  belongs_to :meet

  validates :user_id, :presence => true
  validates :meet_id, :presence => true
  validates :invitee, :presence => true, :length => { :maximum => 25000 }

  default_scope :order => 'invitations.created_at DESC'
end
