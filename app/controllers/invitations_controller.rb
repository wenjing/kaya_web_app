class InvitationsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :only => :create do |controller|
    controller.authorized_meet_member(params[:meet_id])
  end
  before_filter :authorized_invitation_owner, :only => [:show, :destroy]
  
  def new
    @user  = User.new
    @title = "invite friends"
  end

  def create
    # It is handled by authorized_meet_member
    #@meet = Meet.find_by_id(params[:meet_id])

    # Create invitation
    if (params[:invitation].nil?)
      #p params
      @invitation = @meet.invitations.build(params)
    else
      @invitation = @meet.invitations.build(params[:invitation])
    end
    assert_internal_error(@invitation) # is this necessaary?

    #p @invitation
    # Set user id
    @invitation.user_id = current_user.id
    if @invitation.save
      # Send emails
      #@user = User.find_by_id(current_user.id) # this is current_user areadly
      # ZZZ hong.zhao, shall create pending users from invitee and add them to this meet
      InvitationMailer.signup_invitation(current_user, @invitation.invitee).deliver

      respond_to do |format|
        format.html {
          redirect_to root_path, :flash => { :success => "Invitation sent!" }
        }
        format.json {
          render :json => @invitation.to_json
        }
      end
    else
      @title = "Sign up"
      respond_to do |format|
        format.html { render 'new' }
        format.json { render :json => @invitation.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

  def show
    #@invitation = Invitation.find_by_id(params[:id])
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
  
end
