# == Schema Information
# Schema version: 20100829021049
#
# Table name: users
#
#  id                 :integer         not null, primary key
#  name               :string(255)
#  email              :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  encrypted_password :string(255)
#  salt               :string(255)
#  admin              :boolean
#

class User < ActiveRecord::Base
  attr_accessor   :password
  attr_accessible :name, :email, :password, :password_confirmation, :photo
  
  has_many :mposts, :dependent => :destroy, :inverse_of => :user

  has_many :meets, :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 0]
  has_many :deleted_meets, :class_name => "Meet", :source => :meet,
                   :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 1]
  has_many :pending_meets, :class_name => "Meet", :source => :meet,
                   :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 2]
  has_many :solo_meets, :class_name => "Meet", :source => :meet,
                  :through => :mposts, :uniq => true,
                  :conditions => ['mposts.status = ? AND meets.meet_type = ?', 0, 1]
  has_many :private_meets, :class_name => "Meet", :source => :meet,
                  :through => :mposts, :uniq => true,
                  :conditions => ['mposts.status = ? AND meets.meet_type = ?', 0, 2]
  has_many :group_meets, :class_name => "Meet", :source => :meet,
                  :through => :mposts, :uniq => true,
                  :conditions => ['mposts.status = ? AND meets.meet_type = ?', 0, 3]

  has_many :hosted_meets, :class_name => "Meet", :foreign_key => "hoster_id",
                          :inverse_of => :hoster

  has_many :pending_invitations, :class_name => "Invitation", :source => :invitation,
                   :through => :mposts, :uniq => true,
                   :conditions => ['mposts.status = ?', 2]

  has_many :chatters, :dependent => :destroy, :inverse_of => :user
  has_many :invitations, :dependent => :destroy, :inverse_of => :user
  has_many :mviews, :dependent => :destroy, :inverse_of => :user
  #has_may :invitees, :class_name => "Mview",
  #                   :dependent => :nullify, :inverse_of => :inviter

  # relationship = following = I am following someone
  #has_many :relationships, :foreign_key => "follower_id" :dependent => :destroy,
  # reverse relationship = being followed = I am being followed by someone
  #has_many :reverse_relationships, :class_name => "Relationship", :foreign_key => "followed_id",
  # :following = :followeds = :users
  # each user follows many users, through relationships, where foreign key is followed_id
  #has_many :following, :through => :relationships, :source => :followed
  # :followers = :users
  # each user has many users who follow him/her, through relationships, where foreign key is follower_id
  #has_many :followers, :through => :reverse_relationships, :source  => :follower

  # Paperclips
  has_attached_file :photo,
    :styles => {
      #:original => "1000x1000>",
      :small  => "30x30#",
      :normal => "50x50#"
    },
    :convert_options => {:all => "-auto-orient"},
    :default_url => "http://www.kayameet.com/images/K-50x50.jpg",
    :path => ":attachment/:id/:style.:extension",
    :storage => :s3,
    :s3_credentials => {
      :access_key_id  => ENV['S3_KEY'],
      :secret_access_key => ENV['S3_SECRET']
    },
    :bucket => ENV['S3_BUCKET']

  email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  
  validates :name,  :presence => true,
                    :length   => { :maximum => 50 }, :unless => :exclusive_procedure?
  validates :email, :presence   => true,
                    :format     => { :with => email_regex }, :uniqueness  => true
  validates :password, :presence => true, :confirmation => true,
                       :length => { :within => 6..40 }, :unless => :exclusive_procedure?
  validates :password_confirmation, :presence => true, :unless => :exclusive_procedure?
  validates_attachment_size :photo, :less_than => 1.megabyte
  validates_attachment_content_type :photo, 
    :content_type => ['image/jpg', 'image/jpeg', 'image/gif', 'image/png'] 

  before_save {|record|
    record.email = record.email.strip.downcase if record.email.present?
  }
  before_save {|record|
    password ||= temp_password
    record.encrypt_password
  }

  default_scope :order => 'users.email ASC'

  class << self
    def authenticate(email, submitted_password)
      return nil unless (email.present? && submitted_password.present?)
      user = find_by_email(email.strip.downcase)
      (user && !user.deleted? && user.has_password?(submitted_password)) ? user : nil
    end
    
    def authenticate_with_salt(id, cookie_salt)
      return nil unless (id.present? && cookie_salt.present?)
      user = find_by_id(id)
      (user && !user.deleted? && user.salt == cookie_salt) ? user : nil
    end
  end
  
  # 0 or nil: active user
  # 1       : deleted user
  # 2       : signup pending user
  # 3       : invitation pending user
  # 4       : password reset user
  def active?
    return status == nil || status == 0
  end
  def pending?
    return status == 2 || status == 3 || status == 4
  end
  def signup_pending?
    return status == 2
  end
  def invitation_pending?
    return status == 3
  end
  def deleted?
    return status == 1
  end
  def delete
    self.status = 1
    # Also change email so it can be reused. May the same user signup again.
    if !(/^DELETED_(.*)_(.*)/ =~ email)
      self.email = "DELETED_#{Time.now.getutc.iso8601}_#{email}"
    end
    return self
  end
  def recovery(to_status=0)
    if (to_status != 1 && /^DELETED_(.*)_(.*)/ =~ email)
      org_email = Regexp.last_match(2)
      self.email = org_email if org_email.present?
    end
    self.status = to_status
    return self
  end

  def exclusive_procedure?
    !@exclusive_procedure.nil? && @exclusive_procedure
  end
  def exclusive_save
    @exclusive_procedure = true
    saved = save
    @exclusive_procedure = false
    return saved
  end

  def has_password?(submitted_password)
    matched = encrypted_password.present? && (encrypted_password == encrypt(submitted_password))
    if (!matched && pending? && temp_password.present?)
      matched = (temp_password == submitted_password)
    end
    return matched
  end
  
# def following?(followed)
#   relationships.find_by_followed_id(followed)
# end
# def follow!(followed)
#   relationships.create!(:followed_id => followed.id)
# end
# def unfollow!(followed)
#   relationships.find_by_followed_id(followed).destroy
# end

  def name_or_email
    return name || email
  end

  def self.default_photo
    return "K-50x50.jpg"
  end
  def self.default_photo_small
    return "K-50x50.jpg"
  end
  def photo? # Overwrite the original one, this is much faster
    return photo_content_type.present?
  end
  def user_avatar_orig
    return photo? ? photo.url : User.default_photo
  end
  def user_avatar
    return photo? ? photo.url(:normal) : User.default_photo
  end
  def user_avatar_small
    #"http://www.gravatar.com/avatar/" + Digest::MD5.hexdigest(self.email.strip.downcase) + "?size=50"
    return photo? ? photo.url(:small) : User.default_photo_small
  end

  # Return most recent meets upto limit
  # all     : 0
  # solo    : 1
  # private : 2
  # group   : 3
  def top_meet_ids(limit, type=nil)
    return raw_meet_ids_of_type(type).limit(limit).collect {|v| v.meet_id}
  end
  def top_meets(limit, type=nil)
    if meets.loaded?
      return meets.to_a.select {|meet| meet.of_type?(type)}.slice(0..limit-1)
    else
      return meets_of_type(type).limit(limit).to_a
    end
  end

  # Return most recent meets from time_ago
  def recent_meet_ids(time_ago, type=nil)
    time_after = Time.now-time_ago
    return raw_meet_ids_of_type(type).where("created_at >= ?", time_after)
                                     .collect {|v| v.meet_id}
  end
  def recent_meets(time_ago, type=nil)
    time_after = Time.now-time_ago
    if meets.loaded?
      return meets.to_a.select {|meet| meet.of_type?(type) && meet.time >= time_after}
    else
      return meets_of_type(type).where("created_at >= ?", time_after).to_a
    end
  end

  # Return most recent met friends within specified meets, upto limit
  def top_friend_ids(within_meet_ids, limit)
    return meet_friend_ids(within_meet_ids, limit, true)
  end
  def top_friends(within_meet_ids, limit)
    return meet_friends(within_meet_ids, limit, false)
  end

  # Return most recent met friends within specified meets
  def all_friend_ids(within_meet_ids)
    return meet_friends(within_meet_ids, :all, true)
  end
  def all_friends(within_meet_ids)
    return meet_friends(within_meet_ids, :all, false)
  end

  # Return most recent comments upto limit
  def top_chatters(limit)
    # Can not use user=>chatters relation, it only returns user's own chatters.
    # We want chatters related to user's meets.
    # Also, unlike friends, can not rely on meet time. Chatter time is independent 
    # of meet time.
    top_ids = Chatter.related_topic_ids(self).limit(limit).select {|v| v.id}
    return Chatter.all_topics_of(top_ids)
  end

  # Return most recent met comments from time_ago
  def recent_chatters(time_ago)
    time_after = Time.now-time_ago
    recent_ids = Chatter.related_topic_ids(self)
                        .where("chatters.created_at >= ?", time_after).select {|v| v.id}
    return Chatter.all_topics_of(recent_ids)
  end

  # Return a hash of friends with array of common meets as value
  def meets_friends
    friends = Hash.new
#   meets.to_a.each {|meet|
#     meet.users.each {|meet_user|
#       (friends[meet_user] ||= Array.new) << meet if meet_user.id != id
#     }
#   }
    friend_infos = []
    within_meet_ids = meet_ids.to_a
    within_meets = Meet.find(within_meet_ids, :select => "id,time,lat,lng")
    while (!within_meet_ids.empty?)
      sliced_meet_ids = within_meet_ids.slice!(0, 100) # 100 meets at a time
      friend_infos.concat(Mpost.select([:user_id,:meet_id])
                                .where("user_id != ? AND meet_id IN (?)", id, sliced_meet_ids))
    end
    friend_ids = friend_infos.collect {|v| v.user_id}.uniq
    friend_users = User.find(friend_ids)
    friend_users.each {|friend|
      friend_meet_ids = friend_infos.select {|v| v.user_id == friend.id}.collect {|v| v.meet_id}.to_set
      friend_meets = within_meets.select {|v| friend_meet_ids.include?(v.id)}
      (friends[friend] ||= Array.new).concat(friend_meets)
    }
    return friends
  end

  # Return all chatters of meets user related to.
  def meets_chatters
    return Chatter.related_to(self)
  end

  def meet_ids_of_type(type)
    return type == 1 ? solo_meet_ids :
           type == 2 ? private_meet_ids :
           type == 3 ? group_meet_ids : meet_ids
  end
  def meets_of_type(type)
    return type == 1 ? solo_meets :
           type == 2 ? private_meets :
           type == 3 ? group_meets : meets
  end

  # Return all meets with this user
  def meet_ids_with(user, type=nil)
    if user.id == id
      return meet_ids_of_type(type)
    else
      user_meet_ids = user.meet_ids_of_type(type).to_set
      return meet_ids.select {|meet_id| user_meet_ids.include?(meet_id)}
    end
  end
  def meets_with(user, type=nil)
    if user.id == id
      return meets_of_type(type)
    else
      user_meet_ids = user.meet_ids.to_set
      return meets.select {|meet| user_meet_ids.include?(meet.id) && meet.of_type?(type)}
    end
  end
  def top_meets_with(user, limit, type=nil)
    if user.id == id
      return top_meets(limit, type)
    else
      user_meet_ids = user.meet_ids.to_set
      return meets.select {|meet| user_meet_ids.include?(meet.id) && meet.of_type?(type)}.slice(0..limit-1)
    end
  end

  # The original meet_ids dose not work, it ignore all conditions
  def meet_ids
    return Mpost.select(["DISTINCT(meet_id)", "created_at"])
                .where("meet_id IS NOT NULL AND user_id = ? AND status = ?", id, 0)
                .collect {|v| v.meet_id}
    #return meets.to_a.collect {|v| v.id}.compact
  end
  def delete_meet_ids
    return Mpost.select(["DISTINCT(meet_id)", "created_at"])
                .where("meet_id IS NOT NULL AND user_id = ? AND status = ?", id, 1)
                .collect {|v| v.meet_id}
    #return delete_meets.to_a.collect {|v| v.id}.compact
  end
  def pending_meet_ids
    return Mpost.select(["DISTINCT(meet_id)", "created_at"])
                .where("meet_id IS NOT NULL AND user_id = ? AND status = ?", id, 2)
                .collect {|v| v.meet_id}
    #return pending_meets.to_a.collect {|v| v.id}.compact
  end
  def solo_meet_ids
    return Mpost.select(["DISTINCT(mposts.meet_id)", "mposts.created_at"]).includes(:meet)
                .where("mposts.user_id = ? AND mposts.status = ? AND meets.meet_type = ?", id, 0, 1)
                .collect {|v| v.meet_id}
    #return solo_meets.to_a.collect {|v| v.id}.compact
  end
  def private_meet_ids
    return Mpost.select(["DISTINCT(mposts.meet_id)", "mposts.created_at"]).includes(:meet)
                .where("mposts.user_id = ? AND mposts.status = ? AND meets.meet_type = ?", id, 0, 2)
                .collect {|v| v.meet_id}
    #return private_meets.to_a.collect {|v| v.id}.compact
  end
  def group_meet_ids
    return Mpost.select(["DISTINCT(mposts.meet_id)", "mposts.created_at"]).includes(:meet)
                .where("mposts.user_id = ? AND mposts.status = ? AND meets.meet_type = ?", id, 0, 3)
                .collect {|v| v.meet_id}
    #return group_meets.to_a.collect {|v| v.id}.compact
  end
  def true_pending_meet_ids
    return [] if pending_meets.count == 0
    active_meet_ids = meet_ids.to_set
    return pending_meet_ids.select {|meet_id| !active_meet_ids.include?(meet_id)} || []
  end
  def true_pending_meets
    return [] if pending_meets.count == 0
    active_meet_ids = meet_ids.to_set
    return pending_meets.to_a.select {|meet| !active_meet_ids.include?(meet.id)} || []
  end

  def dev
    return "#{name_or_email}:#{id ? id : 0}"
  end

  def encrypt_password
    self.salt ||= make_salt
    self.encrypted_password = encrypt(password)
  end

  private
  
    def encrypt(string)
      secure_hash("#{salt}--#{string}")
    end
    
    def make_salt
      secure_hash("#{Time.now.utc}--#{password}")
    end
    
    def secure_hash(string)
      Digest::SHA2.hexdigest(string)
    end

    # Return recent friends met with upto limit with specified meets.
    # Assume meets are already loaded. And, meet.users are only used directly
    # when they are also already loaded. Otherwise use user_ids and load them
    # all together. This will force a eager load of friends within the meets.
    def meet_friends(within_meet_ids = nil, limit = :all, id_only = false)
      # The logic behind this is that we will use one giant DB query instead
      # of multiple smaller query. For each users unloaded meet, it will
      # require a mpost related query even to get user_ids. Assume 5 such
      # small queries cost more than 1 giant one.
      within_meet_ids ||= meet_ids.to_a
      friend_ids = []
      while (!within_meet_ids.empty?)
        sliced_meet_ids = within_meet_ids.slice!(0, 100) # 100 meets at a time
        friend_ids.concat(Mpost.select(["DISTINCT(user_id)", "created_at"])
                               .where("user_id != ? AND meet_id IN (?)", id, sliced_meet_ids)
                               .collect {|v| v.user_id}).uniq!
        break if (limit != :all && friend_ids.size >= limit)
      end
      friend_ids = friend_ids.slice(0..limit-1) unless limit == :all
      return id_only ? friend_ids : User.find(friend_ids)
    end

    def raw_meet_ids_of_type(type)
      if type == 0 || type == nil
        return Mpost.select(["DISTINCT(meet_id)", "created_at"])
                    .where("meet_id IS NOT NULL AND user_id = ? AND status = ?", id, 0)
      else
        return Mpost.select(["DISTINCT(meet_id)", "created_at"]).includes(:meet)
                    .where("meet_id IS NOT NULL AND user_id = ? AND status = ? AND meet.meet_type = ?", id, 0, meet_type)
                    .collect {|v| v.meet_id}
      end
    end

end
