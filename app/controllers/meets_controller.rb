require 'rubygems'
require 'json'

class MeetsController < ApplicationController

  before_filter :authenticate
  before_filter :authorized_meet_member, :only => [:show]

  def create
    @meet = Meet.new(params[:meet])
    if @meet.save

    else

    end
  end

  def destroy

  end

  def show
    respond_to do |format|
      format.html {
        # Reload again to eager load to prevent db N+1 access
        @meet = Meet.includes(:mposts).find_by_id(params[:id])
        @users = @meet.mposts.paginate(:page => params[:page])
        @title = @meet.name
      }
      format.json {
        # Reload again to eager load to prevent db N+1 access
        @meet = Meet.includes(:users,:chatters).find_by_id(params[:id])
        render :json =>
          @meet.to_json(:except => [:created_at, :updated_at], 
                        :methods => :users_count, 
                        :include => {:users => {
                                        :methods => :user_avatar,
                                        :except => [:salt, 
                                                    :encrypted_password, 
                                                    :created_at, 
                                                    :updated_at, 
                                                    :admin
                                                    ] } }, 
                        :include => {:chatters => {
                                        :methods => :chatter_photo }}
                       )
      }
    end
  end

end
