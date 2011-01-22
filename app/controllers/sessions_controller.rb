class SessionsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:create, :create_reset] do |controller|
    controller.filter_params(:session, :strip => [:email])
  end

  JSON_USER_SESSION_API = { :except => [:created_at, :admin, :lock_version,
                                        :salt, :encrypted_password,
                                        :photo_content_type, :photo_file_name,
                                        :photo_file_size, :photo_updated_at],
                            :methods => [:user_avatar] }

  def new_reset
    @title = "Password reset"
  end

  def create_reset
    user_email = @filtered_params[:email]
    user_email.downcase! if user_email.present?
    user = User.find_by_email(user_email)
    if user.nil?
      flash.now[:error] = "Invalid email!"
      @title = "Password reset"
      respond_to do |format|
        format.html { render 'new_reset' }
        format.json { head :unprocessable_entity }
      end
    else
      user.temp_password = passcode if user.temp_password.blank?
      user.status = 4 # password reset
      saved = false
      user.opt_lock_protected {
        saved = user.exclusive_save
      }
      if saved
        InvitationMailer.password_reset(root_url, pending_user_url(user), user).deliver
        respond_to do |format|
          format.html {
            redirecto_to signin_path, :flash => {:success => "Check your email for temporary password!"}
          } 
          format.json { head :ok }
        end
      else
        @title = "Password reset"
        respond_to do |format|
          format.html { render 'new_reset' }
          format.json { render :json => user.errors.to_json, :status => :unprocessable_entity }
        end
      end
    end
  end

  def new
    @title = "Sign in"
  end
  
  def create
    user_email = @filtered_params[:email]
    user_email.downcase! if user_email.present?
    user = User.authenticate(user_email, @filtered_params[:password])
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
