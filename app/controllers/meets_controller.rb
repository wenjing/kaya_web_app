require 'rubygems'
require 'json'

class MeetsController < ApplicationController

  before_filter :only => [:update] do |controller|
    controller.filter_params(:mview, :strip => [:name, :location, :time, :description])
  end
  befire_filter :store_return_point, :only => [:show]
  before_filter :authenticate
  before_filter :authorized_meet_member, :only => [:confirm, :map, :show, :edit, :update, :destroy]

  JSON_MEET_DETAIL_API = { :except => [:created_at, :cached_info], 
                           :methods => [:meet_name, :meet_address],
                           :include => {:users => UsersController::JSON_USER_DETAIL_API,
                                        :chatters => ChattersController::JSON_CHATTER_DETAIL_API} }
  JSON_MEET_LIST_API   = { :except => [:created_at, :cached_info],
                           :methods => [:meet_inviter, :meet_name, :meet_address,
                                        :users_count, :topics_count, :chatters_count, :photos_count,
                                        :peers_name_brief, :invitatons] }

  # The edit and destroy here do not apply to meet itself. It create/update Mviews and 
  # destroy user's Mpost linked to the meet.
  def edit
    @mview = Mview.new
    @mview.fillin_from_meet(@meet)
    @title = "Edit meet profile"
  end

  def update
    if params[:discard]
      respond_to do |format|
        format.html { redirect_back @meet }
        format.json { head :ok }
      end
      return
    end

    # Find first, create one if new, enforce uniqueness
    @mview = Mview.user_meet_mview(current_user, @meet).first
    @mview ||= Mview.new
    @mview.update_attributes(@filterd_params)
    @mview.user = current_user
    @mview.meet = @meet

    if @mview.save
      respond_to do |format|
        format.html { redirect_back @meet, :flash => { :success => "Meet profile updated!" } }
        format.json { render :json => @mview.to_json(:except => [created_at]) }
      end
    else
      @title = "Edit meet profile"
      respond_to do |format|
        format.html { render 'edit' }
        format.json { render :json => @mview.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end
 
  def confirm
    pending_decision(true)
  end

  def decline
    pending_decision(false)
  end

  def destroy
    # There might be multiple mposts linked to same meet. Need to destroy all of them.
    # Also, destroy the related meet_mview (not quite yet).
    delete_meet_mposts
    #delete_meet_mviews
    delete_meet_chatters
    @meet.opt_lock_protected {
      # Also update meet information. Remove self if meet hoster.
      @meet.hoster = nil if (@meet.hoster.present? && current_user?(@meet.hoster))
      @meet.extract_information
      @meet.save
    }
    respond_to do |format|
      format.html { redirect_back meets_user_path(current_user),
                                  :except_url => @meet,
                                  :flash => { :success => "Meet deleted!" } }
      format.json { head :ok }
    end
  end

  def show
    respond_to do |format|
      format.html {
        # Reload again to eager load to prevent db N+1 access
        #@meet = Meet.includes(:users, :chatters).find_by_id(params[:id])
        @friends = @meet.friends(current_user).paginate(:page => params[:friends_page], :per_page => 25)
        @topics = @meet.topics.includes(:comments).paginate(:page => params[:chatters_page], :per_page => 25)
        # This is for partial comment display by Ajax comment show all feature.
        #attach_topic_top_comments(@topics)
        @title = @meet.meet_name
        # Store return path for chatters, edit and delete
      }
      format.json {
        # Reload again to eager load to prevent db N+1 access
        # However, includes is buggy!!!
        render :json => @meet.to_json(JSON_MEET_DETAIL_API);
      }
    end
  end

  def map
    assert_unauthorized(:except=>:html)
    respond_to do |format|
      format.html { @title = @meet.meet_name }
      # JSON interface shall use show instead
    end
  end

  private

    def pending_decision(accept)
      pending_mposts = Mpost.pending_user_meet_mposts(current_user, @meet).to_a
      if accept
        delete_mposts(pending_mposts)
      else 
        pending_mposts.each {|mpost| mpost.status = 0; mpost.save}
        meet.opt_lock_protected {
          if !meet.include_user?(current_user)
            meet.extract_information_from_extra_user(current_user)
            meet.save
          end
        }
      }
      respond_to do |format|
        format.html { redirect_back user_pending_meets_path(current_user) }
        format.json { head :ok }
      end
    end

    def attach_topic_top_comments(topics) 
      comment_ids = Set.new
      topics.each {|topic|
        comment_ids.concat(topic.top_comment_ids)
      }
      comments = Chatters.find(comment_ids.to_a).compact
      topics.each {|topic|
        topic.loaded_top_comments =
          topic.top_comment_ids.collect {|id| topics.drop_while {|tp| tp.id != id}.first}.compact
      }
    end

    def delete_meet_mposts
      mposts = Mpost.user_meet_mposts(current_user, @meet).to_a
      delete_mposts(current_user, mposts)
      #mviews = Mview.user_meet_mview(current_user, @meet)
      #delete_mviews(current_user, mviews)
      chatters = Chatter.user_meet_chatters(current_user, @meet)
      delete_chatters(current_user, chatters)
      invitations = Invitation.user_meet_invitations(current_user, @meet)
      delete_inviations(current_user, invitations)
    end

end
