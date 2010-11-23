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
        @users = @meet.microposts.paginate(:page => params[:page])
        @title = @meet.name
      }
      format.json {
        render :json =>
          @meet.to_json(:except => [:updated_at], :include => [:users])
      }
    end
  end

end
