class InvitationsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :authorized_user, :only => :destroy
  
  def create
    meet = Meet.find(params[:meet_id])
    # Handle meet.nil?

    # Verify that the user is a participant of the meet

    # Create invitation
    if (params[:chatter].nil?)
      #p params
      @invitation = meet.invitations.build(params)
    else
      @invitation = meet.invitations.build(params[:invitation])
    end

    # Handle @invitation.nil

    #p @invitation
    # Set user id
    @invitation.user_id = current_user.id
    if @invitation.save
      # Send emails
      #
      @user = User.find(current_user.id)
      InvitationMailer.signup_invitation(@user, @invitation.invitee)

      respond_to do |format|
        format.html {
          redirect_to root_path, :flash => { :success => "Invitation sent!" }
        }
        format.json {
          render :json => @invitation.to_json
        }
      end
    else
      @feed_items = []
      render 'pages/home'
    end
  end

  def show
    @invitation = Invitation.find(params[:id])
    respond_to do |format|
      format.html {
        render @invitation
        @title = "meet invitations"
      }
      format.json {
        render :json => @invitation.to_json
      }
    end
  end

  def destroy
    @invitation.destroy
    redirect_to root_path, :flash => { :success => "invitation deleted!" }
  end
  
  private
  
    def authorized_user
      @invitation = Invitation.find(params[:id])
      redirect_to root_path unless (current_user.id == @invitation.user_id)
    end
end
