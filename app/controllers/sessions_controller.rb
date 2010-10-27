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
      render 'new'
    else
      sign_in user
      redirect_back_or user
    end
  end
  
  def destroy
    sign_out
    redirect_to root_path
  end
end
