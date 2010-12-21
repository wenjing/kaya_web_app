module SessionsHelper
  
  def sign_in(user)
    cookies.permanent.signed[:remember_token] = [user.id, user.salt]
    current_user = user
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
  
  def sign_out
    cookies.delete(:remember_token)
    current_user = nil
  end

  def current_user?(user)
    user == current_user
  end

  def current_user_id?(user_id)
    user_id == current_user.id
  end

  def admin_user?
    current_user && current_user.admin
  end
  
  def authenticate
    deny_access unless signed_in? || basic_authenticate
  end

  def basic_authenticate
    authenticate_or_request_with_http_basic do |username, password|
      user = User.authenticate(username, password)
      if !user.nil?
        sign_in(user)
      end
    end
  end

  def deny_auth
    render :status => :unauthorized
  end

  def deny_access
    store_location
    redirect_to signin_path, :notice => "Please sign in to access this page."
  end
  
  def store_location
    session[:return_to] = request.fullpath
  end
  
  def redirect_back_or(default)
    redirect_to(session[:return_to] || default)
    clear_return_to
  end
  
  def clear_return_to
    session[:return_to] = nil
  end

  private
  
    def user_from_remember_token
      User.authenticate_with_salt(*remember_token)
    end
    
    def remember_token
      cookies.signed[:remember_token] || [nil, nil]
    end
end

