require 'meet_processer'

class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate

  def create
    # this step automatically associates with the user
    @mpost = current_user.mposts.build(params)

    if @mpost.save
      =begin
      # here is the connecting point to Mpost handler
      # for testing, i'm creating one meet for each mpost
      # we create the meet, and associate it with the mpost
      #
      @meet = Meet.create!(
        :name => "Test meeting",
        :description => "Testing meeting with a mobile post only",
        :time => Time.now,
        :location => "Testing place - no location",
        :street_address => "100 Main Street",
        :city => "Any Town",
        :state => "CA",
        :zip => "95054",
        :country => "USA",
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
      @meet.save # meet shall be saved automatically when mpost is saved
      =end
      
      # Enqueue directly wihtin same server
      KayaMeetWrapper.new.process_mpost(mpost.id)
      # Or use the worker version
      #KayaMeetWrapper.new.delayed.process_mpost(mpost.id)

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

