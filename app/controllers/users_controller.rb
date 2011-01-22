class UsersController < ApplicationController
  before_filter :store_return_point, :only => [:show, :pending_meets, :friends, :meets]
  skip_before_filter :verify_authenticity_token
  before_filter :only => [:create, :update] do |controller|
    controller.filter_params(:user, :strip => [:email])
  end
  before_filter :authenticate, :except => [:new, :create, :update]
  before_filter :authenticate_pending_ok, :only => [:update]
  before_filter :only => [:create] do |controller|
    signed_in? || basic_authenticate
  end
  before_filter :correct_user, :only => [:show, :edit, :update, :pending_meets, :confirm_meets,
                                         :friends, :map]
  before_filter :admin_current_user,     :only => [:index]
  before_filter :admin_user_except_self, :only => [:destroy]
  
  JSON_USER_DETAIL_API = { :except => [:created_at, :admin, :lock_version,
                                       :salt, :encrypted_password, :temp_password,
                                       :photo_content_type, :photo_file_name,
                                       :photo_file_size, :photo_updated_at],
                           :methods => [:user_avatar] }
  JSON_USER_LIST_API = JSON_USER_DETAIL_API

  def index
    assert_unauthorized(false, :except=>:html)
    respond_to do |format|
      format.html {
        @users = User.paginate(:page => params[:page], :per_page => 25)
        @title = "All users"
      }
    end
  end
 
  # User home when user signed in.
  # Display aggregate user info, recent meets, related chatter, friends and maybe a small map
  def show
    # Do not use costly eager load to get all meets/chatters/friends. We only need
    # to get a top listed few.
    assert_internal_error(@user)
    respond_to do |format|
      format.html {
        #@meets = @user.top_meets(15) # Get a bit more to make sure we have enough top friends
        #@friends = @user.top_friends(@meets, 15)
        #@chatters = @user.top_chatters(10)
        #@meets = @meets.slice(0..4)
        #attach_meet_infos(current_user, @meets)
        @title = @user.name_or_email
        redirect_to meets_user_path(@user)
      }
      format.json { # Only return user profile
        render :json => @user.to_json(JSON_USER_DETAIL_API)
      }
    end
  end

  # Pending meet list view
  def pending_meets 
    assert_internal_error(@user)
    @pending_meets = @user.true_pending_meets
    respond_to do |format|
      format.html {
        # redirect back to user meets view if no more pending meets
        if @pending_meets.empty?
          redirect_back user_meets_path(@user)
        else
          @pending_meets = @pending_meets.paginate(:page => params[:page], :per_page => 25)
          attach_meet_infos(current_user, @pending_meets, true)
        end
      }
      format.json {
        cursor = params[:cursor] || params
        @pending_meets = @pending_meets.cursorize(cursor,
                                  :only=>[:time, :created_at, :updated_at, :lat, :lng])
        attach_meet_infos(current_user, @pending_meets)
        @pending_meets.each {|meet|
          meet.friends_name_list_params = {:except=>current_user,:delimiter=>", ",:max_length=>80}
        }
        render :json => @pending_meets.to_json(MeetsController::JSON_PENDING_MEET_LIST_API)
      }
    end
  end

  # Meet list view
  def meets
    @user = User.find_by_id(params[:id])
    assert_unauthorized(@user)
    meet_type = params[:meet_type] ? params[:meet_type].to_i : nil
    @meets = @user.meets_with(admin_user? ? @user : current_user, meet_type)
    respond_to do |format|
      format.html {
        @pending_meet_count = @user.true_pending_meets.count
        @meets = @meets.paginate(:page => params[:page], :per_page => 25)
        attach_meet_infos(current_user, @meets)
        @title = @user.name_or_email
      }
      format.json {
        cursor = params[:cursor] || params
        @meets = @meets.cursorize(cursor, :only=>[:time, :created_at, :updated_at, :lat, :lng])
        attach_meet_infos(current_user, @meets)
        # This params staff is the workaround for to_json because :methods can not specify parameters. 
        # We can not hardcode :except (which is used to prevent display user herself in the list).
        @meets.each {|meet|
          meet.friends_name_list_params = {:except=>current_user,:delimiter=>", ",:max_length=>80}
        }
        render :json => @meets.to_json(MeetsController::JSON_MEET_LIST_API)
      }
    end
  end

  # Friends list view
  def friends
    # Beside cursor, also support sorting.
    # Support following sorting methods:
    #  1) By time, recent met first
    #  2) By relation, most common meets first
    # Here, not only eager load all meets but also all users under each meet
    # Includes with duplicated through relation is buggy. Event with uniq specified, it returns
    # duplicated meets, users list
    #@user = User.includes(:meets).find_by_id(params[:id])
    assert_internal_error(@user)
    cursor = params[:cursor] || params
    sort_by = cursor[:sort_by] || params[:sort_by]
    # meet_friends returns a hash user=>[meets]
    # After sort, it becomes array [user, [meets]]
    if sort_by == "relation"
      @friends = @user.meets_friends.sort {|x, y|
        tt = -(x[1].size <=> y[1].size) # compare relation first, DESC order
        # then base on name
        tt = (x[0].name_or_email <=> y[0].name_or_email) if tt == 0
        tt
      }
    else # sort by meet time, this is default
      @friends = @user.meets_friends.sort {|x, y|
        tt = -(x[1][0].time <=> y[1][0].time) # compare time first, DESC order
        # then base on name
        tt = (x[0].name_or_email <=> y[0].name_or_email) if tt == 0
        tt
      }
    end
    respond_to do |format|
      format.html {
        @friends = @friends.paginate(:page => params[:page], :per_page => 25)
        @title = @user.name_or_email
      }
      format.json {
        @friends = @friends.cursorize(cursor)
        @friends = @friends.collect {|v| [v[0], v[1][0].time, v[1].size]}
        render :json => friends.to_json(JSON_USER_LIST_API)
      }
    end
  end

  # Chatters flat view
# def comments
#   assert_internal_error(@user)
#   assert_unauthorized(false, :except=>:html)
#   @chatters = @user.meets_chatters
#   respond_to do |format|
#     format.html {
#       @chatters = @chatters.paginate(:page => params[:page], :per_page => 25)
#       @title = @user.name_or_email
#     }
#     # JSON interface shall not come here
#     # Get all chatters is too costly, use meet detail instead.
#   end
# end

  def map
    assert_internal_error(@user)
    assert_unauthorized(false, :except=>:html)
    upto = params[:uptx] ? params[:uptx].to_i : 500
    respond_to do |format|
      format.html {
        meet_type = params[:meet_type] ? params[:meet_type].to_i : nil
        @meets = @user.top_meets(upto, meet_type)
        attach_meet_infos(current_user, @meets)
        center_meet = @meets[0]
        @center_ll = center_meet.lat_lng if center_meet
        @center_ll = "37.387722,-121.966733" if @center_ll.blank?
        @title = @user.name_or_email
        # Calculate next upto, keep as-is if already exceed limit
        @more_upto = upto
        @more_upto += 500 if upto < @user.meets.count
      }
      # JSON interface shall use meets instead
    end
  end

# def following
#   @title = "Following"
#   @user = User.find_by_id(params[:id])
#   assert_unauthorized(@user)
#   @users = @user.following.paginate(:page => params[:page], :per_page => 25)
#   render 'show_follow'
# end
  
# def followers
#   @title = "Followers"
#   @user = User.find_by_id(params[:id])
#   assert_unauthorized(@user)
#   @users = @user.followers.paginate(:page => params[:page], :per_page => 25)
#   render 'show_follow'
# end

  def new
    @user  = User.new
    @title = "Sign up"
  end
  
  def create
    confirm_signup = !admin_user?
    @filtered_params = {:email => @filtered_params[:email]} if confirm_signup
    @user = User.new(@filtered_params)
    pending_user = User.find_by_email(@user.email.strip.downcase)
    if (pending_user)
      if (pending_user.status == 2 || pending_user.status == 3)
        # If the user is already invitation or signup pending and now she try to signup
        # directly again, we shall let her go through without trigger email already
        # taken error.
        @user = pending_user
      elsif (pending_user.status == 1)
        # Free up the record of a deleted user if someone try to signup using it.
        pending_user.destroy
      end
    end
    saved = false
    @user.opt_lock_protected {
      if (confirm_signup)
        @user.temp_password = passcode if @user.temp_password.blank?
        @user.status = 2 # signup pending
        saved = @user.exclusive_save
      else # an admin user can signup an user without confirmation
        @user.status = 0 # sign it up
        saved = @user.save
      end
    }
    if saved
      #sign_in @user
      if confirm_signup
        InvitationMailer.signup_confirmation(root_url, pending_user_url(@user), @user).deliver
      end
      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Check your email for confirmation!" } }
        format.json { render :json => @user.to_json(JSON_USER_DETAIL_API) }
      end
    else
      @title = "Sign up"
      respond_to do |format|
        format.html { render 'new' }
        format.json { render :json => @user.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end
  
  def edit
    @title = "Edit user"
  end
  
  def update
    saved = false
    @user.opt_lock_protected {
      @user.status = 0
      @user.temp_password = nil # temp password is only one time use
      saved = @user.update_attributes(@filtered_params)
    }
    if saved
      respond_to do |format|
        format.html { redirect_back @user, :flash => { :success => "Profile updated!" } }
        format.json { render :json => @user.to_json(JSON_USER_DETAIL_API) }
      end
    else 
      respond_to do |format|
        format.html { @title = "Edit user"; render 'edit' }
        format.json { render :json => @user.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    assert_internal_error(@user)
    assert_unauthorized(false, :except=>:html)
    delete_user_associates
    @user.opt_lock_protected {
      @user.delete
      @user.exclusive_save
    }
    redirect_to users_path, :flash => { :success => "User removed!" }
  end

  def perm_destroy
    assert_internal_error(@user)
    assert_unauthorized(false, :except=>:html)
    @user.destroy
    redirect_to users_path, :flash => { :success => "User removed!" }
  end

  private

    def attach_meet_infos(user, meets, invitation=false)
      attach_meet_mviews(user, meets)
      attach_meet_top_users(meets)
      attach_meet_top_chatters(meets)
      attach_meet_invitations(user, meets) if (invitation)
    end

    def attach_meet_mviews(user, meets)
      mviews = Mview.user_meets_mview(user, meets).to_a
      meets.each {|meet|
        meet.meet_mview = mviews.select {|mview| mview.meet_id == meet.id}.first
        meet.hoster_mview = Mview.user_meet_mview(meet_hoster, meet).first if meet.has_hoster?
      }
    end

    def attach_meet_top_users(meets)
      user_ids = Set.new
      meets.each {|meet| user_ids.merge(meet.top_user_ids)}
      users = User.find(user_ids.to_a).compact
      meets.each {|meet|
        meet.loaded_top_users =
          meet.top_user_ids.collect {|id| users.drop_while {|us| us.id != id}.first}.compact
      }
    end

    def attach_meet_top_chatters(meets)
      chatter_ids = Set.new
      meets.each {|meet|
        chatter_ids.merge(meet.top_topic_ids)
      }
      chatters = Chatter.find(chatter_ids.to_a).compact
      meets.each {|meet|
        meet.loaded_top_chatters =
          meet.top_topic_ids.collect {|id| chatters.drop_while {|ch| ch.id != id}.first}.compact
      }
    end

    def attach_meet_invitations(user, meets)
      pending_invitations = user.pending_invitations.to_a
      meets.each {|meet|
        # invitations are sorted by created_at time. Hope it still keep the timed
        # order after the select procedure, so the first is the latest one,
        # so the first is the latest one.
        meet.meet_invitations = pending_invitations.select {|invitation|
          invitation.meet_id == meet.id
        }
      }
    end

    def delete_user_associates
      delete_mposts(@user.mposts)
      #delete_mviews(@user.mviews)
      delete_chatters(@user.chatters)
      delete_invitations(@user.invitations)
    end

end
