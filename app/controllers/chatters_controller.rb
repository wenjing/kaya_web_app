class ChattersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :authorized_chatter_owner, :only => :destroy
  before_filter :only => :create do |controller|
    controller.authorized_meet_member(params[:meet_id])
  end
  #before_filter :authroized_chatter_meet_owner, :only => :show

  def create
    if (params[:chatter].nil?)
      #p params
      #@chatter = Chatter.new(params)
      #meet.chatters << @chatter
      @chatter = @meet.chatters.build(params)
    else
      @chatter = @meet.chatters.build(params[:chatter])
    end

    #p @chatter
    @chatter.user_id = current_user.id
    if @chatter.save
      respond_to do |format|
        format.html {
          redirect_to root_path, :flash => { :success => "Chatter created!" }
        }
        format.json {
          render :json => @chatter.to_json(:methods => :chatter_photo)
        }
      end
    else
      @feed_items = []
      respond_to do |format|
        format.html { render 'pages/home' }
        format.json { render :json => @chatter.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

  def show
    @chatter = Chatter.find_by_id(params[:id])
    assert_unauthorized(@chatter)
    respond_to do |format|
      format.html {
        render @chatter
        @title = "meet chatters"
      }
      format.json {
        render :json => @chatter.to_json(:methods => :chatter_photo)
      }
    end
  end

  def destroy
    @chatter.destroy
    redirect_to root_path, :flash => { :success => "Chatter deleted!" }
  end
  
end
