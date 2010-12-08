class ChattersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :authorized_user, :only => :destroy
  
  def create
    meet = Meet.find(params[:meet_id])
    # Handle meet.nil?

    # Verify that the user is a participant of the meet

    if (params[:chatter].nil?)
      #p params
      #@chatter = Chatter.new(params)
      #meet.chatters << @chatter
      @chatter = meet.chatters.build(params)
    else
      @chatter = meet.chatters.build(params[:micropost])
    end

    # Handle @chatter.nil

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
      render 'pages/home'
    end
  end

  def show
    @chatter = Chatter.find(params[:id])
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
  
  private
  
    def authorized_user
      @chatter = Chatter.find(params[:id])
      redirect_to root_path unless (current_user.id == @chatter.user_id)
    end
end
