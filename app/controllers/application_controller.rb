class ApplicationController < ActionController::Base
  protect_from_forgery
  include SessionsHelper
  include ApplicationHelper

  # current_user must be this user
  def correct_user(id=nil)
    @user ||= find_user(id||params[:id])
    if (!@user || (!current_user?(@user) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be be a admin
  def admin_current_user
    if !admin_user?
      # user can not delete itself even she is an admin
      render_unauthorized
    end
  end

  # current_user must be be a admin and not current user
  def admin_user_except_self(id=nil)
    @user ||= find_user(id||params[:id])
    if (!@user || (!admin_user? || current_user?(@user)))
      # user can not delete itself even she is an admin
      render_unauthorized
    end
  end

  # current_user must be part of this meet
  def authorized_meet_member(id=nil)
    @meet ||= Meet.find_by_id(id||params[:id])
    if (!@meet || (!@meet.include_user?(current_user) && !admin_user?))
      render_unauthorized
    else
      attach_meet_mview(current_user, @meet)
    end
  end

  # current_user must be part of this meet as a pending user
  def pending_meet_member(id=nil)
    @meet ||= Meet.find_by_id(id||params[:id])
    if (!@meet || (!@meet.include_pending_user?(current_user) && !admin_user?))
      render_unauthorized
    else
      attach_meet_mview(current_user, @meet)
    end
  end

  # current_user must be own this mpost
  def authorized_mpost_owner(id=nil)
    @mpost ||= Mpost.find_by_id(id||params[:id])
    if (!@mpost || (!current_user_id?(@mpost.user_id) && !admin_user?))
      render_unauthorized
    elsif (!@mpost.active? && !admin_user?)
      render_removed
    end
  end

  # current_user must be own this chatter
  def authorized_chatter_owner(id=nil)
    @chatter ||= Chatter.find_by_id(id||params[:id])
    if (!@chatter || (!current_user_id?(@chatter.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be part of chatter's meet
  def authorized_chatter_meet_member(id=nil)
    @chatter ||= Chatter.find_by_id(id||params[:id])
    if (!@chatter || !authorized_meet_member(@chatter.meet_id))
      render_unauthorized
    elsif (!@chatter.active? && !admin_user?)
      render_removed
    end
  end

  # current_user must be part of chatter's meet and this chatter must be either
  # a topic or a comment to a topic. Can not add a comment to another comment.
  def authorized_chatter
    if params[:meet_id].present?
      authorized_meet_member(params[:meet_id])
    else
      @topic = Chatter.find_by_id(params[:chatter_id])
      if (!@topic || !@topic.topic?)
        render_unauthorized
      else
        authorized_meet_member(@topic.meet_id)
      end
    end
  end

  # current_user must be own this invitation
  def authorized_invitation_owner(id=nil)
    @invitation ||= Invitation.find_by_id(id||params[:id])
    if (!@invitation || (!current_user_id?(@invitation.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # Standard error handling routes
  def render_invalid(options={}) # 404
    render_error(invalid_url, 404, options)
  end
  def render_unauthorized(options={}) # 422
    render_error(unauthorized_url, 422, options)
  end
  def render_internal_error(options={}) # 500
    render_error(internal_error_url, 500, options)
  end
  def render_removed(options={}) # 422
    render_error(removed_url, 422, options)
  end

  # Assertion and redirect to error page
  class InvalidAssert < Exception; end
  class UnauthorizedAssert < Exception; end
  class InternalErrorAssert < Exception; end
  class RemoveAssert < Exception; end
  rescue_from InvalidAssert do |exception| render_invalid; end
  rescue_from UnauthorizedAssert do |exception| render_unauthorized; end
  rescue_from InternalErrorAssert do |exception| render_internal_error; end
  rescue_from RemoveAssert do |exception| render_remove; end
  def assert_invalid(val=true, options={}, &block)
    render_invalid({:raise=>InvalidAssert}.merge(options)) if (!val || (block && !block.call))
  end
  def assert_unauthorized(val=true, options={}, &block)
    render_unauthorized({:raise=>UnauthorizedAssert}.merge(options)) if (!val || (block && !block.call))
  end
  def assert_internal_error(val=true, options={}, &block)
    render_internal_error({:raise=>InternalErrorAssert}.merge(options)) if (!val || (block && !block.call))
  end
  def assert_remove(val=true, options={}, &block)
    render_remove({:raise=>RemoveAssert}.merge(options)) if (!val || (block && !block.call))
  end

  def filter_params(context, options = {})
    @filtered_params = params[context].nil? ? params.clone : params[context].clone
    @filtered_params.delete(:controller)
    @filtered_params.delete(:action)
    options[:strip].each {|key|
      @filtered_params[key].strip! if @filtered_params[key].present?
    } if options[:strip].present?
  end
  
  def delete_mposts(mposts)
    return unless mposts.present?
    mposts.each {|mpost|
      #next if mpost.destroyed?
      #user, meet = mpost.user, mpost.meet
      #user.mposts.delete(mpost)
      #meet.mposts.delete(mpost) if meet.present?
      #mpost.destroy
      mpost.delete; mpost.save
    }
  end
  def delete_mviews(mviews)
    return unless mviews.present?
    mviews.each {|mview|
      next if mview.destroyed?
      user, meet = mview.user, mview.meet
      user.mviews.delete(mview)
      meet.mviews.delete(mview)
      mview.destroy
    }
  end
  def delete_invitations(invitations)
    return unless invitations.present?
    invitations.each {|invitation|
      next if invitation.destroyed?
      user, meet = invitation.user, invitation.meet
      user.invitations.delete(invitation)
      meet.invitations.delete(invitation) if meet.present?
      invitation.destroy
    }
  end
  def delete_chatters(chatters)
    update_meets = Set.new
    update_topics = Set.new
    chatters.each {|chatter|
      next if chatter.destroyed?
      user, meet = chatter.user, chatter.meet
      topic = chatter.topic
      # Be careful, a topic can be an orphan (no user).
      if (user.present? && chatter.topic?)
        # Delete all current user's comments under this topic first
        chatter.comments.to_a.each {|comment|
          if comment.user_id == user.id
            meet.chatters.delete(comment)
            update_meets << meet
            user.chatters.delete(comment)
            chatter.comments.delete(comment)
            comment.destroy
          end
        }
      end
      if (!chatter.topic? || chatter.comments.empty?)
        # Delete the chatter if it is not a topic or it is has no comments
        meet.chatters.delete(chatter)
        update_meets << meet
        user.chatters.delete(chatter) if user.present?
        if topic.present?
          topic.comments.delete(chatter)
          update_topics << topic
        end
        chatter.destroy
      else
        # Can not delete it, otherwise it will wipe out all comments under it.
        # Orpanize it by removing ownership.
        chatter.user = nil
        chatter.save
      end
    }
    update_meets.each {|meet|
      meet.opt_lock_protected {
        meet.update_chatters_count
        meet.save
      }
    }
    update_topics.each {|topic|
      next if topic.destroyed?
      topic.update_comments_count
      topic.save
    }
  end

  def find_user(user_id)
    return nil if user_id.blank?
    @user_cache ||= {}
    user = @user_cache[user_id]
    if !user
      user = User.find(user_id)
      @user_cache[user.id] = user if user
    end
    return user
  end
  def find_users(user_ids)
    return [] if user_ids.blank?
    @user_cache ||= {}
    missing_user_ids = user_ids.select {|v| !@user_cache.include?(v)}
    if !missing_user_ids.empty?
      missing_users = User.find(missing_user_ids).compact
      missing_users.each {|user| @user_cache[user.id] = user}
    end
    return user_ids.collect {|id| @user_cache[id]}
  end

  def find_meet(meet_id)
    return nil if meet_id.blank?
    @meet_cache ||= {}
    meet = @meet_cache[meet_id]
    if !meet
      meet = User.find(meet_id)
      @meet_cache[meet.id] = meet if meet
    end
    return meet
  end
  def find_meets(meet_ids)
    return [] if meet_ids.blank?
    @meet_cache ||= {}
    missing_meet_ids = meet_ids.select {|v| !@meet_cache.include?(v)}
    if !missing_meet_ids.empty?
      missing_meets = User.find(missing_meet_ids).compact
      missing_meets.each {|meet| @meet_cache[meet.id] = meet}
    end
    return meet_ids.collect {|id| @meet_cache[id]}
  end

  def find_mpost(mpost_id)
    return nil if mpost_id.blank?
    @mpost_cache ||= {}
    mpost = @mpost_cache[mpost_id]
    if !mpost
      mpost = User.find(mpost_id)
      @mpost_cache[mpost.id] = mpost if mpost
    end
    return mpost
  end
  def find_mposts(mpost_ids)
    return [] if mpost_ids.blank?
    @mpost_cache ||= {}
    missing_mpost_ids = mpost_ids.select {|v| !@mpost_cache.include?(v)}
    if !missing_mpost_ids.empty?
      missing_mposts = User.find(missing_mpost_ids).compact
      missing_mposts.each {|mpost| @mpost_cache[mpost.id] = mpost}
    end
    return mpost_ids.collect {|id| @mpost_cache[id]}
  end

  def find_chatter(chatter_id)
    return nil if chatter_id.blank?
    @chatter_cache ||= {}
    chatter = @chatter_cache[chatter_id]
    if !chatter
      chatter = User.find(chatter_id)
      @chatter_cache[chatter.id] = chatter if chatter
    end
    return chatter
  end
  def find_chatters(chatter_ids)
    return [] if chatter_ids.blank?
    @chatter_cache ||= {}
    missing_chatter_ids = chatter_ids.select {|v| !@chatter_cache.include?(v)}
    if !missing_chatter_ids.empty?
      missing_chatters = User.find(missing_chatter_ids).compact
      missing_chatters.each {|chatter| @chatter_cache[chatter.id] = chatter}
    end
    return chatter_ids.collect {|id| @chatter_cache[id]}
  end

  private

    def render_error(file, status, options={})
      except, only, raise_exception = options[:except], options[:only], options[:raise]
      except = [except] if (except && !except.is_a?(Array))
      only = [only] if (only && !only.is_a?(Array))
      is_html = (!except || !except.include?(:html)) &&
                (!only   || only.include?(:html))
      is_json = (!except || !except.include?(:json)) &&
                (!only   || only.include?(:json))
      format = params[:format] || request.format
      format = format.to_s
      format = format.slice((format.rindex('/')||-1)+1..-1);
      if raise_exception.present?
        raise raise_exception if (is_html && format == "html")
        raise raise_exception if (is_json && format == "json")
      else
        respond_to do |format|
          #format.html { render :file=>file, :status=>status; raise AssertException } if is_html
          format.html { redirect_to file } if is_html
          format.json { head status } if is_json
        end
      end
    end

    def attach_meet_mview(user, meet)
      meet.meet_mview = Mview.user_meet_mview(user, meet).first
      meet.hoster_mview = Mview.user_meet_mview(meet.hoster, meet).first if meet.has_hoster?
      #meet.meet_invitations = user.pending_invitations.where("meets.id = ?", meet.id).to_a
    end

end

class ContentAPI
  attr_accessor :type, :timestamp, :id, :body
# include ActiveModel::Serialization
# attr_accessor :attributes
# def initialize(attributes)
#   @attributes = attributes
# end
  def initialize(type)
    self.type = type
  end
  def as_json(options={})
    options ||= {}
    org_flag = ActiveRecord::Base.include_root_in_json
    ActiveRecord::Base.include_root_in_json = false
    res = {:type=>type, :timestamp=>timestamp, :id=>id}
    body.each_pair {|k, v|
      if v.class == Meet && k == :encounter_summary
        options0 = options.merge(MeetsController::JSON_MEET_LIST_API)
      elsif v.class == Meet && k == :encounter
        options0 = options.merge(MeetsController::JSON_MEET_MARKED_API)
      elsif v.class == Meet && k == :cirkle
        options0 = options.merge(MeetsController::JSON_MEET_CIRKLE_API)
      elsif v.class == Chatter && k == :photo
        options0 = options.merge(ChattersController::JSON_CHATTER_LIST_API)
      elsif v.class == Chatter && k == :topic
        options0 = options.merge(ChattersController::JSON_CHATTER_MARKED_API)
      elsif v.class == User
        options0 = options.merge(UsersController::JSON_USER_LIST_API)
      elsif v.class == Meet && k == :pending_invitation
        options0 = options.merge(MeetsController::JSON_PENDING_MEET_LIST_API)
      elsif v.class == Meet && k == :invitation
        options0 = options.merge(MeetsController::JSON_MEET_LIST_API)
      elsif v.class == Mpost
        options0 = options.merge(MpostController::JSON_MPOST_DETAIL_API)
      end
      res[k] = v.as_json(options0)
    }
    ActiveRecord::Base.include_root_in_json = org_flag
    return res
  end
  def to_json(options={})
    return as_json(options).to_json
  end
end
