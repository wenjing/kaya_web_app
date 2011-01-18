class Mview < ActiveRecord::Base
  attr_accessible :name, :location, :time, :description

  # Keep this table simple. It only acts as a user layer to a meet. It is used to store user
  # customized meet information. Potential, it can be replacing mpost as through to link users
  # and meets. Right now to keep it simple, there is no has_many relations on user and meets
  # side.
  # It is strictly enforced to be unique on user_id and meet_id combination. It is defined as
  # unique index at DB. Any way at controller, always check for existance. so, no unique
  # validator here.
  belongs_to :user, :inverse_of => :mviews
  belongs_to :meet, :inverse_of => :mviews
  #belongs_to :inviter, :class_name => "User", :inverse_of => :invitees

  validates :name,        :allow_blank => true, :length  => { :maximum => 100 }
  validates :description, :allow_blank => true, :length  => { :maximum => 500 }
  validates :location,    :allow_blank => true, :length  => { :maximum => 100 }

  default_scope :order => 'mviews.created_at DESC'
  scope :user_meet_mview, lambda {|user, meet|
    where("mviews.user_id = ? AND mviews.meet_id = ?", user.id, meet.id).limit(1)
  }
  scope :user_meets_mview, lambda {|user, meets|
    meet_ids =  meets.collect {|meet| meet.id}
    where("mviews.user_id = ? AND mviews.meet_id IN (?)", user.id, meet_ids)
  }

  def fillin_from_meet(meet)
    self.name = meet.meet_name 
    self.description = meet.meet_description
    self.time = meet.meet_time
    self.location = meet.meet_location
  end

  def clone_from(view)
    name = view.name if view.name.present?
    description = view.description if view.description.present?
    time = view.time if view.time.present?
    location = view.location if view.location.present?
  end

end
