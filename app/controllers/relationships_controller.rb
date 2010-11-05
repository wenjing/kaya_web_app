class RelationshipsController < ApplicationController
  before_filter :authenticate
  

# creation of a relationship is done via the owner - the follower
# the follower is therefore the current_user, which is authenticated

  def create

# find the followed user
    @user = User.find(params[:relationship][:followed_id])

# the current_user is following the followed - follow! is defined in User model
    current_user.follow!(@user)

# respond to hrml and javascript differently
    respond_to do |format|

# redirect to url_for(@user) - url_for goes through routes
      format.html { redirect_to @user }
      format.js
    end
  end
  
  def destroy
    @user = Relationship.find(params[:id]).followed
    current_user.unfollow!(@user)
    respond_to do |format|
      format.html { redirect_to @user }
      format.js
    end
  end
end
