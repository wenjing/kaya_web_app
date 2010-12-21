class UsersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate, :except => [:show, :new, :create]
  before_filter :correct_user, :only => [:edit, :update, :meets]
  #before_filter :admin_user,   :only => [:destroy, :index]
  before_filter :admin_user,   :only => [:destroy]
  
  def index
    respond_to do |format|
      format.html {
        @users = User.paginate(:page => params[:page])
        @title = "All users"
      }
      format.json {
        @users = User.find(:all)
        render :json => 
          @users.to_json(:except => [:updated_at, :salt, :encrypted_password])
      }
    end
  end
  
  def show
    # User eager db load to prevent N+1 problem
    @user = User.includes(:microposts, :mposts).find_by_id(params[:id])
    assert_unauthorized(@user)
    respond_to do |format|
      format.html {
        @microposts = @user.microposts.paginate(:page => params[:page])
        @mposts = @user.mposts.paginate(:page => params[:page])
        @title = @user.name
      }
      format.json {
        render :json => 
          @user.to_json(:except => [:admin, 
                                    :created_at, 
                                    :updated_at, 
                                    :salt, 
                                    :encrypted_password
                                    ], 
                        :methods => :user_avatar)
      }
    end
  end

  def meets
    # Cursor feature for json is richer than paginate
    # It supports 2 types of cursors:
    #  1) Datetime based: (before_time,after_time) or (before_time,max_count) or (to_time, max_count)
    #  2) Index based: (from_index(starting from 0),to_index) or (from_idnex,max_count) or (to_index, max_count)
    # To make it more general, it is encapsuled under a hash params[:cursor]
    # Relad user again with meets to prevent db N+1 load issue
    @user = User.includes(:meets).find_by_id(params[:id])
    assert_internal_error(@user)
    respond_to do |format|
      format.html {
        @meets = @user.meets.paginate(:page => params[:page])
        @title = @user.name
      }
      format.json {
        @meets = @user.meets.cursorize(params[:cursor]||params)
        # This params staff is the workaround for to_json because :methods can not specify parameters. 
        # We can not hardcode :except (which is used to prevent display user herself in the list).
        @meets.each {|meet|
          meet.peers_name_list_params = {:except=>@user,:delimiter=>", ",:max_length=>80}
        }
        render :json =>
          @meets.to_json(:except => [:created_at, :updated_at],
                         :methods => [:users_count, :peers_name_brief])
      }
    end
  end

  def following
    @title = "Following"
    @user = User.find_by_id(params[:id])
    assert_unauthorized(@user)
    @users = @user.following.paginate(:page => params[:page])
    render 'show_follow'
  end
  
  def followers
    @title = "Followers"
    @user = User.find_by_id(params[:id])
    assert_unauthorized(@user)
    @users = @user.followers.paginate(:page => params[:page])
    render 'show_follow'
  end

  def new
    @user  = User.new
    @title = "Sign up"
  end
  
  def create
    if params[:user].nil?
      @user = User.new(params)
    else
      @user = User.new(params[:user])
    end
    if @user.save
      sign_in @user
      respond_to do |format|
        format.html { redirect_to @user, :flash => { :success => "Welcome to the Kaya App!" } }
        format.json { render :json => @user.to_json(:except => [:updated_at, :salt, :encrypted_password]) }
      end
    else
      @title = "Sign up"
      respond_to do |format|
        format.html { render 'new' }
        #format.json { render :json => User.new.to_json(:except => [:updated_at]) }
        format.json { render :json => @user.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end
  
  def edit
    @title = "Edit user"
  end
  
  def update
    if params[:user].nil?
      @user.update_attributes(params)
      render :json => @user.to_json(:except => [:updated_at, :salt, :encrypted_password])
    else 
      if @user.update_attributes(params[:user])
        redirect_to @user, :flash => { :success => "Profile updated." }
      else
        @title = "Edit user"
        render 'edit'
      end
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, :flash => { :success => "User destroyed." }
  end

end
