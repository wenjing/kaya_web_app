class SessionsController < ApplicationController
  skip_before_filter :verify_authenticity_token

  JSON_USER_SESSION_API = { :except => [:created_at, :admin, :lock_version,
                                        :salt, :encrypted_password,
                                        : photo_content_type, :photo_file_name,
                                        :photo_file_size, :photo_updated_at],
                            :methods => [:user_avatar] }

  def new_reset
    @title = "Password reset"
  end

  def create_reset
    if params[:session].nil?
      user_email = params[:email]
    else
      user_email = params[:session][:email]
    end
    user_email.strip!.downcase! if user_email.present?
    user = User.find_by_email(user_email)
    if user.nil?
      flash.now[:error] = "Invalid email!"
      @title = "Password reset"
      respond_to do |format|
        format.html { render 'new_reset' }
        format.json { header :unprocessable_entity }
      end
    else
      user.temp_password = passcode
      user.status = 4 # password reset
      respond_to do |format|
        format.html {
          redirecto_to signin_path, :flash => {:success => "Check your email for temporary password!"}
        } 
        format.json { header :ok }
      end
    end
  end

  def new
    @title = "Sign in"
  end
  
  def create
    if params[:session].nil?
      user = User.authenticate(params[:email], params[:password])
    else
      user = User.authenticate(params[:session][:email],
                               params[:session][:password])
    end
    if user.nil?
      flash.now[:error] = "Invalid email/password combination"
      @title = "Sign in"
      respond_to do |format|
        format.html { render 'new' }
        format.json { head :unprocessable_entity }
      end
    else
      sign_in user
      respond_to do |format|
        format.html { redirect_back user }
        format.json { render :json => user.to_json(UsersController::JSON_USER_DETAIL_API) }
      end
    end
  end

  def destroy
    sign_out
    redirect_to root_path
  end
end
