class ChattersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:update] do |controller|
    controller.filter_params(:chatters, :strip => [:content])
  end
  before_filter :authenticate
  before_filter :authorized_chatter_owner, :only => :destroy
  before_filter :authorized_chatter, :only => :create
  #before_filter :authroized_chatter_meet_owner, :only => :show

  JSON_CHATTER_DETAIL_API = { :methods => [:chatter_photo_small],
                              :include => [:comments],
                              :except => [:created_at, :cached_info,
                                          :photo_content_type, :photo_file_name,
                                          :photo_file_size, :photo_updated_at] }

  def create
    @chatter = Chatter.new(@filterd_params)
    if ((@chatter.content.blank? && !@chatter.photo) || params[:discard])
      # Empty post, quietly ignore it.
      respond_to do |format|
        format.html { redirect_back @meet }
        format.json { head :ok }
      end
    else
      # A comment can not have a photo. Silently drop the photo.
      @chatter.photo = nil if (@chatter.photo? && @topic)
      current_user.chatters << @chatter
      @meet.chatters << @chatter
      if @chatter.photo?
        @meet.photos << @chatter
      end
      if @topic # a comment to this topic
        @topic.comments << @chatter
        @topic.comements_count += 1
      else # a new topic of the meet
        @meet.topics << @chatter
        @meet.topics_count += 1
      end
      if @chatter.save
        @topic.save if @topic
        @meet.opt_lock_protected { @meet.update_chatters_count; @meet.save }
        respond_to do |format|
          format.html { redirect_back @meet, :flash => { :success => "Posted!" } }
          format.json { render :json => @chatter.to_json(JSON_CHATTER_DETAIL_API) }
        end
      else
        respond_to do |format|
          format.html { render 'meets/show' }
          format.json { render :json => @chatter.errors.to_json, :status => :unprocessable_entity }
        end
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
    delete_chatters(current_user, [@chatter])
    respond_to do |format|
      format.html { redirect_back meet, :flash => { :success => "Chatter deleted!" }
      format.json { header :ok }
    end
  end
  
end
