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
  # empty   : 0
  # solo    : 1
  # private : 2
  # group   : 3
  def top_meets(limit, type=nil)
    if meets.loaded?
      return meets.to_a.select {|meet| meet.of_type?(type)}.slice(0..limit-1)
    else
      return meets_of_type(type).limit(limit).to_a
    end
  end

  # Return most recent meets from time_ago
  def recent_meets(time_ago, type=nil)
    time_after = Time.now-time_ago
    if meets.loaded?
      return meets.to_a.select {|meet| meet.of_type?(type) && meet.time >= time_after}
    else
      return meets_of_type(type).where("meets.time >= ?", time_after).to_a
    end
  end

  # Return most recent met friends within specified meets, upto limit
  def top_friends(within_meets, limit)
    return meet_friends(within_meets, limit)
  end

  # Return most recent met friends within specified meets
  def all_friends(within_meets, count_only=true)
    return meet_friends(within_meets, :all, count_only)
  end

  # Return most recent comments upto limit
  def top_chatters(limit)
    # Can not use user=>chatters relation, it only returns user's own chatters.
    # We want chatters related to user's meets.
    # Also, unlike friends, can not rely on meet time. Chatter time is independent 
    # of meet time.
    top_ids = Chatter.related_topic_ids(self).limit(limit).to_a
    return Chatter.all_topics_of(top_ids)
  end

  # Return most recent met comments from time_ago
  def recent_chatters(time_ago)
    time_after = Time.now-time_ago
    recent_ids = Chatter.related_topic_ids(self).where("chatters.created_at >= ?", time_after).to_a
    return Chatter.all_topics_of(recent_ids)
  end

  # Return a hash of friends with array common meets as value
  def meets_friends
    friends = Hash.new
    meets.to_a.each {|meet|
      meet.users.each {|meet_user|
        (friends[meet_user] ||= Array.new) << meet if meet_user != self
      }
    }
    return friends
  end

  # Return all chatters of meets user related to.
  def meets_chatters
    return Chatter.related_to(self)
  end

  def meets_of_type(type)
    return type == 1 ? solo_meets :
           type == 2 ? private_meets :
           type == 3 ? group_meets : meets
  end
  # Return all meets with this user
  def meets_with(user, type=nil)
    if user.id == id
      return meets_of_type(type)
    else
      user_meet_ids = user.meet_ids.to_set
      return meets.select {|meet| user_meet_ids.include?(meet.id) && meet.of_type?(type)}
    end
  end

  def meet_ids
    return meets.to_a.collect {|v| v.id}.compact
  end
  def delete_meet_ids
    return delete_meets.to_a.collect {|v| v.id}.compact
  end
  def pending_meet_ids
    return pending_meets.to_a.collect {|v| v.id}.compact
  end
  def solo_meet_ids
    return solo_meets.to_a.collect {|v| v.id}.compact
  end
  def private_meet_ids
    return private_meets.to_a.collect {|v| v.id}.compact
  end
  def group_meet_ids
    return group_meets.to_a.collect {|v| v.id}.compact
  end
  def true_pending_meets
    return [] if pending_meets.count == 0
    active_meet_ids = meet_ids.to_set
    return pending_meets.to_a.select {|meet| !active_meet_ids.include?(id)} || []
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
    def meet_friends(within_meets = nil, limit = :all, count_only=false)
      within_meets ||= meets
      unloaded_count = within_meets.select {|v| !v.users.loaded?}.count
      if (within_meets.size < 50 && unloaded_count > 5)
        # The logic behind this is that we will use one giant DB query instead
        # of multiple smaller query. For each users unloaded meet, it will
        # require a mpost related query even to get user_ids. Assume 5 such
        # small queries cost more than 1 giant one.
        with_meet_ids = within_meets.collect {|v| v.id}
        friend_ids = Mpost.select([:id, :meet_id, :user_id])
                          .where("user_id != ? AND meet_id IN (?)", id, with_meet_ids)
                          .collect {|v| v.user_id}.uniq
        friend_ids = friend_ids.slice(0..limit-1) unless limit == :all
        return count_only ? friend_ids.size : User.find(friend_ids)

      else
        user_ids = Set.new
        users = Array.new
        within_meets.each {|meet|
          break if (limit != :all && users.size >= limit)
          if meet.users.loaded?
            meet.users.each {|user|
              break if (limit != :all && users.size >= limit)
              unless (user.id == id || user_ids.include?(user.id))
                users << user
                user_ids << user.id
              end
            }
          else # use user_ids, then load them together
            meet.user_ids.each {|user_id|
              break if (limit != :all && users.size >= limit)
              unless (user_id == id || user_ids.include?(user_id))
                users << user_id
                user_ids << user_id
              end
            }
          end
        }
        return user_ids.size if count_only
        # Check users, load those that are not loaded yet. 
        # Have to keep original order though.
        unloaded_users = users.select {|user| user.class != User}
        loaded_users = Hash.new
        User.find(unloaded_users).each {|user| loaded_users[user.id] = user}
        users.collect! {|user| user.class == User ? user : loaded_users[user]}
        return users
      end
    end

end
