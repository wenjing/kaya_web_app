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
end
