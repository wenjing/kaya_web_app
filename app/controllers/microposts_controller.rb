class MicropostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :authorized_user, :only => :destroy
  
  def create
    if (params[:micropost].nil?)
      @micropost = current_user.microposts.build(params)
    else
      @micropost = current_user.microposts.build(params[:micropost])
    end
    if @micropost.save
      redirect_to root_path, :flash => { :success => "Micropost created!" }
    else
      @feed_items = []
      render 'pages/home'
    end
  end

  def destroy
    @micropost.destroy
    redirect_to root_path, :flash => { :success => "Micropost deleted!" }
  end
  
  private
  
    def authorized_user
      @micropost = Micropost.find(params[:id])
      redirect_to root_path unless current_user?(@micropost.user)
    end
end