class Chatter < ActiveRecord::Base
  attr_accessor :loaded_top_comments
  attr_accessible :content, :photo 

  belongs_to :meet, :inverse_of => :chatters
  belongs_to :user, :inverse_of => :chatters
  belongs_to :topic, :class_name => "Chatter", :inverse_of => :comments
  has_many :comments, :class_name => "Chatter", :foreign_key => "topic_id",
                      :dependent => :destroy, :inverse_of => :topic

  validates :content, :length => { :allow_blank => true, :maximum => 500 }
# validates :user_id, :presence => true,
#                     :numericality => { :greater_than => 0, :only_integer => true }
# validates :meet_id, :numericality => { :greater_than => 0, :only_integer => true }
# validates :topic_id, :numericality => { :allow_nil => true,
#                                         :greater_than => 0, :only_integer => true }

  # Paperclips
  has_attached_file :photo,
    :styles => {
      #:original  => "1000x1000>",
      :small  => "80x120>",
      :normal => "160x200>"
    },
    :convert_options => {:all => "-auto-orient"},
    :path => "images/:id/:style.:extension",
    :storage => :s3,
    :s3_credentials => {
      :access_key_id  => ENV['S3_KEY'],
      :secret_access_key => ENV['S3_SECRET']
    },
    :bucket => ENV['S3_BUCKET']

  # Paperclips
  validates_attachment_size :photo, :less_than => 2.megabyte
  validates_attachment_content_type :photo,
    :content_type => ['image/jpg', 'image/jpeg', 'image/gif', 'image/png']

  default_scope :order => 'chatters.updated_at DESC'

  # Query chatters of meets where user has membership
  scope :related_chatter_ids, lambda {|user|
    includes(:meet=>:mposts).select("DISTINCT(chatters.id)", "chatters.update_at")
                            .where("mposts.user_id = ?", user.id)
  }
  scope :all_chatters_of, lambda {|chatter_ids|
    where("chatters.id IN (?)", topic_ids)
  }
  scope :related_topic_ids, lambda {|user|
    includes(:meet=>:mposts).select("DISTINCT(chatters.id)", "chatters.update_at")
                            .where("mposts.user_id = ? AND chatters.topic_id IS NULL", user.id)
  }
  scope :all_topics_of, lambda {|topic_ids|
    includes(:comments).where("chatters.id IN (?) AND chatters.topic_id IS NULL", topic_ids)
  }
  scope :user_meet_chatters, lambda {|user, meet|
    where("chatters.user_id = ? AND chatters.meet_id = ?", user.id, meet.id)
  }

  serialize :cached_info

  def update_comments_count
    self.cached_info ||= Hash.new
    comment_ids0 = comment_ids.to_a
    self.cached_info[:comments_count] = comment_ids0.count
    self.cached_info[:top_comment_ids] = comment_ids0.slice(0..9)
  end
  def comments_count
    return cached_info ? (cached_info[:comments_count] || 0) : 0
  end
  def top_comment_ids
    return cached_info ? (cached_info[:top_comment_ids] || []) : []
  end
  def top_comments
    return Chatter.find(top_comment_ids).compact!
  end

  def topic?
    return !topic_id?
  end
  def comment?
    return !topic?
  end
  def photo? # Overwrite the original one, this is much faster
    return photo_content_type.present?
  end
  def chatter_photo_orig
    return photo? ? photo.url : ""
  end
  def chatter_photo
    return photo? ? photo.url(:normal) : ""
  end
  def chatter_photo_small
    return photo? ? photo.url(:small) : ""
  end

end
