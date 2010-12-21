require 'rubygems'
require 'json'
require 'geokit'
require 'meet_processer'

class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :authorized_mpost_owner, :only => [:show]

  def create
    # this step automatically associates with the user
    saved = false
    @mpost = current_user.mposts.build(params)
    Rails.kaya_dblock {saved = @mpost.save}

    assert_internal_error(saved)
    if saved
      respond_to do |format|
        format.html { redirect_to root_path, :flash => { :success => "Mpost created!" } }
        format.json { render :json => @mpost.to_json(:except => [:updated_at, :created_at]) }
      end

      # Expedite from backup processer to give hosted post a quick response.
      # Under heavy load backup processser could backup. Host post need a meet_id
      # to kick start a host.
      if @mpost.is_host_owner?
        meet = Meet.new
        Rails.kaya_dblock {meet.mposts << mpost}
        meet.extract_information
        Rails.kaya_dblock {meet.save}
      else
        # Enqueue directly wihtin same server
        MeetWrapper.new.process_mpost(@mpost.id, Time.now.getutc)
        # Or use the worker version
        #MeetWrapper.new.delayed.process_mpost(@mpost.id, Time.now.getutc)
      end
    end
  end

  def show
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
