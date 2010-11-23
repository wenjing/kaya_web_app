class MeetsController < ApplicationController

  before_filter :authenticate

  def create
    @meet = Meet.new(params[:meet])

    if @meet.save

    else

    end
  end

  def destroy

  end

  def show
    @meet = Meet.find(params[:id])
    respond_to do |format|
      format.html {
        @users = @meet.mposts.paginate(:page => params[:page])
        @title = @meet.name
      }
      format.json {
        render :json =>
          @meet.to_json(:except => [:created_at, :updated_at], :include => {:users => {:except => [:salt, :encrypted_password, :created_at, :updated_at, :admin] } } )
      }
    end
  end

end
