class ChattersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:create] do |controller|
    controller.filter_params(:chatter, :strip => [:content])
  end
  before_filter :authenticate
  before_filter :authorized_chatter, :only => :create
  before_filter :authorized_chatter_owner, :only => :destroy
  #before_filter :authroized_chatter_meet_owner, :only => :show

  JSON_CHATTER_MARKED_DETAIL_API = { :methods => [:chatter_photo, :marked_chatters],
                              :include => {:user => UsersController::JSON_USER_DETAIL_API},
                              :except => [:cached_info, :user_id,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }
  JSON_CHATTER_MARKED_COMMENT_API= { :methods => [:chatter_photo, :is_new_chatter],
                              :include => {:user => UsersController::JSON_USER_DETAIL_API},
                              :except => [:cached_info, :user_id,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }
  JSON_CHATTER_LIST_API   = { :methods => [:chatter_photo, :comments_count],
                              :include => {:user => UsersController::JSON_USER_DETAIL_API},
                              :except => [:cached_info, :user_id,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }
  JSON_CHATTER_COMMENT_API= { :methods => [:chatter_photo],
                              :include => {:user => UsersController::JSON_USER_DETAIL_API},
                              :except => [:cached_info, :user_id,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }
  JSON_CHATTER_DETAIL_API = { :methods => [:chatter_photo],
                              :include => {:comments => JSON_CHATTER_COMMENT_API,
                                           :user => UsersController::JSON_USER_DETAIL_API},
                              :except => [:cached_info, :user_id,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }

  def create
    assert_internal_error(@user||@meet)
    @filtered_params.delete(:meet_id)
    @filtered_params.delete(:user_id)
    @filtered_params.delete(:chatter_id)
    @chatter = current_user.chatters.build(@filtered_params)
    # A comment can not have a photo. Silently drop the photo.
    @chatter.photo = nil if @topic
    if ((@chatter.content.blank? && !@chatter.photo?) || params[:discard])
      # Empty post, quietly ignore it.
      respond_to do |format|
        format.html { redirect_back @meet }
        format.json { head :ok }
      end
    elsif @chatter.save
      @meet = Meet.create_cirkle_between_users(current_user.id==@user.id ? [current_user] : [current_user, @user]) if @user
      @meet.chatters << @chatter
      @meet.photos << @chatter if @chatter.photo?
      if @topic # a comment to this topic
        @topic.comments << @chatter
      else # a new topic of the meet
        @meet.topics << @chatter
      end
      if @topic
        @topic.update_comments_count
        @topic.save
      end
      @meet.opt_lock_protected { @meet.update_chatters_count; @meet.save }
      respond_to do |format|
        format.html { redirect_back @meet, :flash => { :success => "Posted!" } }
        format.json { render :json => @chatter.to_json(@chatter.topic? ?
                                                       JSON_CHATTER_DETAIL_API : JSON_CHATTER_COMMENT_API) }
      end
    else
      respond_to do |format|
        format.html { render 'meets/show' }
        format.json { render :json => @chatter.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

# def show
#   @chatter = Chatter.find_by_id(params[:id])
#   assert_unauthorized(@chatter)
#   respond_to do |format|
#     format.html {
#       render @chatter
#       @title = "meet chatters"
#     }
#     format.json {
#       render :json => @chatter.to_json(:methods => :chatter_photo_small)
#     }
#   end
# end

  def destroy
    delete_chatters([@chatter])
    respond_to do |format|
      format.html { redirect_back @meet, :flash => { :success => "Chatter deleted!" } }
      format.json { head :ok }
    end
  end
  
end
