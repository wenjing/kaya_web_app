class ApplicationController < ActionController::Base
  protect_from_forgery
  include SessionsHelper
  include ApplicationHelper

  # current_user must be this user
  def correct_user(id=nil)
    @user ||= User.find_by_id(id||params[:id])
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
    @user ||= User.find_by_id(id||params[:id])
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
    elsif (!@chatter.active? && !admin_user?)
      render_removed
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
  def authroized_chatter
    if params[:meet_id].present?
      authorized_meet_member(params[:meet_id])
    else
      @topic = Chatter.find_by_id(params[:chatter_id])
      if (!@topic || !@topic.topic?)
        render_unauthorized
      elsif (!@topic.active? && !admin_user?)
        render_removed
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
  rescue_from InvalidAssert do |exception| render_invalid; end
  rescue_from UnauthorizedAssert do |exception| render_unauthorized; end
  rescue_from InternalErrorAssert do |exception| render_internal_error; end
  def assert_invalid(val=true, &block)
    raise InvalidAssert if (!val || (block && !block.call))
  end
  def assert_unauthorized(val=true, &block)
    raise UnauthorizedAssert if (!val || (block && !block.call))
  end
  def assert_internal_error(val=true, &block)
    raise InternalErrorAssert if (!val || (block && !block.call))
  end

  def filter_params(:context, options = {})
    @filtered_params = params[:context].nil ? params : params[:context]
    strips = options[:strip]
    if strips.present?
      strips.each {|key|
        @filtered_params[key].strip! if @filtered_params[key].present?
      }
    end
  end
  
  def delete_mposts(user, mposts)
    return unless mposts.present?
    mposts.each {|mpost|
      #user.mposts.destroy(mpost); @meet.mposts.destroy(mpost); mpost.destroy
      mpost.delete; mpost.save
    }
  end
  def delete_mviews(user, mviews)
    return unless mviews.present?
    mviews.each {|mview|
      user.mviews.destroy(mview)
      meet.mviews.destroy(mview)
      mview.destroy
    }
  end
  def delete_invitations(user, invitations)
    return unless invitations.present?
    invitations.each {|invitation|
      user.invitations.destroy(invitation)
      meet.invitations.destroy(invitation)
      invitation.destroy
    }
  end
  def delete_chatters(user, chatters)
    update_meets = Set.new
    update_topics = Set.new
    invitations.each {|invitation|
      next if invitation.destroyed?
      topic = chatter.topic
      if topic.present?
        # Delete all current user's comments under this topic first
        chatter.comments.to_a.each {|comment|
          if comment.user_id == current_user.id
            meet.chatters.destroy(comment)
            meet.chatters.destroy(comment)
            topic.chatters.destroy(comment)
            comment.destroy
          end
        }
      end
      if (!topic || chatter.comments_count == 0)
        # Delete the chatter if it is not a topic or it is has no comments
        meet.chatters.destroy(chatter)
        update_meets << meet
        user.chatters.destroy(chatter)
        topic.comments.destroy(chatter) if topic.present?
        update_topics << topic
        chatter.destroy
      else
        # Can not delete it, otherwise it will wipe out all comments under it.
        # Orpanize it by removing ownership.
        chatter.user = nil
        chatter.save
      end
      update_meets.each {|meet|
        @meet.opt_lock_protected {
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

  private

    def render_error(file, status, options={})
      except, only = options[:except], options[:only]
      except = [except] if (except && !except.is_a?(Array))
      only = [only] if (only && !only.is_a?(Array))
      is_html = (!except || !except.include?(:html)) &&
                (!only   || only.include?(:html))
      is_json = (!except || !except.include?(:json)) &&
                (!only   || only.include?(:json))
      respond_to do |format|
        format.html { redirect_to file } if is_html
        #format.html { render :file=>file, :status=>status } if is_html
        format.json { head status } if is_json
      end
    end

    def attach_meet_mview(user, meet)
      meet.meet_mview = Mview.user_meet_mview(user, meet).first
      meet.hoster_mview = Mview.user_meet_mview(meet_hoster, meet).first if meet.has_hoster?
      #meet.meet_invitations = user.pending_invitations.where("meets.id = ?", meet.id).to_a
    end

end
