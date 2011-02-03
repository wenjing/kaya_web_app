class PagesController < ApplicationController
  respond_to :html
  respond_to :js, :only => :home_info

  def home
    redirect_to user_url(current_user) if signed_in?
    @title = "Home"
    #@users_count = User.count
    @meets_count = Meet.count
    #@meets = Meet.limit(10)
  end

  def contact
    @title = "Contact"
  end
  
  def about
    @title = "About"
  end
  
  def help
    @title = "Help"
  end
end
