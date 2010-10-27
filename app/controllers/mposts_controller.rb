
class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate

  def create
    @mpost = current_user.mposts.build(params)
    if @mpost.save
      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Mpost created!" } }
        format.json { render :json => @mpost.to_json(:except => [:updated_at, :encrypted_password, :salt]) }
      end
    else
      @feed_items = []
      render 'pages/home'
    end
  end

  def destroy
  end

end

