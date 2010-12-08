class Chatter < ActiveRecord::Base
  attr_accessible :content, :photo 

  belongs_to :meet
  belongs_to :user

  validates :content, :presence => true, :length => { :maximum => 250 }
  validates :user_id, :presence => true
  validates :meet_id, :presence => true

  # Paperclips
  has_attached_file :photo,
    :styles => {
      :small  => "80x120>",
      :normal => "160x200>"
    },
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

  default_scope :order => 'chatters.created_at DESC'

  def chatter_photo
    self.photo.url(:small)
  end
end
