module SessionsHelper
  
  def sign_in(user, create_session=true)
    if !current_user?(user)
      sign_out
      cookies.permanent.signed[:remember_token] = [user.id, user.salt] if create_session
      self.current_user = user
    end
  end
  def sign_out(clear_rp=true)
    cookies.delete(:remember_token)
    # redirect_back is invalid once user signed out
    clear_return_point
    self.current_user = nil
  end

  def re_sign_in(user)
    sign_out(false)
    sign_in(user)
  end
  
  def current_user=(user)
    @current_user = user
  end
  
  def current_user
    @current_user ||= user_from_remember_token
  end
  
  def signed_in?
    !current_user.nil?
  end
  
  def current_user?(user)
    user && current_user && user.id == current_user.id
  end

  def current_user_id?(user_id)
    user_id == current_user.id
  end

  def admin_user?
    current_user && current_user.admin
  end
  
  def authenticate
    deny_access unless signed_in? || basic_authenticate || temp_authenticate
    pending_access(current_user) if (current_user && current_user.pending?)
  end
  def authenticate_pending_ok
    # More temp_auth to the first, it overwrites all other form of authentications
    deny_access unless temp_authenticate || signed_in? || basic_authenticate || temp_authenticate
  end

  def basic_authenticate
    # hong.zhao, Shall not request for http_basic. Otherwise browser will keep user
    # signed in even she signed out.
    authenticate_with_http_basic do |username, password|
      user = User.authenticate(username, password)
      sign_in(user) if !user.nil?
    end
  end

  # Pass username and temporary password on url. Used for pending user email confirmation.
  def temp_authenticate
    user_id, user_passcode = params[:id], params[:pcd]
    user = find_user(user_id)
    if (!user.nil? && user.pending? && !current_user?(user))
      user = User.authenticate(user.email, user_passcode)
      sign_in(user) if !user.nil?
    end
  end
  # 10 digit random number
  def passcode
     Array.new(6) {("0".."9").to_a.sample}.join
  end
  def pending_user_url(user)
    if (user.pending? && user.temp_password)
      return edit_user_url(user.id)+"?pcd=#{user.temp_password}"
    else
      return user_url(user.id)
    end
  end
  def pending_user_path(user)
    if (user.pending? && user.temp_password)
      return edit_user_path(user.id)+"?pcd=#{user.temp_password}"
    else
      return user_path(user.id)
    end
  end

  def deny_auth
    render :status => :unauthorized
  end

  def deny_access
    respond_to do |format|
      format.html {
        redirect_away signin_url, :notice => "Please sign in to access this page."
      }
      format.json { head :unauthorized }
    end
  end

  def pending_access(user)
    respond_to do |format|
      format.html {
        redirect_to edit_user_url(user.id), :notice => "Please complete your profile first."
      }
      format.json { head :unauthorized }
    end
  end
  
  private
  
    def user_from_remember_token
      User.authenticate_with_salt(*remember_token)
    end
    
    def remember_token
      cookies.signed[:remember_token] || [nil, nil]
    end
end
