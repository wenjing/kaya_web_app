class SessionsController < ApplicationController
  skip_before_filter :verify_authenticity_token

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
      flash.now[:error] = "Invalid email/password combination."
      @title = "Sign in"
      respond_to do |format|
        format.html { render 'new' }
        format.json { render :json => new.to_json }
      end
    else
      sign_in user

      respond_to do |format|
        format.html { redirect_back_or user }
        format.json { render :json => user.to_json(
          :methods => :user_avatar,
          :except => [:admin,:created_at,:encrypted_password,:salt,:updated_at]) }
      end
    end
  end
  
  def destroy
    sign_out
    redirect_to root_path
  end
end
