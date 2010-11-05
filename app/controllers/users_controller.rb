class UsersController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate, :except => [:show, :new, :create]
  before_filter :correct_user, :only => [:edit, :update]
  before_filter :admin_user,   :only => :destroy
  
  def index
    @users = User.paginate(:page => params[:page])
    @title = "All users"
  end
  
  def show
    @user = User.find(params[:id])
    respond_to do |format|
      format.html {
        @microposts = @user.microposts.paginate(:page => params[:page])
        @mposts = @user.mposts.paginate(:page => params[:page])
        @title = @user.name
      }
      format.json { 
        render :json => 
          @user.to_json(:except => [:updated_at, :salt, :encrypted_password], :include => [:meets]) 
      } 
    end
  end

  def following
    @title = "Following"
    @user = User.find(params[:id])
    @users = @user.following.paginate(:page => params[:page])
    render 'show_follow'
  end
  
  def followers
    @title = "Followers"
    @user = User.find(params[:id])
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
        format.json { render :json => User.new.to_json(:except => [:updated_at]) }
      end
    end
  end
  
  def edit
    @title = "Edit user"
  end
  
  def update
    if @user.update_attributes(params[:user])
      redirect_to @user, :flash => { :success => "Profile updated." }
    else
      @title = "Edit user"
      render 'edit'
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, :flash => { :success => "User destroyed." }
  end

  private

    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_path) unless current_user?(@user)
    end
    
    def admin_user
      @user = User.find(params[:id])
      redirect_to(root_path) if !current_user.admin? || current_user?(@user)
    end
end
