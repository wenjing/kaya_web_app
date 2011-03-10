require 'rubygems'
require 'json'
require 'geokit'
require 'meet_processer'
require 'delayed_job'

class MpostsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :only => [:create] do |controller|
    controller.filter_params(:mpost, :strip => [:email])
  end
  before_filter :only => [:create] do |controller|
    controller.correct_user(params[:user_id]) if params[:user_id]
    #controller.authorized_cirkle_member(params[:cirkle_id], false) if params[:cirkle_id]
  end
  before_filter :authorized_mpost_owner, :only => [:show]

  JSON_MPOST_DETAIL_API = {:except => [:created_at, :user_dev, :devs, :note, :lng, :lat, :lerror],
                           :methods => [:processing_status]}

  def create
    assert_unauthorized(false, :except=>:json)
    saved = false
    @user ||= current_user
    @mpost = @user.mposts.build(@filtered_params)
    Rails.kaya_dblock {saved = @mpost.save}

    if saved
      respond_to do |format|
        format.json { render :json => @mpost.to_json(JSON_MPOST_DETAIL_API) }
      end

      # Expedite from backup processer to give hosted post a quick response.
      # Under heavy load backend processser could backup to some extent.
      # Hoster need a meet_id to kick start a host.
#     if @mpost.is_host_owner?
#       meet = Meet.new
#       Rails.kaya_dblock {
#         meet.mposts << mpost
#         @user.hosted_meets << meet
#       }
#       meet.host = @mpost.user
#       meet.extract_information
#       Rails.kaya_dblock {meet.save}
#     else
        if ENV['NO_HEROKU_DJ']
          # Enqueue directly within same server
          MeetWrapper.new.process_mpost(@mpost.id, Time.now.getutc)
        else
          # enqueue for DJ worker
          Delayed::Job.enqueue @mpost
          # Or use the worker version
          #MeetWrapper.new.delayed.process_mpost(@mpost.id, Time.now.getutc)
        end
#     end
    else
      respond_to do |format|
        format.json { render :json => @mpost.errors.to_json, :status => :unprocessable_entity }
      end
    end
  end

  def show
    assert_unauthorized(false, :except=>:json)
    respond_to do |format|
      format.json { render :json => @mpost.to_json(JSON_MPOST_DETAIL_API) }
    end
  end
#
# def destroy
#
# end

end
