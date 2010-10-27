class MeetsController < ApplicationController
  attr_accessible :name :description :time :location :street_address :city :state :zip :country :users_count :lng :lat

  def new
  end

end
