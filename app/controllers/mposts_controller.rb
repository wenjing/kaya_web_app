require 'rubygems'
require 'geokit'

class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate

  def create
    # this step automatically associates with the user
    @mpost = current_user.mposts.build(params)

    if @mpost.save
      # here is the connecting point to Mpost handler
      # for testing, i'm creating one meet for each mpost
      # we create the meet, and associate it with the mpost
      #
      # First, reverse geocode from google
      geo = Geokit::Geocoders::GoogleGeocoder::geocode(@mpost.lat.to_s+','+@mpost.lng.to_s)

      @meet = Meet.create!(
        :name => "Test meeting",
        :description => "Testing meeting with a mobile post only",
        :time => Time.now,
        :location => geo.full_address,
        :street_address => geo.street_name,
        :city => geo.city,
        :state => geo.state,
        :zip => geo.zip,
        :country => geo.country,
        :lng => @mpost.lng,
        :lat => @mpost.lat,
        :users_count => 1,
        :image_url => "http://www.facebook.com/album.php?profile=1&id=666348082"
      )

      @mpost.meet_id = @meet.id

      @meet.mposts << @mpost

      # now save both
      # skipping error checking for now
      @mpost.save
      @meet.save

      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Mpost created!" } }
        format.json { render :json => @mpost.to_json(:except => [:updated_at, :encrypted_password, :salt]) }
      end
    else
      @feed_items = []
      render 'pages/home'
    end
  end

  def destroy
  end

end

