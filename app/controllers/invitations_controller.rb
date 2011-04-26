class InvitationsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:create] do |controller|
    controller.filter_params(:invitation, :strip => [:invitee, :message])
  end
  before_filter :authenticate
  before_filter :only => [:new, :create] do |controller|
    controller.correct_user(params[:user_id]) if params[:user_id]
    controller.authorized_meet_member(params[:meet_id]) if params[:meet_id]
  end
  before_filter :authorized_invitation_owner, :only => [:show, :destroy]
  
  JSON_INVITATION_DETAIL_API = { :except => [:updated_at, :invitee],
                                 :methods => [:inviter_name] }

  def new
    @user ||= current_user
    @invitation = Invitation.new
    if @meet
      @title = "Add friends to this meet"
      @friends = @meet.friends(current_user).paginate(:page => params[:friends_page], :per_page => 25)
    else
      @title = "Invite friends"
    end
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

    assert_internal_error(@user)
    @filtered_params.delete(:meet_id)
    @filtered_params.delete(:user_id)
    @invitation = @user.invitations.build(@filtered_params)
    @meet.invitations << @invitation if @meet

    if @invitation.save
      # Send emails
      invitees = Set.new
      @invitation.invitee.split(/[,; \t\r\n]+/).each {|invitee_email|
        invitee_email = invitee_email.strip.downcase
        invitee = User.find_by_email(invitee_email)
        if invitee.present? # already exists
          # Ignore general (non-meet related) invitation to existing user
          # And, obviously, can not send invitation to self.
          # However, resend invitation if user is invitation pending or she is not already 
          # included in the meet.
          if (invitee.id != @user.id &&
              (invitee.invitation_pending? ||
               (@meet && !@meet.include_user?(invitee))))
            invitees << invitee
          end
        else # create a new pending user
          invitee = User.new(:email=>invitee_email)
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
          # This is a bit tricky. Since meet and user are related through mpost.
          # Have to create a mpost first.
          mpost = invitee.mposts.build(:time=>@meet.time, :user_dev=>invitee.dev, :devs=>"invitee.dev",
                                       :lng=>@meet.lng, :lat=>@meet.lat, :lerror=>@meet.lerror)
          mpost.status = 2 # invitation pending
          @meet.mposts << mpost
          @invitation.pending_mposts << mpost
          if mpost.save
            if @meet.meet_mview
              # Share inviter's meet view with invitee
              mview = Mview.user_meet_mview(invitee, @meet).first
              mview ||= Mview.new
              mview.clone_from(@meet.meet_mview)
              invitee.mviews << mview
              @meet.mviews << mview
              mview.save # never bother check success or not
                         # may fail if someone else already added this invitee to the meet
            end
          else # rare, could be internal error
            ####
          end
        }
      end

      invitees.each {|invitee|
        if invitee.invitation_pending?
          #InvitationMailer.signup_invitation(root_url, pending_user_url(invitee), @user, invitee,
          InvitationMailer.signup_invitation(root_url, root_url, @user, invitee,
                                             @invitation.message, @meet).deliver
        elsif @meet
          #InvitationMailer.meet_invitation(root_url, pending_meets_user_url(@meet), @user, invitee,
          InvitationMailer.meet_invitation(root_url, root_url, @user, invitee,
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
#   current_user.invitations.delete(@invitation)
#   @invitation.destroy
#   redirect_back @user, :flash => { :success => "invitation deleted!" }
# end
  
end
