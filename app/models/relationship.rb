# == Schema Information
# Schema version: 20101027191028
#
# Table name: relationships
#
#  id          :integer         not null, primary key
#  follower_id :integer
#  followed_id :integer
#  created_at  :datetime
#  updated_at  :datetime
#

# == Schema Information
# Schema version: 20100831012055
#
# Table name: relationships
#
#  id          :integer         not null, primary key
#  follower_id :integer
#  followed_id :integer
#  created_at  :datetime
#  updated_at  :datetime
#
# both follower_id and followed_id are user_id
# from user (follower) to the users being followed is called relationship (following)
# the other direction, it's reverse_relationship
#
class Relationship < ActiveRecord::Base
  attr_accessible :followed_id
  
# because follower and followed are not the default naming convention (users)
# so we must name the class name User
  
  belongs_to :follower, :class_name => "User"
  belongs_to :followed, :class_name => "User"
  
  validates :follower_id, :presence => true
  validates :followed_id, :presence => true
end
