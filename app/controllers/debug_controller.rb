require 'rubygems'

class DebugController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :authenticate
  before_filter :admin_current_user
  before_filter :admin_debug, :only => [:run]

  def run
    script = params[:script]
    respond_to do |format|
      format.json {
        begin
          eval script
          head :ok # 200
        rescue Exception => e
          puts e.to_s, e.backtrace
          head :internal_server_error # 500
        end
      }
    end
  end

  def mposts
    mposts0 = Array.new
    params[:mpost_ids].each {|mpost_id|
      mpost_id = mpost_id.to_i
      mpost = Mpost.find_by_id(mpost_id)
      mposts0 << mpost if mpost
    }
    respond_to do |format|
      format.json { render :json => mposts0.to_json(:include =>  {:meet=>{:include=>:users}}, :except => [:devs]) }
    end
  end

  def stats
    stats0 = Stats.first || stats.new
    respond_to do |format|
      format.json { render :json => stats0.to_json }
    end
  end

  private

    def admin_debug
      if (Rails.env.production? || !admin_user?)
        render_unauthorized
      else
        #render_unauthorized(:only=>:html)
      end
    end

end
