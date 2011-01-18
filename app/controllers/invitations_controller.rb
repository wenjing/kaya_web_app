class InvitationsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:update] do |controller|
    controller.filter_params(:invitation, :strip => [:invitee, :message])
  end
  before_filter :authenticate
  before_filter :only => [:new, :create] do |controller|
    controller.correct_user(params[:user_id]) if params[:user_id]
    controller.authorized_meet_member(params[:meet_id]) if params[:meet_id]
  end
  before_filter :authorized_invitation_owner, :only => [:show, :destroy]
  
  def new
    @user ||= current_user
    @invitation = Invitation.new
    @title = @meet ? "Add friends to meet" : "Invite friends"
  end

  def create
    @user ||= current_user
    if params[:discard]
      respond_to do |format|
        format.html { redirect_back @meet || @user }
        format.json { head :ok }
      end
      return
    end

    @invitation = Invitation.new(@filterd_params)
    assert_internal_error(@invitation)
    @user.invitations << @invitation 
    @meet.invitations << @invitation if @meet

    if @invitation.save
      # Send emails
      invitees = Set.new
      @invitation.invitee.split(/[, \t\r\n]+/).each {|invitee_email|
        invitee_email.strip!.downcase!
        invitee = User.find_by_email(invitee_email)
        if invitee.present? # already exists
          # Ignore general (non-meet related) invitation to existing user
          # And, obviously, can not send invitation to self.
          invitees << invitee unless (@meet && invitee.id != @user.id)
        else # create a new pending user
          invitee = User.build(:email=>invitee_email)
          invitee.temp_password = passcode
          invitee.status = 3 # invitation pending
          if invitee.exclusive_save
            invitees << invitee
          else # likely due to invalid email format,
            # ZZZ, hong.zhao, shall kindly notify sender about the error
            # Or, maybe it someone took the email address just before the save
          end
        end
      }
      if @meet # add users to this meet
        invitees.each {|invitee|
          # Ignore meet invitation to user who is already in the meet???
          # However, only skip procedure adding this user to meet but still
          # send out invitation.
          next if @meet.include_user?(invitee)
          # This is a bit tricky. Since meet and user are related through mpost.
          # Have to create a mpost first.
          mpost = invitee.mposts.build(:time=>@meet.time, :user_dev=>user.dev, :devs=>"",
                                       :lng=>@meet.lng, :lat=>@meet.lat, :lerror=>@meet.lerror)
          mpost.status = 2 # invitation pending
          @meet.mposts << mpost
          @invitation.pending_mposts << mpost
          if mpost.save
            mview = Mview.user_meet_mview(invitee, @meet).first
            mview ||= Mview.new
            # Share user's meet view with invitee
            mview.clone_from(@meet.meet_mview) if @meet.meet_mview
            mview.inviter = @user # remember who is the inviter
            invitee.mviews << mview
            @meet.mviews << mview
            mview.save # never bother check success or not
                       # may fail if someone else already added this invitee to the meet
          else # rare, could be internal error
            ####
          end
        }
      end

      invitees.each {|invitee|
        if invitee.pending?
          InvitationMailer.signup_invitation(@user, invitee,
                                             @invitation.message, @meet).deliver
        elsif @meet
          InvitationMailer.meet_invitation(@user, invitee,
                                           @invitation.message, @meet).deliver
        end
      }

      respond_to do |format|
        format.html {
          if params[:send_more]
              @invitation = Invitation.new
              @title = @meet ? "Add friends" : "Invite friends"
            render 'new'
          elsif @meet
            redirect_back @meet, :flash => { :success => "Notified added friends!" }
          else
            redirect_back @user, :flash => { :success => "Invitation sent!" }
          end
        }
        format.json {
          render :json => @invitation.to_json
        }
      end
    else
      respond_to do |format|
        format.html { render 'new' }
        format.json { render :json => @invitation.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

# def show
#   respond_to do |format|
#     format.html {
#       render @invitation
#       @title = @invitation.meet_id ? "Meet invitation" : "Friends invitation"
#     }
#     format.json {
#       render :json => @invitation.to_json
#     }
#   end
# end
#
# def destroy
#   current_user.invitations.destroy(@invitation)
#   @invitation.destroy
#   redirect_back root_path, :flash => { :success => "invitation deleted!" }
# end
  
end
