# This is main meet processing class.
# It is supposy used as singleton class which will keep necessary data remain in memory.
# It implements and hosts KayaTQueue module which allows outside objects to use queued mpost
# processing and also a timer to periodly invoke a certain method.
# It shall be initialized first, probally at the time when it is first invoked. When it is
# initialied, KayaTQueue is also created and started ready to be used rightway.

require 'singleton'
require 'kaya_base'
require 'kaya_tqueue'

# Required functions in Mpost:
#   trigger_time: already converted into utc, has to be reconverted back to local time for display
#   is_processed?
#   see?(another_mposts)
#   seen_by?(another_mposts)
#   see_or_seen_by?(another_mposts)
#   add_devs(devs)
#   add_dev(dev)
#
# Required functions in Meet:
#   mposts
#   extract_information
#   occured_earliest
#   occured_latest
#   indexed by time

# Since MeetProcesser is a singleton, it can not be used by delayed job (DJ)
# directly. Use this wrapper to bridge the gap. This wrap will be the one to pass
# on jobs and call function in MeetProcesser singleton.
# Usage:
#   MeetWrapper.new.delayed.process_mpost(mpost, Time.now.getutc)
#   MeetWrapper.new.delayed.setup_parameters(options)
#   MeetWrapper.new.delayed.start_record(1.day)
#   MeetWrapper.new.delayed.start_replay(Time.now-2.days, Time.now)
class MeetWrapper

  def initialize
  end

  # The at_time here is the issuing time not processing time. Under heavy load condition,
  # processer may lag behind issuer. To prevent messing up with double standard timers,
  # avoid using live time at processer, use issuer's time instead. That is because the issuer's
  # time is more close to actual mpost's time. This is important when dealing with hot posts.
  def process_mpost(mpost, at_time)
    process_mposts([mpost], at_time)
  end

  def process_mposts(mposts, at_time)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.process_mposts(mposts, at_time)
  end

  def process_meets(at_time)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.process_meets(true, at_time)
  end

  def setup_parameters(options)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.setup_parameters(options)
  end

  def restart_up(duration, at_time)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.restart_up(duration, at_time)
  end

  def catch_up(duration, at_time)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.catch_up(duration, at_time)
  end

  def start_record(duration)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.start_record(duration)
  end

  def stop_record(duration)
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.stop_record
  end

  def start_replay(start_time, end_time)
    start_time = start_time.getutc if start_time
    end_time = end_time.getutc if end_time
    meet_processer = MeetProcesser.instance
    meet_processer.tqueue.start_replay(from_time, end_time)
  end

  # Terminate replay, called asynchronously
  def stop_replay
    meet_processer = MeetProcesser.instance
    meet_processer.terminate_replay
  end

  # Delayed Job can not accesser to global module functions, use these
  # class instance functions as proxy to KayaBase's debug settting.
  def set_debug(type, level)
    KayaBase::set_debug(type, level)
  end
  def set_debugs(levels)
    KayaBase::set_debug(levels)
  end
  def clear_debug(type=nil)
    KayaBase::clear_debug(type)
  end

end


class MeetProcesser

  include Singleton
  include KayaTQueue

  cattr_accessor :infinite_coeff, :meet_duration_loose

  @@timer_interval      = 1.0  # timer internal
  @@meet_duration_tight = 5.0  # fully counted if 2 mposts are trigger within time period
  @@meet_duration_loose = 10.0 # discounted within time period, different meets if exceed
  # Process a raw cluster if its earliest mpost exceed limit AND has not receive new mpost
  # for a while and it is complete (all peer devs are included in self devs)
  @@hot_time_idle        = 2.0
  @@hot_time_threshold   = 5.0
  @@hot_time_limit       = 10.0 # force to process a raw cluster if earliest mpost exceed limit
  @@cold_time_limit      = 1800.0  # freeze processe clusters older than limit
  # Shall be much larger than meet_duration_loose, 10 mins
  @@cold_time_margin = [@@meet_duration_loose*5, 600.0].max
  # Exponentially decay starting from duration_tight to durantion_loose to 10% of original value
  @@delta_time_discounts  = (0..100).map {|x| ((100.0-x)**2/10000.0+1.0/9.0)/(1.0+1.0/9.0)}
  @@infinite_coeff        = 1000000.0  # infinite coeff value
  @@uni_connection_discount = 0.8 # discount if A see B but B does not see A
  # A member's coeff to the group can not be less than 5% of average
  @@coeff_vs_avg_threshold = 0.05

  #@@timer_interval       = 5.0  # timer internal
  #@@hot_time_idle        = 5.0
  #@@hot_time_threshold   = 10.0
  #@@hot_time_limit       = 15.0
  #@@cold_time_limit      = 50.0  # freeze processe clusters older than limit
  #@@coeff_vs_avg_threshold = 0.05

  def setup_parameters(options)
    @@timer_interval       = options[:timer_interval]       if options[:timer_interval]
    @@meet_duration_tight  = options[:meet_duration_tight]  if options[:meet_duration_tight]
    @@meet_duration_loose  = options[:meet_duration_loose]  if options[:meet_duration_loose]
    @@hot_time_idle        = options[:hot_time_idle]        if options[:hot_time_idle]
    @@hot_time_threshold   = options[:hot_time_threshold]   if options[:hot_time_threshold]
    @@hot_time_limit       = options[:hot_time_limit]       if options[:hot_time_limit]
    @@cold_time_limit      = options[:cold_time_limit]      if options[:cold_time_limit]
    @@cold_time_margin     = options[:cold_time_margin]     if options[:cold_time_margin]
    @@delta_time_disconts  = options[:delta_time_disconts]  if options[:delta_time_disconts]
    @@infinite_coeff       = options[:infinite_coeff]       if options[:infinite_coeff]
    @@uni_connection_discount = options[:uni_connection_discount] if options[:uni_connection_discount]
    @@coeff_vs_avg_threshold = options[:coeff_vs_avg_threshold] if options[:coeff_vs_avg_threshold]
  end

  def initialize
    fresh_start
    @record_start_time = nil
    @record_end_time = nil
    @replay_start_time = nil
    @replay_end_time = nil
    @history_mutex = Mutex.new
    start_tqueue
  end

  def empty?
    return @meet_pool.empty?
  end

  def dump_debug
    @meet_pool.dump_debug(:processer)
    debug(:processer, 3, "elapsed time from start %s", get_elapse_time)
  end

  # Mpost processer, right now, queued from controller directly.
  # In furture, this processer will operate on seperate machine outside controller.
  # Instead of being called from controller directly, controller passes it to an external
  # mpost queue and dispatch to backend machines. The backend machine running this
  # processer will use main thread to read incoming external mposts and queue proper
  # method for further processing.
  # This is relatively lightweight comparing with process_meets. It basically pools the
  # incoming mposts and passes it onto process_meets.
  def process_mposts(mposts, at_time, is_replay=false)
    @time_now = at_time.getutc # centralized standard now time
    debug(:processer, 1, "%s %s %s at %s(+%d)",
          (is_replay ? "replay" : "received"), pluralize(mposts.size, "mpost"),
          mposts.join(","), @time_now.localtime.time_ampm, (Time.now-@time_now).round)
    record_mposts(mposts)
    mposts.each {|mpost_id|
      Rails.kaya_dblock {
        mpost = Mpost.find_by_id(mpost_id)
        process_mpost_core(mpost) if mpost
      }
    }
    # XXX, Shall we call process_meets for every new mpost?
    # process_meets(false, at_time.getutc)
  end

  # Heavyweight, process pending mposts and assign meet to them.
  # Save to db if necessary.
  def process_meets(is_timer, at_time, is_replay=nil)
    # If it is triggered from timer, make sure enough time has passed since last
    # time it is called
    if is_timer_interval_ok?(is_timer, at_time.getutc)
      @time_now = at_time.getutc
      return if @meet_pool.empty?
      debug(:processer, 1, "%s meet processing %sat %s(+%d) : r%d p%d m%d",
            (is_replay ? "replay" : "received"), (is_timer ? "by timer " : ""),
            @time_now.localtime.time_ampm, (Time.now-@time_now).round,
            @meet_pool.raw_clusters.size, @meet_pool.processed_clusters.size,
            @meet_pool.pending_mposts.size)
      record_mposts(nil)
      process_meets_core
    end
  end

  def restart_up(duration, at_time)
    stop_record; stop_replay
    restart_tqueue
    catch_up(duration, end_time)
  end

  def catch_up(duration, at_time)
    end_time = at_time
    start_time = end_time - duration
    mposts = nil
    Rails.kaya_dblock {
      mposts = Mpost.where("created_at >= ? AND created_at <= ? AND meet_id = nil",
                           start_time, end_time)
      mpost.each {|mpost| mpost.id}
    }
    fresh_start
    process_mposts(mposts.map {|mpost| mpost.id}, at_time)
  end

  def start_record(duration)
    stop_record
    if (duration && duration > 0.0)
      stop_replay
      @record_start_time = Time.now.getutc
      @record_end_time = @record_start_time + duration
      debug(:record, 1, "start recording from %s to %s",
            @record_start_time, @record_end_time)
    end
  end

  def stop_record
    if is_recoding?
      debug(:record, 1, "stop recording at %s", Time.now.getutc)
      @record_start_time, @record_end_time = nil, nil
    end
  end

  def start_replay(start_time, end_time)
    stop_replay
    if (start_time && (start_time < end_time))
      stop_record
      @replay_start_time, @replay_end_time = start_time, end_time
      records = nil
      Rails.kaya_dblock {
        records = MpostRecord.where("time >= ? AND time <= ?",
                                    @replay_start_time, @replay_end_time)
        records.each {|record| record.id}
      }
      if !records.empty?
        @tqueue_timer.pause
        fresh_start
        debug(:replay, 1, "replaying %s from %s to %s",
              pluralize(records.size, "record"),
              @replay_start_time, @replay_end_time)
        @history_mutex.safe_run {@replay_terminated = false}
        for record in records
          # Check if it is stopped (asynchronously)
          terminated = false
          @history_mutex.safe_run {stop_replay if @replay_terminated}
          break unless is_replaying?
          if record.mpost_id?
            process_mposts([record.mpost_id], record.time, true)
          else
            process_meets(true, record.time, true)
          end
        end
        stop_replay
        fresh_start
        @tqueue_timer.resume
      end
      debug(:replay, 2, "done replaying")
    end
  end

  def stop_replay
    if is_replaying?
      debug(:replay, 1, "stop replaying at %s", Time.now.getutc)
      @replay_start_time, @replay_end_time = nil, nil
    end
  end

  def terminate_replay
    @replay_mutex.safe_run {@replay_terminated = true}
  end

  def is_recording?
    return @record_start_time && @record_end_time
  end

  def is_replaying?
    return @replay_start_time && @replay_end_time
  end

private

  def start_tqueue
    tqueue_start(@@timer_interval, 2) {MeetWrapper.new.process_meets(Time.now.getutc)}
    #tqueue_start(@@timer_interval, 2) {MeetWrapper.new.delayed.process_meets(Time.now.getutc)}
  end
  def restart_tqueue
    tqueue_end
    start_tqueue
  end

  # Get rid of cached data
  def fresh_start
    @start_time = nil
    @time_now   = nil
    @last_meets_process_time = nil
    @meet_pool = MeetPool.new
  end

  def record_mposts(mpost_ids)
    # Can not record during replay
    if (!is_replaying? && @record_start_time)
      if (@time_now >= @record_start_time && @time_now <= @record_end_time)
        if mpost_ids
          mpost_ids.each {|mpost_id|
            Rails.kaya_dblock {MpostRecord.create(:mpost_id=>mpost_id, :time=>@time_now)}
          }
        else
          Rails.kaya_dblock {MpostRecord.create(:mpost_id=>nil, :time=>@time_now)}
        end
      else
        # Record complete, reset start and end time
        stop_record
      end
    end
  end

# Trivial helper functions
 
  def is_timer_interval_ok?(is_timer, at_time)
    curr_time = at_time
    if (is_timer &&
        @last_meets_process_time &&
        (curr_time-@last_meets_process_time) < @@timer_interval/2.0)
      return false
    end
    @last_meets_process_time = curr_time
    return true
  end

  def mpost_time_from_now(mpost)
    return mpost ? [@time_now-mpost.trigger_time, 0.0].max : 0.0
  end

  #def meet_time_from_now(meet)
  #  return meet ? [mpost_time_from_now(meet.latest_mpost),
  #                  mpost_time_from_now(meet.earliest_mpost)],
  #                 [0.0, 0.0]
  #end

  def shall_process_cluster?(cluster)
    return !cluster.is_processed? &&
           (mpost_time_from_now(cluster.latest_mpost) > @@hot_time_idle &&
            mpost_time_from_now(cluster.earliest_mpost) > @@hot_time_threshold &&
           cluster.is_complete?) ||
           mpost_time_from_now(cluster.earliest_mpost) > @@hot_time_limit
  end

  def delta_time_discount(time_delta)
    time_delta = (time_delta-@@meet_duration_tight).to_f/
                      (@@meet_duration_loose-@@meet_duration_tight)
    return time_delta <= 0.0 ? 1.0 :
           time_delta >  1.0 ? 0.0 :
              @@delta_time_discounts[time_delta*(@@delta_time_discounts.size-1)]
  end

  # Must be only in database, skip checking on memory. No risk to cause
  # database and memory out-of-sync
  def is_definitely_cold?(mpost)
    return mpost_time_from_now(mpost) > @@cold_time_limit + @@cold_time_margin
  end

  # Must be on memory (though may be also in database), skip checking database
  # even found no match on memory. After it is processed, memory and database will
  # be in-sync.
  # However, the cold_time is not necessary to be cold_time_limit all the time.
  # When processer just started or refreshed, cold time is 0. It gradually
  # grows upto limit. Acutall cold time is the min of elasped time and the limit.
  def is_definitely_warm?(mpost)
    cold_time = [@@cold_time_limit, get_elapse_time].min
    return mpost_time_from_now(mpost) < cold_time - @@cold_time_margin
  end

  # Time lapse from processer fresh start time until now.
  def get_elapse_time
    @start_time ||= @time_now
    return @time_now - @start_time
  end

  def is_cluster_cold?(cluster)
    return cluster.is_processed? &&
           mpost_time_from_now(cluster.earliest_mpost) > @@cold_time_limit
  end

  # Delete any mpost whose host_id is included in mposts
  def delete_joined_mposts_from_meet(mposts, meet)
    host_ids = Set.new
    mposts.each { |mpost| host_ids << mpost.host_id if mpost.host_id.present? }
    meet.mposts.each {|mpost|
      if host_ids.include?(mpost.host_id)
        mpost.delete; mpost.save
      end
    }
    meet.opt_lock_protected {
      meet.extract_information
      Rails.kaya_dblock {meet.save}
    }
  end

  def assign_mposts_to_meet(mposts, meet)
    mposts.each {|mpost|
      Rails.kaya_dblock {meet.mposts << mpost} 
    }
    meet.opt_lock_protected {
      meet.extract_information
      Rails.kaya_dblock {meet.save}
    }
  end

  def assign_mpost_to_meet(mpost, meet)
    Rails.kaya_dblock {meet.mposts << mpost}
    meet.opt_lock_protected {
      meet.extract_information
      Rails.kaya_dblock {meet.save}
    }
  end

  def add_mpost_to_meet(mpost, meet)
    assign_mpost_to_meet(mpost, meet)
    debug(:processer, 2, "*** add to meet %d of %s",
          meet.id, pluralize(1, "mpost"))
  end

  def add_mposts_to_meet(mposts, meet)
    assign_mposts_to_meet(mposts, meet)
    debug(:processer, 2, "*** add to meet %d of %s",
          meet.id, pluralize(mpost.size, "mpost"))
  end

  def add_owners_to_hosted_meet(mposts, meet)
    # The meet is already created by owner, use this mpost to assign hoster_id and meet_name
    ng_mposts = mposts.clone
    if (meet && !mposts.empty?)
      hoster = nil
      mposts.each {|mpost|
        user = mpost.user
        hoster_id = mpost.hoster_from_host_id
        # Some sanity check, make sure this is the owner
        if (meet.include_user?(user) && user.id == hoster_id.to_i)
          ng_mposts.delete(mpost)
          hoster ||= user
          meet_name = mpost.meet_name_from_host_id
          if meet_name.present?
            mview = Mview.user_meet_mview(user, meet).first
            if !mview
              mview = Mview.new
              mview.user = user
              mview.meet = meet
            end
            # Do not overwrite existing meet name
            mview.name = meet_name if mview.name.blank?
            mview.save
          end
        end
      }
      # Assign hoster if no hoster exists yet. Only support one hoster per meet.
      meet.opt_lock_protected {
        if (!meet.has_hoster? && hoster)
          meet.hoster = hoster; meet.save
        end
      }
    end
    return ng_mposts
  end
  def add_guests_to_hosted_meet(mposts, meet)
    # Even with host_id, still have to check devs to confirm they are actually linked
    ng_mposts = mposts.clone
    if (meet && !mposts.empty?)
      ok_mposts = Array.new
      hoster = nil
      mposts.each {|mpost|
        # Maybe better only to check against meet_mpost that is host or proxy mode
        if meet.see_or_seen_by?(mpost)
          ok_mposts << mpost
          ng_mposts.delete(mpost)
          hoster ||= User.find(mpost.hoster_from_host_id)
        end
      }
      if !ok_mposts.empty?
        assign_mposts_to_meet(ok_mposts, meet)
        # Assign hoster if no hoster exists yet. Only support one hoster per meet.
        meet.opt_lock_protected {
          if (!meet.has_hoster? && hoster)
            meet.hoster = hoster; meet.save
          end
        }
      end
    end
    return ng_mposts
  end

  def add_owners_to_joined_meet(mposts, meet)
    ng_mposts = mposts.clone
    if (meet && !mposts.empty?)
      ok_mposts = Array.new
      xx_mposts = Array.new
      mposts.each {|mpost|
        owner = mpost.user
        collision = Mpost.join_owner_or_client(mpost).any? {|v| v.collision?}
        # Some sanity check, make sure it is legit and only for collision purpose
        if meet.include_user?(owner)
          #if !mpost.collision?
          if (!collision && !mpost.collision?)
            ok_mposts << mpost 
          else
            xx_mposts << mpost 
          end
          ng_mposts.delete(mpost)
        end
      }
      assign_mposts_to_meet(ok_mposts, meet) if !ok_mposts.empty?
      delete_joined_mposts_from_meet(xx_mposts, meet) if !xx_mposts.empty?
    end
    return ng_mposts
  end
  def add_guests_to_joined_meet(mposts, meet)
    # The owner of joined meet must already be in the meet already.
    ng_mposts = mposts.clone
    if (meet && !mposts.empty?)
      ok_mposts = Array.new
      xx_mposts = Array.new
      mposts.each {|mpost|
        #owner = mpost.hoster_from_host_id
        collision = Mpost.join_owner_or_client(mpost).any? {|v| v.collision?}
        # Sanity check, join guest connect directly with ower
        # However, not sure if this is true, skip the check for now.
        #if meet.see_or_seen_by?(mpost)
        #if meet.incluce_user?(owner)
          if (!collision && !mpost.collision?)
            ok_mposts << mpost
          else
            xx_mposts << mpost 
          end
          ng_mposts.delete(mpost)
        #end
      }
      assign_mposts_to_meet(ok_mposts, meet) if !ok_mposts.empty?
      ## Unlike join owner, simply ignore join guest with collision
      delete_joined_mposts_from_meet(xx_mposts, meet) if !xx_mposts.empty?
    end
    return ng_mposts
  end

  def create_meet_from_mposts(mposts)
    meet = Meet.new
    assign_mposts_to_meet(mposts, meet)
    debug(:processer, 2, "*** created new meet %d from %s",
          meet.id, pluralize(mposts.size, "mpost"))
    return meet
  end
  def create_meet_from_mpost(mpost)
    meet = Meet.new
    assign_mpost_to_meet(mpost, meet)
    debug(:processer, 2, "*** created new meet %d from %s",
          meet.id, pluralize(1, "mpost"))
    return meet
  end

# def get_meets_by_host_id(mpost)
#   meets = nil
#   if (mpost.host_id.present?)
#     Rails.kaya_dblock {
#       meets = Meet.where("host_id == ?", mpost.host_id).includes(:mposts)
#       meets.each {|meet| meet.id} # make sure it is loaded here
#     }
#   end
#   return meets
# end

  def get_meets_around_mpost(mpost)
    return get_meets_by_range(mpost.trigger_time - @@meet_duration_loose,
                              mpost.trigger_time + @@meet_duration_loose)
  end

  def get_meets_by_range(from, to)
    meets = nil
    Rails.kaya_dblock {
      meets = Meet.where("time >= ? AND time <= ?", from, to).includes(:mposts)
      meets.each {|meet| meet.id} # make sure it is loaded here
    }
    return meets
  end

# Core algorithm functions.
# The main purpose of these functions is to process received mposts into meets.
# At first, mposts are categorized basing on mpost age basing on trigger time:
#   1) Hot, new will wait for mposts before process them
#   2) Warm, already processed into meets but still stay in memory
#   3) Cold, already processed into meets and released fro memory
# However, for robustness, these categories are used slightly differently. A mpost
# instead is categrized into following categories:
#   1) Defintely warm, processed or not but must be in memory
#   2) Defintely cold, processed and must only in db
#   3) Somthing in between, processed and maybe or may not in memory
# The reason for the above tricks is to make sure information stays sync if exists in
# both memory and db. The something-in-between is the most dangerouse which require
# special handling.
#
# A group of related individual mposts form a cluster. A cluseter is processed when
# it cools down from hot to warm. A processed cluster become an meet and save into db.
# When a processed cluster (meet) becomes cold, it is release from memory.
#
# A cluster is created and grown in following ways:
#   A) If mpost is definitely cold, it is passed to cold processer which retrives
#      related meets and rebuild cluster from there.
#   B) If mpost is definitely warm, it is passed to main processer which try to attach
#      to existing clusters. Combine some clusters if necessary. If rejected by all
#      clusters, it seed a new cluster.
#   C) If mpost is in-between, it first try B) without seeding new cluster if rejected
#      all existing ones. If failed B), do A) instead.
#
# Follow these guidline for attaching mposts:
#   A) Processed clusters (meets) first
#      If a mpost can attach to a processed cluster (meet), do it. Meet there maybe some other
#      raw clusters which make better fit.
#   B) No reconfiguration for processed clusters (meets)
#      Only add members, no split, no remove, no combine
#   C) No exception for processed cluster (meet)
#      If mpost violate any rule (e.g. loose_time_duration), it can not attach to a processed
#      cluster.
#   D) Choose the best fit for processed clusters (meets)
#      If an mpost can attach to multiple processed clusters (meets), choose the best one.
#   F) Combine raw clusters if necessary
#      If an mpost can attach to multiple raw clusters, combine them.

  def pass_coeff_criteria_normal?(gain, coeff, coeff_stats)
    return gain > 0.0 && coeff >= coeff_stats[0] * @@coeff_vs_avg_threshold
  end

  def pass_coeff_criteria_simple?(gain, coeff, coeff_stats)
    return gain > 0.0 # only check gain
    # && coeff >= coeff_stats[0] * @@coeff_vs_avg_threshold
  end

  def calculate_coeff(connect, time_delta)
    return -@@infinite_coeff if time_delta > @@meet_duration_loose
    return 0.0 if connect <= 0
    coeff = (connect == 2 ? 1.0 : @@uni_connection_discount)
    coeff *= delta_time_discount(time_delta)
    return coeff
  end

  def coeff_calculator(from, to)
    time_delta = (from.trigger_time-to.trigger_time).abs
    connect = 0
    connect += 1 if from.see?(to)
    connect += 1 if to.see?(from)
    return calculate_coeff(connect, time_delta)
  end

  # Choose the best hosted meet and assign the mpost to it.
  # Only check host_id and devs. There is no time duration constraint for hosted meet.
  # Return the assigned meet.
# def assign_mpost_to_hosted_meets_if_possible(mpost)
#   meets = get_meets_by_host_id(mpost)
#   candidates = Hash.new
#   meets.each {|meet|
#     meet.mposts.each {|meet_mpost|
#       if (meet_mpost.see_or_be_seen?(mpost) || meet_mpost.see_common?(mpost))
#         candidates[meet] = (meet.time-mpost.time).abs
#       end
#     }
#   }
#   return nil if candidates.empty?
#   # Select the best one and assign to it (the closest to it in time)
#   meet = (candidates.min_by {|h| h[1]})[0] # use the closest meet
#   add_mpost_to_meet(mpost, meet)
#   return meet
# end

  # Choose the best meet and assign the mpost to it.
  # Return the assigned meet.
  def assign_mpost_to_meets_if_possible(mpost, meets)
    candidates = Hash.new
    meets.each {|meet|
      if (meet.time >= mpost.trigger_time - @@meet_duration_loose &&
          meet.time <= mpost.trigger_time + @@meet_duration_loose)
        relation = MeetRelation.new
        relation.populate_from_meet_for_mposts(meet, [mpost], &method(:coeff_calculator))
        coeff_gain = relation.proceed(&method(:pass_coeff_criteria_simple?))
        if (coeff_gain > 0.0) # can be assigned to the meet
          candidates[meet] = [coeff_gain, meet.mposts.size]
        end
      end
    }
    return nil if candidates.empty?
    # Select the best one and assign to it
    meet = (candidates.max_by {|h| h[1]})[0] # use the meet with highest score
    add_mpost_to_meet(mpost, meet)
    return meet
  end

  # Find a best fist cold meet to assign the mpost to.
  # Create a new one if found none.
  # Attach a cluster (processed or raw) to attach the mpost to.
  # Return false if found none.
  def assign_mpost_to_clusters_if_possible(mpost)
    # First, try to find a best fit processed cluster (meets) to assign
    # the mpost to.
    meets = @meet_pool.meets
    assigned_meet = assign_mpost_to_meets_if_possible(mpost, meets.keys)
    if assigned_meet
      # Succesfully assign the mpost to a existing meet
      # Also populate cluster's member
      meets[assigned_meet] << mpost
      return true
    elsif @meet_pool.add_to_raw_clusters_if_possible(mpost)
      # Succesfully assign the mpost to a raw cluster
      return true
    end
    return false
  end

  def assign_mpost_to_cold_meets_if_possible(mpost)
    # First, get all candidate meets which this mpost could assigned to
    meets = get_meets_around_mpost(mpost)
    return assign_mpost_to_meets_if_possible(mpost, meets)
  end

  def process_raw_clusters
    # Anything marked skipped, will no longer be processed this next
    skipped_clusters = Set.new
    done = false
    while !done
      done = true
      raw_clusters = @meet_pool.raw_clusters.to_a
      raw_clusters.each {|cluster|
        if skipped_clusters.include?(cluster)
          # Skip it
        elsif !shall_process_cluster?(cluster)
          # Too early, wait until it cool down a bit
          skipped_clusters << cluster
        elsif cluster.size == 1 # special case, only 1 node left
          cluster.meet = create_meet_from_mposts(cluster.mposts)
          @meet_pool.move_to_processed_clusters(cluster)
        else
          relation = MeetRelation.new
          relation.populate_from_cluster(cluster, &method(:coeff_calculator))
          coeff_gain = relation.proceed(&method(:pass_coeff_criteria_normal?))
          if coeff_gain >= 0.0 # 0 means nothing more except the seeded one
            mposts = relation.seeded.keys
            cluster = @meet_pool.split_cluster(mposts, cluster)
            cluster.meet = create_meet_from_mposts(mposts)
            @meet_pool.move_to_processed_clusters(cluster)
            done = false
          else
            # Something wrong, skip processing it this time
            skipped_clusters << cluster
          end
        end
      }
    end
  end

  def process_pending_mposts
    host_owners = Hash.new
    host_guests = Hash.new
    join_owners = Hash.new
    join_guests = Hash.new
    @meet_pool.pending_mposts.each {|mpost|
      if mpost.is_processed?
        # Shall we do something here?
      elsif mpost.is_host_owner?
        # Shall not come here, expedite to process_mpost for quick response
        #create_meet_from_mpost(mpost)
        # The meet is already created. Use this mpost to mark hoster and meet_name in mview.
        (host_owners[mpost.meet_from_host_id] ||= Array.new) << mpost
      elsif mpost.is_host_guest?
        # Collect all mposts of same meet, so we can process them all at once
        (host_guests[mpost.meet_from_host_id] ||= Array.new) << mpost
      elsif mpost.is_join_owner?
        (join_owners[mpost.meet_from_host_id] ||= Array.new) << mpost
      elsif mpost.is_join_guest?
        (join_guests[mpost.meet_from_host_id] ||= Array.new) << mpost
      elsif is_definitely_cold?(mpost) # must not in meet_pool, check db directly
        if !assign_mpost_to_cold_meets_if_possible(mpost)
          # Create a orphan meet and assigned this mpost as solo member
          create_meet_from_mpost(mpost)
        end
      elsif is_definitely_warm?(mpost)
        if !assign_mpost_to_clusters_if_possible(mpost)
          # Create a new cluster and attach the mpost to it
          @meet_pool.create_raw_cluster(:mpost=>mpost)
        end
      elsif assign_mpost_to_clusters_if_possible(mpost)
        # Ok, it is in memory now, it is attached to a processed cluster, it is already saved
        # to db. Otherwise it stay in a raw cluster waiting to be processed (probably soon).
      elsif assign_mpost_to_cold_meets_if_possible(mpost)
        # Ok, it is in db now. Not in memory.
      elsif
        # Nowhere to go, keep in memory and will be processed soon.
        # Create a new cluster and attach the mpost to it
        @meet_pool.create_raw_cluster(:mpost=>mpost)
      end
    }
    @meet_pool.pending_mposts.clear

    ng_mposts = Array.new
    host_owners.each_pair {|meet_id, mposts|
      meet = Meet.includes(:mposts).find_by_id(meet_id)
      ng_mposts.concat(add_owners_to_hosted_meet(mposts, meet))
    }
    host_guests.each_pair {|meet_id, mposts|
      meet = Meet.includes(:mposts).find_by_id(meet_id)
      ng_mposts.concat(add_guests_to_hosted_meet(mposts, meet))
    }
    join_owners.each_pair {|meet_id, mposts|
      meet = Meet.includes(:mposts).find_by_id(meet_id)
      ng_mposts.concat(add_owners_to_joined_meet(mposts, meet))
    }
    join_guests.each_pair {|meet_id, mposts|
      meet = Meet.includes(:mposts).find_by_id(meet_id)
      ng_mposts.concat(add_guests_to_joined_meet(mposts, meet))
    }

    # Under normal circumstance, this shall never happen unless someone try to
    # abuse the system. We can either quitely ignore these posts, or we can play it
    # nicely by converting them to peer mode posts and put back to pool to be processed later.
    ng_mposts.each {|mpost|
      mpost.force_to_peer_mode
      mpost.save
      @meet_pool.pending_mposts << mpost
    }
  end

  # Remove cold meets from pool.
  # Also update cold_time to earliest mpost_time_from_now still in pool.
  def release_cold_meets
    # Eliminate processed clusters and corresponding mpost from pool if their
    # latest time_from_now is larger than cold_time_limit
    released_count = 0
    @meet_pool.processed_clusters.each {|cluster|
      if is_cluster_cold?(cluster)
        @meet_pool.pop_cluster(cluster)
        released_count += 1
      end
    }
    if released_count > 0
      debug(:processer, 2, "*** released %s", pluralize(released_count, "cold meets"))
    end
  end

  def process_mpost_core(mpost)
#   if (!mpost.is_processed? && mpost.is_host_owner?)
      # Unconditionally create a meet from it
      # Expedite to here to improve response time
      # Further moved up to mpost_controller to be handled directly over there.
      # Ensure quick respond even when backup process is backing up
      # create_meet_from_mpost(mpost)
      # mpost.user.hosted_meets << mpost.meet
#   else
      @meet_pool.pending_mposts << mpost
#   end
  end

  def process_meets_core
    return if @meet_pool.empty?
    @meet_pool.dump_debug(:pool_before)
    process_pending_mposts
    @meet_pool.dump_debug(:pool_cluster)
    process_raw_clusters
    @meet_pool.dump_debug(:pool_cold)
    release_cold_meets
    @meet_pool.dump_debug(:pool_after)
  end

end

class MeetMasterMpost

  attr_accessor :user_devs, :device_devs

  def initialize
    self.user_devs = Set.new
    self.device_devs = Set.new
  end

  def <<(mpost)
    user_devs << mpost.user_dev
    mpost.devs.each_key {|dev| device_devs << dev}
  end

  def see_or_seen_by?(mpost)
    return true if device_devs.include?(mpost.user_dev) # see?
    for dev in device_devs
      return true if mpost.see_dev?(dev) # seen_by?
    end
    return false
  end

end

class MeetCluster

  attr_accessor :meet, :latest_mpost, :earliest_mpost, :mposts, :master_mpost

  def initialize(options={})
    self.meet           = nil
    self.latest_mpost   = nil
    self.earliest_mpost = nil
    self.mposts         = Set.new
    self.master_mpost   = MeetMasterMpost.new
    self << options[:mpost] if options[:mpost]
    if options[:mposts]
      options[:mposts].each {|mpost| self << mpost}
    end
  end

  def is_processed?
    return meet != nil
  end

  # Return true if mposts graph is self contained. No body see any outsiders.
  def is_complete?
    return master_mpost.user_devs.superset?(master_mpost.device_devs)
  end

  def <<(mpost)
    mposts << mpost
    self.latest_mpost    = mpost if (latest_mpost == nil ||
                                     latest_mpost.trigger_time < mpost.trigger_time)
    self.earliest_mpost  = mpost if (earliest_mpost == nil ||
                                     earliest_mpost.trigger_time > mpost.trigger_time)
    master_mpost << mpost
  end

  # Not only check if see or be seen, also check time delta. Do not attach if this
  # mpost is to seperated from the cluster
  def attachable?(to)
    margin = MeetProcesser.meet_duration_loose
    return to.trigger_time >= earliest_mpost.trigger_time-margin &&
           to.trigger_time <=   latest_mpost.trigger_time+margin &&
           master_mpost.see_or_seen_by?(to)
           
  end

  def size
    return mposts.size
  end

end


class MeetPool

  attr_accessor :raw_clusters, :processed_clusters, :pending_mposts

  def initialize
    self.raw_clusters       = Set.new
    self.processed_clusters = Set.new
    self.pending_mposts     = Set.new
  end

  def empty?
    return raw_clusters.empty? && processed_clusters.empty? && pending_mposts.empty?
  end

  def dump_debug(type)
    if is_debug?(type, 1)
      debug(type, 1, "meet pool information:")
      cdebug("\thas %s", pluralize(raw_clusters.size, "raw_cluster"))
      cdebug("\thas %s", pluralize(processed_clusters.size, "processed_cluster"))
      cdebug("\thas %s", pluralize(pending_mposts.size, "pending_mpost"))
      dump_debug_clusters(type, "raw", raw_clusters)
      dump_debug_clusters(type, "processed", processed_clusters)
      dump_debug_mposts(type, "pending", pending_mposts)
    end
  end

  def dump_debug_clusters(type, header, clusters)
    if is_debug?(type, 2)
      debug(type, 2, "%s clusters information:", header)
      index = 0
      clusters.each {|cluster|
        # :meet, :latest_mpost, :older_mpost, :mposts, :master_mpost
        cdebug("\tcluster %d:", index)
        cdebug("\t  %s with %s from %s to %s",
               (cluster.is_processed? ? "processed" : "raw"),
               pluralize(cluster.mposts.size, "mpost"),
               (cluster.earliest_mpost ? cluster.earliest_mpost.trigger_time : "---"),
               (cluster.latest_mpost ? cluster.latest_mpost.trigger_time : "---"))
        index += 1
      }
    end
  end

  def dump_debug_mposts(type, header, mposts)
    if is_debug?(type, 2)
      debug(type, 2, "%s mposts information:", header)
      index = 0
      mposts.each {|mpost|
        # :trigger_time, :devs, :location
        cdebug("\tmpost %d:", index)
        cdebug("\t  %s with %s triggered at %s",
               (mpost.is_processed? ? "processed" : "raw"),
               pluralize(mpost.devs.size, "device"),
               mpost.trigger_time)
        index += 1
      }
    end
  end

  # Return hash of meet=>processed_cluster
  def meets
    meets = Hash.new
    processed_clusters.each {|cluster| meets[cluster.meet] = cluster}
    return meets
  end

  def create_raw_cluster(options)
    cluster = MeetCluster.new(options)
    raw_clusters << cluster
    return cluster
  end

  def pop_clusters(clusters)
    clusters.each {|cluster| pop_cluster(cluster)}
  end

  def pop_cluster(cluster)
    if cluster.is_processed?
      processed_clusters.delete(cluster)
    else
      raw_clusters.delete(cluster)
    end
  end

  def merge_clusters(cluster1, cluster2)
    if cluster1.size > cluster2.size
      from, to = cluster2, cluster1
    else
      from, to = cluster1, cluster2
    end
    from.mposts.each {|mpost| to << mpost}
    pop_cluster(from)
    return to
  end

  # Add mpost to clusters, merge if necessary.
  # Return false if fails.
  def add_to_raw_clusters_if_possible(mpost, &block)
    attachable_clusters = Set.new
    raw_clusters.each {|cluster|
      attachable_clusters << cluster if cluster.attachable?(mpost)
    }
    return false if attachable_clusters.empty?
    to_cluster = nil
    attachable_clusters.each {|cluster|
      to_cluster ||= cluster
      if to_cluster != cluster
        to_cluster = merge_clusters(to_cluster, cluster)
      end
    }
    to_cluster << mpost
    return true
  end

  # Split mposts from cluster and create new clusters.
  # Return main cluster created from specified mposts
  def split_cluster(mposts, cluster)
    return nil if mposts.empty?
    # The mposts must be all related to each other, create a cluster from them
    # and then proceed to remaining ones until all are processed
    main_cluster = nil
    while true
      # Create a new raw cluster from mposts and remove them from the old one
      new_cluster = create_raw_cluster(:mposts=>mposts)
      main_cluster ||= new_cluster
      mposts.each {|mpost| cluster.mposts.delete(mpost)}
      break if cluster.mposts.empty? # all processed
      # Get a new set of related mposts from remaining mposts
      mposts = Set.new
      master_mpost = MeetMasterMpost.new
      cluster.mposts.each {|mpost|
        if (mposts.empty? || master_mpost.see_or_seen_by?(mpost))
          mposts << mpost
          master_mpost << mpost
        end
      }
    end
    # Get rid of the old cluster
    pop_cluster(cluster)
    return main_cluster
  end

  def move_to_processed_clusters(cluster)
    processed_clusters << cluster
    raw_clusters.delete(cluster)
  end

  # Return the earliest mpost
  def earliest_mpost
    earliest = nil
    block = Proc.new {|cluster|
      mpost = cluster.earliest_mpost
      if mpost 
        earliest  = mpost if (earliest == nil ||
                              earliest.trigger_time > mpost.trigger_time)
      end
    }
    raw_clusters.each(&block)
    processed_clusters.each(&block)
    return earliest
  end

end

class MeetRelation

  attr_accessor :graph, :pending, :seeded, :coeff_stats

  def initialize
    self.graph = Hash.new # relation graph, a sparse matrix represented by hash=>array
                          # missing means 0, -INF means mutually exclusion
    self.pending = Hash.new # to be processed nodes
    self.seeded = Hash.new # current seeded nodes, pointing to node coeff of seed graph
    self.coeff_stats = [0.0, 0.0] # seeded node coeff statistics [mean, sigma]
  end

  # Populate it from an existing meet preparing to add specified mposts
  def populate_from_meet_for_mposts(meet, mposts, &coeff_calculator)
    graph.clear; pending.clear; seeded.clear

    # Don't case relation between meet members, only fillin between mposts
    # and meet.mposts
    meet.mposts.each {|mpost| 
      #next unless mpost.active?
      graph[mpost] = Array.new
      # Fillin seeds with meet.mposts. Since meet can not be re-configured, they
      # all have infinite coeff values.
      seeded[mpost] = MeetProcesser.infinite_coeff
    }

    mposts.each {|mpost|
      graph_mpost = Array.new
      node_coeff = 0.0
      meet.mposts.each {|meet_mpost| 
        #next unless meet_mpost.active?
        if mpost.see_or_seen_by?(meet_mpost)
          coeff = coeff_calculator.call(mpost, meet_mpost)
          graph_mpost << [meet_mpost, coeff]
          node_coeff += coeff
        end
      }
      graph[mpost] = graph_mpost
      pending[mpost] = node_coeff
    }

    # Don't check coeff_stats, assign a mpost to it whenever possible
    self.coeff_stats = [0.0, 0.0]
  end

  # Populate from cluster (raw cluster only).
  def populate_from_cluster(cluster, &coeff_calculator)
    graph.clear; pending.clear; seeded.clear
    self.coeff_stats = [0.0, 0.0]
    
    # Fillin graph check each mpost pair, N^2 complexity
    mposts = cluster.mposts.to_a
    for from_index in (0...mposts.size)
      from_mpost = mposts[from_index]
      from = (graph[from_mpost] ||= Array.new)
      for to_index in ((from_index+1)...mposts.size)
        to_mpost = mposts[to_index]
        to = (graph[to_mpost] ||= Array.new)
        if from_mpost.see_or_seen_by?(to_mpost)
          coeff = coeff_calculator.call(from_mpost, to_mpost)
          from << [to_mpost, coeff]
          to << [from_mpost, coeff]
        end
      end
      pending[from_mpost] = 0.0
    end
    seed_first_node
  end

  def proceed(&seed_it)
    coeff_gain = 0.0
    skipped = Hash.new
    while !pending.empty? # loop until no more pending
      # Find a candidate from pending which best fit seeded
      candidate = (pending.max_by{|h| h[1]})[0] # use the meet with highest coeff
      break if !candidate # no more pending
      relations = graph[candidate]
      break if !relations # unlikely, candidate has no relation to seeded, who could

      gain, coeff = 0.0, 0.0
      exclusions = Set.new
      count_itself = true
      relations.each {|relation|
        relation_node, relation_coeff = *relation
        seeded_coeff = seeded[relation_node]
        if seeded_coeff # related to seeded
          if relation_coeff < 0.0 # mutual exclusive
            gain -= seeded_coeff
            exclusions << relation_node
          else 
            coeff += relation_coeff
            gain += relation_coeff
            if count_itself
              coeff += 1.0; gain += 1.0; count_itself = false
            end
          end
        end
      }

      if seed_it.call(gain, coeff, coeff_stats)
        promote_candidate(candidate, coeff, exclusions, skipped)
        coeff_gain += gain
      else
        skipped[candidate] = pending[candidate]
        pending.delete(candidate)
      end
    end
    return coeff_gain
  end

private

  def promote_candidate(candidate, coeff, exclusions, skipped)
    pending.delete(candidate)
    seeded[candidate] = coeff
    # Remove excluded nodes from seeded and DO NOT put back to pending (prmeet infiinte loop)
    seeded.delete_if {|node, node_coeff| exclusions.include?(node)}
    # Put the skipped back to pending, they might be accepted next time
    pending.merge!(skipped); skipped.clear
    update_pending_coeff(candidate, false)
    exclusions.each {|exclusion| update_pending_coeff(exclusion, true)}
    self.coeff_stats = seeded.values.mean_sigma
  end

  def update_pending_coeff(node, is_exclude)
    relations = graph[node]
    relations.each {|relation|
      relation_node, relation_coeff = *relation
      if pending.has_key?(relation_node)
        if (!is_exclude) # add coeff
          pending[relation_node] += relation_coeff
        else # substract coeff
          pending[relation_node] -= relation_coeff
        end
      end
    }
  end

  # Find the most likely one to seed for a group and seed it as the first node.
  # The most likely seeder is the one with highest coeff values. Also, we would like
  # to seed from a older node to avoid partial group if starting from a latest one.
  # Choose the oldeset one from top several candidate.
  def seed_first_node
    return if pending.empty?

    # Find the earliest one from top candidates (with top 20% highest coeff values)
    candidates = Array.new
    max_coeff = 0.0
    graph.each_pair {|node, relations|
      node_coeff = 1.0 # count itself
      relations.each {|relation|
        relation_node, relation_coeff = *relation
        node_coeff += relation_coeff if relation_coeff >= 0.0 # ignore exclusive nodes
      }
      max_coeff = node_coeff if (max_coeff < node_coeff)
      candidates << [node, node_coeff]
    }
    candidates = candidates.select {|candidate| candidate[1] >= max_coeff * 0.8}
    candidate = (candidates.max_by{|h| h[0].trigger_time})[0] # use the earliest node

    # Seed this candidate as the fist node
    coeff = 1.0 # count it self as coeff = 1.0
    pending.delete(candidate)
    seeded[candidate] = coeff
    update_pending_coeff(candidate, false)
    self.coeff_stats = seeded.values.mean_sigma
  end

end
