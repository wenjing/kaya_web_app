require 'rubygems'
require 'json'
require 'geokit'
require 'meet_processer'

class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate

  def create
    # this step automatically associates with the user
    saved = false
    Rails.kaya_dblock {
      #user = current_user
      #if (!Rails.env.production? && current_user.admin && params[:user_id])
      #  # This is for debugging purpose. Allow admin to act as any users
      #  user = User.find(params[:user_id]) || user
      #end
      @mpost = current_user.mposts.build(params)
      saved = @mpost.save
    }

    if saved
      # here is the connecting point to Mpost handler
      # for testing, i'm creating one meet for each mpost
      # we create the meet, and associate it with the mpost
      #
      # First, reverse geocode from google
 
#     geo = Geokit::Geocoders::GoogleGeocoder::geocode(@mpost.lat.to_s+','+@mpost.lng.to_s)
#
#     @meet = Meet.create!(
#       :name => "Test meeting",
#       :description => "Testing meeting with a mobile post only",
#       :time => Time.now,
#       :location => geo.full_address,
#       :street_address => geo.street_name,
#       :city => geo.city,
#       :state => geo.state,
#       :zip => geo.zip,
#       :country => geo.country,
#       :lng => @mpost.lng,
#       :lat => @mpost.lat,
#       :users_count => 1,
#       :image_url => "http://www.facebook.com/album.php?profile=1&id=666348082"
#     )
#     @mpost.meet_id = @meet.id
#     @meet.mposts << @mpost
#     # now save both
#     # skipping error checking for now
#     @mpost.save
#     @meet.save # meet shall be saved automatically when mpost is saved
      
      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Mpost created!" } }
        format.json { render :json => @mpost.to_json(:except => [:updated_at, :created_at]) }
      end

      # Enqueue directly wihtin same server
      MeetWrapper.new.process_mpost(@mpost.id, Time.now.getutc)
      # Or use the worker version
      #MeetWrapper.new.delayed.process_mpost(@mpost.id, Time.now.getutc)

    else
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { head :unprocessable_entity }
      end
    end
  end

  def show
    @mpost = Mpost.find(params[:id])
    respond_to do |format|
      format.html {
        render @mpost
        @title = "mobile posts"
      }
      format.json {
        render :json => @mpost.to_json(:except => [:created_at, :updated_at])
        }
    end
  end

  def destroy
  end

end
