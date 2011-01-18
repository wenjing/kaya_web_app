class Invitation < ActiveRecord::Base
  attr_accessible :invitee, :message

  belongs_to :user, :inverse_of => :invitations
  belongs_to :meet, :inverse_of => :invitations

  has_many :pending_mposts, :class_name => "Mpost", :dependent => :destroy,
                            :conditions => ['mposts.status = ?', 2]
  has_many :checked_mposts, :class_name => "Mpost", :dependent => :nullify,
                            :conditions => ['mposts.status != ?', 2]

  # ZZZ hong.zhao, shall also check email validity of all invitees
  validates :invitee, :presence => true, :length => { :maximum => 200 }
  validates :message, :allow_blank => true, :length => { :maximum => 500 }

  default_scope :order => 'invitations.created_at DESC'
  scope :user_meet_invitations, lambda {|user, meet|
    where("invitations.user_id = ? AND invitations.meet_id = ?", user.id, meet.id)
  }

end
