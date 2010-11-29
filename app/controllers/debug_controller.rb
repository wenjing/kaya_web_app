require 'rubygems'
require 'geokit'
require 'meet_processer'

class DebugController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :admin_debug

  def run
    script = params[:script]
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json {
        begin
          eval script
          head :ok
        rescue Exception => e
          puts e.to_s
          puts e.backtrace
          head :unprocessable_entity
        end
      }
    end
  end

  def mposts
    mposts = Array.new
    params[:mpost_ids].each {|mpost_id|
      mpost_id = mpost_id.to_i
      mpost = Mpost.find_by_id(mpost_id)
      mposts << mpost if mpost
    }
    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { render :json => mposts.to_json(:include =>  {:meet=>{:include=>:users}}, :except => [:devs]) }
    end
  end

  private

    def admin_debug
      if (Rails.env.production? || !current_user || !current_user.admin?)
        respond_to do |format|
          format.html { redirect_to root_path }
          format.json { head :unauthorized }
        end
      end
    end

end

