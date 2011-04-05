# == Schema Information
# Schema version: 20110405033701
#
# Table name: chatters
#
#  id                 :integer         not null, primary key
#  user_id            :integer
#  content            :text
#  photo_content_type :string(255)
#  photo_file_name    :string(255)
#  photo_file_size    :integer
#  photo_updated_at   :datetime
#  created_at         :datetime
#  updated_at         :datetime
#  meet_id            :integer
#  topic_id           :integer
#  cached_info        :text
#  toggle_flag        :boolean
#

class Chatter < ActiveRecord::Base
  attr_accessor :loaded_top_comments, :loaded_comments, :new_comment_ids, :loaded_user
  attr_writer   :is_new_chatter
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
      :original  => "1000x1000>",
      :small  => "54x54",
      :normal => "245x245"
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
    includes(:meet=>:mposts).select("chatters.id", "chatters.update_at")
                            .where("mposts.user_id = ?", user.id)
  }
  scope :all_chatters_of, lambda {|chatter_ids|
    where("chatters.id IN (?)", chatter_ids)
  }
  scope :related_topic_ids, lambda {|user|
    includes(:meet=>:mposts).select("chatters.id", "chatters.update_at")
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
    force_timestamping
  end
  def comments_count
    return cached_info ? (cached_info[:comments_count] || 0) : 0
  end
  def top_comment_ids
    return cached_info ? (cached_info[:top_comment_ids] || []) : []
  end
  def top_comments
    return Chatter.find(top_comment_ids).compact
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
    return photo? ? photo.url : nil
  end
  def chatter_photo
    return photo? ? photo.url(:normal) : nil
#   return chatter_photo_orig
  end
  def chatter_photo_small
    return photo? ? photo.url(:small) : nil
#   return chatter_photo_orig
  end

  def marked_user
    return @loaded_user.as_json(UsersController::JSON_USER_DETAIL_API)
  end

  def marked_chatters
    return [] if @loaded_comments.blank?
    res = []
    #@loaded_comments.reverse_each {|comment|
    @loaded_comments.each {|comment|
      comment.is_new_chatter = @new_comment_ids.include?(comment.id)
      res << {:chatter => comment.as_json(ChattersController::JSON_CHATTER_MARKED_COMMENT_API)}
      comment.is_new_chatter = nil
    }
    return res
  end

  def is_new_chatter
    return @is_new_chatter.present?
  end

  # Change of contents in cached_info may not trigger timestamp update, force to update
  # by toggling cached_info_flag.
  def force_timestamping
    if toggle_flag.nil?
      self.toggle_flag = false
    else
      self.toggle_flag = !toggle_flag
    end
  end

end
