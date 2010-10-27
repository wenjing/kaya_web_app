
class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate

  def create
    @mpost = current_user.mposts.build(params)
    if @mpost.save
      redirect_to root_path, :flash => { :success => "Mpost created!" }
    else
      @feed_items = []
      render 'pages/home'
    end
  end

  def destroy
  end

end

