class Meet < ActiveRecord::Base
    attr_accessible :name, :description, :time, :location, :street_address, :city, :state, :zip, :country, :users_count, :lng, :lat

end
