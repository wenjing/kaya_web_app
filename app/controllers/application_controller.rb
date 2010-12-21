class ApplicationController < ActionController::Base
  protect_from_forgery
  include SessionsHelper

  # current_user must be this user
  def correct_user(id=nil)
    @user = User.find_by_id(id||params[:id])
    if !current_user?(@user)
      render_unauthorized
    end
  end

  # current_user must be this user or current_user must be a admin
  def admin_user(id=nil)
    @user = User.find_by_id(id||params[:id])
    if (current_user?(@user) || !admin_user?)
      # user can not delete itself even she is an admin
      render_unauthorized
    end
  end

  # current_user must be part of this meet
  def authorized_meet_member(id=nil)
    @meet = Meet.find_by_id(id||params[:id])
    if (!@meet || (!@meet.has_user?(current_user) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be own this mpost
  def authorized_mpost_owner(id=nil)
    @mpost = Mpost.find_by_id(id||params[:id])
    if (!@mpost || (!current_user_id?(@mpost.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be own this chatter
  def authorized_chatter_owner(id=nil)
    @chatter = Chatter.find_by_id(id||params[:id])
    if (!@chatter || (!current_user_id?(@chatter.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be part of chatter's meet
  def authorized_chatter_meet_member(id=nil)
    @chatter = Chatter.find_by_id(id||params[:id])
    if (!@chatter || !authorized_meet_member(@chatter.meet_id))
      render_unauthorized
    end
  end

  # current_user must be part of micropost's meet
  def authorized_micropost_owner(id=nil)
    @micropost = Chatter.find_by_id(id||params[:id])
    if (!@micropost || (!current_user_id?(@micropost.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # current_user must be own this invitation
  def authorized_invitation_owner(id=nil)
    @invitation = Invitation.find_by_id(id||params[:id])
    if (!@invitation || (!current_user_id?(@invitation.user_id) && !admin_user?))
      render_unauthorized
    end
  end

  # Standard error handling routes
  def render_invalid(options={}) # 404
    render_error('public/404.html', 404, options)
  end
  def render_unauthorized(options={}) # 422
    render_error('public/422.html', 422, options)
  end
  def render_internal_error(options={}) # 500
    render_error('public/500.html', 500, options)
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
        format.html { render :file=>file, :status=>status } if is_html
        format.json { head status } if is_json
      end
    end

end
