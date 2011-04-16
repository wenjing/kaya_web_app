require 'rubygems'
require 'json'

class MeetsController < ApplicationController
  before_filter :store_return_point, :only => [:show]
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:update] do |controller|
    controller.filter_params(:mview, :strip => [:name, :location, :time, :description])
  end
  before_filter :authenticate
  before_filter :authorized_meet_member, :only => [:map, :show, :edit, :update, :destroy]
  before_filter :pending_meet_member, :only => [:confirm, :decline]

  JSON_MEET_DETAIL_API = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                        :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:meet_name, :meet_address],
                           :include => {:users => UsersController::JSON_USER_BRIEF_API,
                                        :topics => ChattersController::JSON_CHATTER_DETAIL_API} }
  JSON_MEET_BRIEF_API  = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                      :cirkle_id, :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:meet_name, :meet_address] }
  JSON_MEET_MARKED_API = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                       :cirkle_id, :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:marked_name, :meet_address,
                                        :marked_users, :marked_chatters] }
  JSON_MEET_CIRKLE_API = { :only => [:id, :time, :mage_url, :updated_at],
                           :methods => [:marked_name, :marked_top_users,
                                        :users_count, :topics_count, :chatters_count, :photos_count] }
  JSON_MEET_LIST_API   = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                       :cirkle_id, :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:meet_name, :meet_address,
                                        :users_count, :topics_count, :chatters_count, :photos_count,
                                        :peers_name_brief, :marked_top_users] }
  JSON_MEET_LIST_APIX  = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                       :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:meet_name, :meet_address,
                                        :users_count, :topics_count, :chatters_count, :photos_count,
                                        :peers_name_brief, :marked_top_users] }
  JSON_PENDING_MEET_LIST_API = { :except => [:created_at, :cached_info, :lock_version, :collision, :toggle_flag,
                                             :cirkle_id, :name, :description, :host_id, :meet_type, :hoster_id],
                           :methods => [:meet_inviter, :meet_invitation_message, :meet_other_inviters,
                                        :meet_name, :meet_address,
                                        :users_count, :topics_count, :chatters_count, :photos_count,
                                        :peers_name_brief, :is_new_invitation] }

  # The edit and destroy here do not apply to meet itself. It create/update Mviews and 
  # destroy user's Mpost linked to the meet.
  def edit
    assert_internal_error(@meet)
    @mview = Mview.new
    @mview.fillin_from_meet(@meet)
    @title = "Edit meet profile"
  end

  def update
    assert_internal_error(@meet)
    if params[:discard]
      respond_to do |format|
        format.html { redirect_back @meet }
        format.json { head :ok }
      end
      return
    end

    # Find first, create one if new, enforce uniqueness
    @filtered_params.delete(:id)
    @mview = Mview.user_meet_mview(current_user, @meet).first
    @mview ||= Mview.new
    @mview.update_attributes(@filtered_params)
    @mview.user = current_user
    @mview.meet = @meet

    if @mview.save
      @meet.meet_mview = @mview
      respond_to do |format|
        format.html { redirect_back @meet, :flash => { :success => "Meet profile updated!" } }
        format.json { render :json => @meet.to_json(JSON_MEET_BRIEF_API); }
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
    assert_internal_error(@meet)
    # There might be multiple mposts linked to same meet. Need to destroy all of them.
    # Also, destroy the related meet_mview (not quite yet).
    delete_meet_associates
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
    assert_internal_error(@meet)
    respond_to do |format|
      format.html {
        # Reload again to eager load to prevent db N+1 access
        #@meet = Meet.includes(:users, :chatters).find_by_id(params[:id])
        @friends = @meet.friends(current_user).paginate(:page => params[:friends_page], :per_page => 25)
        @topics = @meet.topics.includes([{:comments=>:user},:user])
                              .paginate(:page => params[:chatters_page], :per_page => 25)
        # This is for partial comment display by Ajax comment "show all" feature.
        #attach_topic_top_comments(@topics)
        @title = @meet.meet_name
        # Store return path for chatters, edit and delete
      }
      format.json {
        # Reload again to eager load to prevent db N+1 access on chatters
        @meet = Meet.includes(:topics=>:comments).find_by_id(params[:id])
        attach_meet_mview(current_user, @meet)
        # Reload again to eager load to prevent db N+1 access
        # However, includes is buggy!!!
        render :json => @meet.to_json(JSON_MEET_DETAIL_API);
      }
    end
  end

  def map
    assert_internal_error(@meet)
    assert_unauthorized(false, :except=>:html)
    respond_to do |format|
      format.html { @title = @meet.meet_name }
      # JSON interface shall use show instead
    end
  end

  private

    def pending_decision(accept)
      assert_internal_error(@meet)
      pending_mposts = Mpost.pending_user_meet_mposts(current_user, @meet).to_a
      if accept
        @meet.opt_lock_protected {
          if !@meet.include_user?(current_user)
            @meet.extract_information_from_extra_user(current_user, pending_mposts)
            @meet.save
          end
          pending_mposts.each {|mpost| mpost.status = 0; mpost.save}
        }
      else
        delete_mposts(pending_mposts)
      end
      respond_to do |format|
        format.html { 
          if (accept && current_user.true_pending_meets.count == 0)
            # The only pending meet is confirmed, got to meet detail
            redirect_to meet_path(@meet)
          else
            redirect_back pending_meets_user_path(current_user)
          end
        }
        format.json {
          if accept
            render :json => @meet.to_json(JSON_MEET_BRIEF_API)
          else
            head :ok
          end
        }
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

    def delete_meet_associates
      mposts = Mpost.user_meet_mposts(current_user, @meet).to_a
      delete_mposts(mposts)
      #mviews = Mview.user_meet_mview(current_user, @meet)
      #delete_mviews(mviews)
      chatters = Chatter.user_meet_chatters(current_user, @meet)
      delete_chatters(chatters)
      invitations = Invitation.user_meet_invitations(current_user, @meet)
      delete_invitations(invitations)
    end

end
