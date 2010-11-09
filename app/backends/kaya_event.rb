# This is main meet processing class.
# It is supposedly used as singleton class which will keep necessary data remain in memory.
# It implements and hosts KayaTQueue module which allows outside objects to use queued mpost
# processing and also a timer to periodly invoke a certain method.
# It shall be initialized first, probally at the time when it is first invoked. When it is
# initialied, KayaTQueue is also created and started ready to be used rightway.

require 'kaya_base'
require 'kaya_tqueue'

# Required functions in Mpost:
#   trigger_time: already converted into utc, has to be reconverted back to local time for display
#   is_processed?
#   see?(another_mposts)
#   be_seen?(another_mposts)
#   see_or_be_seen?(another_mposts)
#   merge_devs(devs)
#
# Required functions in Meet:
#   mposts
#   extract_information
#   occured_earliest
#   occured_latest
#   indexed by time


# Use database to record history to be replayed for debugging purpose
# Has to index basing on :time
class MpostRecord < ActiveRecord::Base

  def initialize
    self.mpost_id = nil
    self.time = nil
  end

end


# Since KayaMeetProcesser is a singleton, it can not be used by delayed job (DJ)
# directly. Use this wrapper to bridge the gap. This wrap will be the one to pass
# on jobs and call function in KayaMeetProcesser singleton.
# Usage:
#   KayaMeetWrapper.new.delayed.process_mpost(mpost)
#   KayaMeetWrapper.new.delayed.setup_parameters(options)
#   KayaMeetWrapper.new.delayed.start_record(1.day)
#   KayaMeetWrapper.new.delayed.start_replay(Time.now-2.days, Time.now)
class KayaMeetWrapper

  def initialize
  end

  def process_mpost(mpost)
    process_mposts([mpost])
  end

  def process_mposts(mposts)
    meet_processer = KayaMeetProcessor.meet_processer
    meet_processer.queue.process_mpost(mpost)
  end

  def setup_parameters(options)
    meet_processer = KayaMeetProcessor.meet_processer
    meet_processer.queue.setup_parameters(options)
  end

  def start_record(duration)
    meet_processer = KayaMeetProcessor.meet_processer
    meet_processer.queue.start_record(duration)
  end

  def stop_record
    meet_processer = KayaMeetProcessor.meet_processer
    meet_processer.queue.stop_record(duration)
  end

  def start_replay(from_time, end_time)
    from_time = from_time.getutc if from_time
    to_time = to_time.getutc if to_time
    meet_processer = KayaMeetProcessor.meet_processer
    meet_processer.queue.start_replay(from_time, end_time)
  end

  # Terminate replay, called asynchronously
  def stop_replay
    meet_processer = KayaMeetProcessor.meet_processer
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


class KayaMeetProcessor

  include KayaTQueue

  # Make sure it only accept singleton
  private_class_method :new

  #tqueue_asynchronously :mpost_processer
  # Do not specify for meet_processer, because it is called internally
  # inside mpost_processer. We have to very careful not to queue a method
  # inside a queued method.
  # However, it is required to be queued for timer. Call queue.method directly.

  @@meet_processer      = nil  # singelton meet processer
  @@timer_interval       = 1.0  # timer internal
  @@meet_duration_tight = 20   # fully counted if 2 mposts are trigger within time period
  @@meet_duration_loose = 60   # discounted within time period, different meets if exceed
  # Process a raw cluster if its oldest mpost exceed limit AND has not receive new mpost
  # for a while
  @@hot_time_idle        = 5.0
  @@hot_time_threshold   = 15.0
  @@hot_time_limit       = 30.0 # force to process a raw cluster if oldest mpost exceed limit
  @@cold_time_limit      = 3600.0  # freeze processe clusters older than limit
  # Shall be much larger than meet_duration_loose, 10 mins
  @@cold_time_margin = [@@meet_duration_loose*5, 600.0].max
  # Exponentially decay starting from duration_tight to durantion_loose to 10% of original value
  @@delta_time_discounts = (0..100).map {|x| ((100.0-x)**2/10000.0+1.0/9.0)/(1.0+1.0/9.0)}
  @@infinite_coeff = 1000000.0  # infinite coeff value
  @@uni_connection_discount = 0.8 # discount if A see B but B does not see A
  # A member's coeff to the group can not be less than 20% of average
  @@coeff_vs_avg_threshold = 0.2

  def self.meet_processer
    if !@@meet_processer
      @@meet_processer = KayaMeetProcessor.new
      @@meet_processer.tqueue_start(@@timer_interval) {
        @@meet_processer.queue.process_meets(true)
      }
    end
    return @@meet_processer
  end

  def setup_paramters(options)
    @@timer_interval       = options[:timer_interval]       if options[:timer_interval]
    @@meet_duration_tight = options[:meet_duration_tight] if options[:meet_duration_tight]
    @@meet_duration_loose = options[:meet_duration_loose] if options[:meet_duration_loose]
    @@host_time_idle       = options[:host_time_idle]       if options[:host_time_idle]
    @@hot_time_threshold   = options[:hot_time_threshold]   if options[:hot_time_threshold]
    @@cold_time_limit      = options[:cold_time_limit]      if options[:cold_time_limit]
    @@cold_time_margin     = options[:cold_time_margin]     if options[:cold_time_margin]
    @@delta_time_disconts  = options[:delta_time_disconts]  if options[:delta_time_disconts]
    @@infinite_coeff       = options[:infinite_coeff]       if options[:infinite_coeff]
    @@uni_connection_discount = options[:uni_connection_discount] if options[:uni_connection_discount]
    @@coeff_vs_avg_threshold = options[:coeff_vs_avg_threshold] if options[:coeff_vs_avg_threshold]
  end

  def initialize
    @time_now = nil
    @last_meets_process_time = nil
    @cold_time = 0.0 # cold_time does not automatically start from limit, it grow from 0
    @meet_pool = KayaMeetPool.new

    @record_start_time = nil
    @record_end_time = nil
    @replay_start_time = nil
    @replay_end_time = nil
    @history_mutex = Mutex.new
  end

  # Mpost processer, right now, queued from controller directly.
  # In furture, this processer will operate on seperate machine outside controller.
  # Instead of being called from controller directly, controller passes it to an external
  # mpost queue and dispatch to backend machines. The backend machine running this
  # processer will use main thread to read incoming external mposts and queue proper
  # method for further processing.
  # This is relatively lightweight comparing with process_meets. It basically pools the
  # incoming mposts and passes it onto process_meets.
  def process_mposts(mposts, record_time_now=nil)
    @time_now = Time.now.getutc # centralized standard now time
    @time_now = record_time_now if record_time_now
    debug(:processer, 1, "%s %s %s at %s",
          (record_time_now ? "receive" : "replay"), pluralize(mposts.size, "mpost"),
          mposts.join(","), @time_now)
    record_mposts(mpost)
    mposts.each {|mpost_id|
      begin
        mpost = Mpost.find_by_id(mpost_id)
        process_mpost_core(mpost)
      rescue
        # Don't let database exception ruins it. Let it pass silently
        error("Mpost ? not found in database", mpost_id)
      end
    }
    process_meets # shall we call process_meets for every new mpost?
  end

  # Heavyweight, process pending mposts and assign meet to them.
  # Save to db if necessary.
  def process_meets(from_timer=false, record_time_now=nil)
    # If it is triggered from timer, make sure enough time has passed since last
    # time it is called
    if is_timer_interval_ok?(from_timer)
      if from_timer
        @time_now = Time.now.getutc
        @time_now = record_time_now if record_time_now
      end
      debug(:processer, 1, "%s meet processing %sat %s",
            (record_time_now ? "receive" : "replay"),
            (from_timer ? "from timer" : ""), @time_now)
      record_mposts(nil)
      process_meets_core()
    end
  end

  def start_record(duration)
    @record_start_time, @record_end_time = nil, nil
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
      debug(:record, 1, "stop record at %s", Time.now.getutc)
      start_record(nil)
    end
  end

  def start_replay(start_time, end_time)
    @replay_start_time, @replay_end_time = nil, nil
    @replay_terminated = false
    if (start_time && !end_time || (start_time < end_time))
      stop_record
      @replay_start_time = start_time
      @replay_end_time = end_time ? end_time : Time.now.getutc
      @tqueue_timer.pause
      debug(:replay, 1, "start recording from %s to %s",
            @record_start_time, @record_end_time)
      records = MpostRecord.where(":timer >= ? AND :time <= ?",
                                        @replay_start_time, @replay_end_time)
      debug(:replay, 2, "replaying %d %s",
            records.size, pluralize(records.size, "record"))
      for record in records
        # Check if it is stopped (asynchronously)
        @history_mutex.safe_lock {stop_replay if @replay_terminated}
        break unless is_replaying?
        if record.mpost_id
          process_mposts([record.mpost_id], record.time)
        else
          process_meets(false, record.time)
        end
      end
      stop_replay
      @tqueue_timer.resume
      debug(:replay, 2, "done replaying")
    end
  end

  def stop_replay
    if is_replaying?
      debug(:replay, 1, "stop replay at %s", Time.now.getutc)
      start_replay(nil, nil)
    end
  end

  def terminate_replay
    @replay_mutex.safe_lock {@replay_terminated = true}
  end

  def is_recording?
    return @record_start_time && @record_end_time
  end

  def is_replaying?
    return @replay_start_time && @replay_end_time
  end

private

  def record_mposts(mpost_ids)
    # Can not record during replay
    if (!is_replaying? && @record_start_time)
      if (@time_now >= @record_start_time && @time_now <= @record_end_time)
        if mpost_ids
          mpost_ids.each {|mpost_id|
            MpostRecord.create(:mpost_id=>mpost_id, :time=>@time_now)
          }
        else
          MpostRecord.create(:mpost_id=>nil, :time=>@time_now)
        end
      else
        # Record complete, reset start and end time
        stop_record
      end
    end
  end

# Trivial helper functions
 
  def is_timer_interval_ok?(from_timer)
    curr_time = Time.now.getutc
    if (from_timer &&
        @last_meets_process_time &&
        (curr_time-@llast_meets_process_time) < @@timer_interval/2.0)
      return false
    end
    @last_meets_process_time = curr_time
    return true
  end

  def mpost_time_from_now(mpost)
    return mpost ? [@time_now-mpost.trgger_time, 0.0].max : 0.0
  end

  #def meet_time_from_now(meet)
  #  return meet ? [mpost_time_from_now(meet.youngest_mpost),
  #                  mpost_time_from_now(meet.oldest_mpost)],
  #                 [0.0, 0.0]
  #end

  def shall_process_cluster?(cluster)
    return !cluster.is_processed? &&
           (mpost_time_from_now(cluster.youngest_mpost) > @@hot_time_idle &&
            mpost_time_from_now(cluster.oldest_mpost) > @@hot_time_threshold) ||
           mpost_time_from_now(cluster.oldest_mpost) > @@hot_time_limit
  end

  def delta_time_discount(time_delta)
    time_delta = (time_delta-@@meet_duration_tight)/
                      (@@meet_duration_loose-@@meet_duration_tight)
    return time_delta <= 0.0 ? 1.0 :
           time_delta >  1.0 ? 0.0 :
              @@delta_time_discounts[time_delta*(@@delta_time_discounts.size-1)]
  end

  # Must be only in database, skip checking on memory. No risk to cause
  # database and memory out-of-sync
  def is_definitely_cold?(mpost)
    return mpost_time_from_now(mpost) > @cold_time + @@cold_time_margin
  end

  # Must be on memory (though may be also in database), skip checking database
  # even found no match on memory. After it is processed, memory and database will
  # be in-sync.
  def is_definitely_warm?(mpost)
    return mpost_time_from_now(mpost) < @cold_time - @@cold_time_margin
  end

  def is_cluster_cold?(cluster)
    return cluster.is_processed? &&
           mpost_time_from_now(cluster.yougest_mpost) > @@cold_time_limit
  end

  def assign_mposts_to_meet(mposts, meet)
    mposts.each {|mpost| meet.mposts << mpost}
    meet.extract_information
    meet.save
  end

  def assign_mpost_to_meet(mpost, meet)
    meet.mposts << mpost
    meet.extract_information
    meet.save
  end

  def create_meet_from_mposts(mposts)
    meet = Meet.new
    assign_mposts_to_meet(mposts, meet)
    return meet
  end

  def create_meet_from_mpost(mpost)
    meet = Meet.new
    assign_mpost_to_meet(mpost, meet)
    return meet
  end

  def get_meets_around_mpost(mpost)
    return get_meets_by_range(mpost.trigger_time - @@meet_duration_loose,
                               mpost.trigger_time + @@meet_duration_loose)
  end

  def get_meets_by_range(from, to)
    return Meet.where(":occured_latest => ? AND :occured_earliest <= ?", from, to)
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
    coeff = (connect == 2 ? 1.0 : @@uni_connect_discount)
    coeff *= delta_time_discount(time_delta)
    return coeff
  end

  def coeff_calculator(from, to)
    time_delta = (member.trigger_time-group_member.grigger_time).abs
    connect = 0
    connect += 1 if from.see?(to)
    connect += 1 if to.see?(from)
    return calculate_coeff(connect, time_delta)
  end

  # Choose the best meet and assign the mpost to it.
  # Return the assigned meet.
  def assign_mpost_to_meets_if_possible(mpost, meets)
    candidates = Hash.new
    meets.each {|meet|
      relation = KayaRelation.new
      relation.populate_from_meet_for_mposts(meet, [mpost], method(:coeff_calculator))
      coeff_gain = relation.proceed(method(:pass_coeff_criteria_simple?))
      if (coeff_gain > 0.0)
        candidates[meet] = [coeff_gain, meet.mposts.size]
      end
    }
    return nil if candidates.empty?
    # Select the best one and assign to it
    meet = (candidates.max_by {|h| h[1]})[0] # use the meet with highest score
    assign_mpost_to_meet(mpost, meet)
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

  def assign_mpost_to_cold_meets(mpost)
    # First, get all candidate meets which this mpost could assigned to
    meets = get_meets_around_mpost(mpost)
    if !assign_mpost_to_meets_if_possible(mpost, meets)
      # Create a orphan meet and assigned this mpost as solo member
      create_meet_from_mpost(mpost)
    end
  end

  def process_raw_clusters
    # Anything marked skipped, will no longer be processed this next
    skipped_clusters = Set.new
    while !@meet_pool.raw_cluster.empty?
      @envet_pool.raw_clusters.each {|cluster|
        if skipped_clusters.include?(cluster)
          # Skip it
        elsif !shall_process_cluster?(cluster)
          # Too early, wait until it cool down a bit
          skipped_clusters << cluster
        else
          relation = KayaRelation.new
          relation.populate_from_clusers(cluster, method(:coeff_calculator))
          coeff_gain = relation.proceed(method(:pass_coeff_criteria_normal?))
          if coeff_gain > 0.0
            mposts = relation.seeded.keys
            cluster = @meet_pool.split_clusters(mposts, cluster)
            cluster.meet = create_meet_from_mposts(mposts)
            @meet_pool.move_to_processed_clusters(cluster)
          else
            # Something wrong, skip processing it this time
            skipped << cluster
          end
        end
      }
    end
  end

  def process_pending_mposts
    @meet_pool.pending_mposts.each {|mpost|
      if mpost.is_processed?
        # Shall we do something here?
      elsif is_definitely_cold?(mpost) # must not in meet_pool, check db directly
        assign_mpost_to_cold_meets(mpost)
      elsif is_definitely_warm?(mpost)
        if !assign_mpost_to_clusters_if_possible(mpost)
          # Create a new cluster and attach the mpost to it
          @meet_pool.create_raw_cluster(:mpost=>mpost)
        end
      elsif !assign_mpost_to_clusters_if_possible(mpost)
        # Rejected by meet_pool, check db as last resort
        assign_mpost_to_cold_meets(mpost)
      end
    }
    @meet_pool.pending_mposts.clear
  end

  # Remove cold meets from pool.
  # Also update cold_time to oldest mpost_time_from_now still in pool.
  def release_cold_meets
    # Eliminate processed clusters and corresponding mpost from pool if their
    # youngest time_from_now is larger than cold_time_limit
    @meet_pool.processed_clusters.each {|cluster|
      if is_cluster_cold?(cluster)
        meet_pool.pop_cluster(cluster)
      end
    }
    @cold_time = mpost_time_from_now(meet_pool.oldest_mpost)
  end

  def process_mpost_core(mpost)
    @meet_pool.pending_mposts << mpost
  end

  def process_meets_core
    @meet_pool.dump_debug(:pool_before)
    process_pending_mposts
    @meet_pool.dump_debug(:pool_cluster)
    process_raw_clusters
    @meet_pool.dump_debug(:pool_cold)
    release_cold_meets
    @meet_pool.dump_debug(:pool_after)
  end

end

class KayaMasterMpost

  attr_accessor :self_mpost, :device_mpost

  def initilize
    @self_mpost = Mpost.new
    @device_mpost = Mpost.new
  end

  def <<(mpost)
    @self_mpost.merge_devs([mpost.user_dev])
    @device_mpost.merge_devs(mpost.devs)
  end

  def see_or_be_seen?(mpost)
    return @self_mpost.be_seen?(mpost) || @device_mpost.see?(mpost)
  end

end

class KayaCluster

  attr_accessor :meet, :youngest_mpost, :older_mpost, :mposts, :master_mpost

  def initialize(optionts)
    self.meet = nil
    self.youngest_mpost = nil
    self.oldest_mpost = nil
    self.mposts = Set.new
    self.master_mpost = Mpost.new
    if options[:mpost]
      self << options[:mpost]
    end
    if options[:mposts]
      options[:mposts].each {|mpost|
        self << options[:mpost]
      }
    end
  end

  def is_processed?
    return meet != nil
  end

  def <<(mpost)
    self.mposts << mpost
    youngest_mpost = mpost if (youngest_mpost == nil ||
                                   youngest_mpost.trigger_time > mpost.trigger_time)
    oldest_mpost   = mpost if (oldest_mpost == nil ||
                                   oldest_mpost.trigger_time < mpost.trigger_time)
    master_mpost << mpost
  end

  def attachable?(to)
    master_mpost.see_or_be_seen?(to)
  end

  def size
    return mposts.size
  end

end


class KayaMeetPool

  attr_accessor :raw_clusters, :processed_clusters, :pending_mposts

  def initialize
    self.raw_clusters       = Set.new
    self.processed_clusters = Set.new
    self.pending_mposts   = Set.new
  end

  def dump_debug(type)
    if is_debug?(type, 1)
      debug(type, 1, "meet pool information:")
      nondebug("\thas %d %s", 
               raw_cluster.size, pluralize(raw_clusters.size, "raw_cluster"))
      nondebug("\thas %d %s", 
               processed_cluster.size, pluralize(processed_clusters.size, "processed_cluster"))
      nondebug("\thas %d %s", 
               pending_mposts.size, pluralize(pending_mposts.size, "pending_mpost"))
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
        # :meet, :youngest_mpost, :older_mpost, :mposts, :master_mpost
        nondebug("\tcluster %d:", index)
        nondebug("\t  %s with %d %s from %s to %s",
                 (cluster.is_procesed? ? "processed" : "raw"),
                 cluster.mposts.size, 
                 pluralize(cluster.mposts.size, "mpost"),
                 (cluster.oldest_mpost?cluster.oldest_mpost.trigger_time:"---"),
                 (cluster.youngest_mpost?cluster.youngest_mpost.trigger_time:"---"))
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
        nondebug("\tmpost %d:", index)
        nondebug("\t  %s %d with %d %s triggered at %s",
                 (mpost.is_procesed? ? "processed" : "raw"),
                 mpost.devs.size, 
                 pluralize(mpost.devs.size, "device"),
                 mpost.trigger_time)
        index += 1
      }
    end
  end

  # Return hash of meet=>processed_cluster
  def meets
    meets = Hash.new
    @meet_pool.processed_cluster.each {|cluster|
      meets[cluster.meet] = cluster
    }
    return meets
  end

  def create_raw_cluster(options)
    cluster = KayaCluster.new(options)
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

  def merge_cluster(cluster1, cluster2)
    if cluster1.size > cluster.size
      from, to = cluster2, cluster1
    else
      from, to = cluster1, cluster2
    end
    from.mposts.each {|messsage| to << mpost}
    pop_cluster(from)
    return to
  end

  # Add mpost to clusters, merge if necessary.
  # Return false if fails.
  def add_to_raw_clusters_if_possible(mpost)
    attachable_clusters = Set.new
    raw_clusters.each {|cluster|
      if cluster.attachable?(mpost)
        attachable_clusters << cluster
      end
    }
    return false if attachable_clusters.empty?
    to_cluster = nil
    attachable_clusters.each {|cluster|
      to_cluster ||= cluster
      if to_cluster != cluster
        to_cluster = merge_cluster(to_cluster, cluster)
      end
    }
    to_cluster << mpost
    return true
  end

  # Split mposts from cluster and create new clusters.
  # Return main cluster created from specified mposts
  def split_clusters(mposts, cluster)
    return nil if mposts.empty?
    # The mposts must be all related to each other, create a cluster from them
    # and then proceed to remaining ones until all are processed
    while true
      # Create a new raw cluster from mposts and remove them from the old one
      main_cluster = create_raw_cluster(:mposts=>mposts)
      mposts.each {|mpost| cluster.mposts.delete(mpost)}
      break if !cluster.mposts.empty? # all processed
      # Get a new set of related mposts from remaining mposts
      mposts = Set.new
      master_mpost = KayaMasterMessge.new
      cluster.mposts.each {|mpost|
        if (mposts.empty? || master_mpost.see_or_be_seen?(mpost))
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

end

class KayaRelation

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
      graph[mpost] = Array.new
      # Fillin seeds with meet.mposts. Since meet can not be re-configured, they
      # all have infinite coeff values.
      seeded[mpost] = KayaMeetProcessor.infinite_coeff
    }

    messgaes.each {|mpost|
      graph_mpost = Array.new
      node_coeff = 0.0
      meet.mposts.each {|meet_mpost| 
        if mpost.see_or_be_seen?(meet_mpost)
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
    for from_index in (0..mposts.size)
      from_mpost = mposts[from_index]
      from = (graph[from_mpost] ||= Array.new)
      for to_index in ((from_index+1)..mposts.size)
        to_mpost = mposts[to_index]
        to = (graph[to_mpost] ||= Array.new)
        if from_mpost.see_or_be_seen?(to_mpost)
          coeff = coeff_calculator.call(from_mpost, to_mpost)
          from << [to_mpost, coeff]
          to << [to_mpost, coeff]
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
      break if !relation # unlikely, candidate has no relation to seeded, who could

      gain, coeff = 0.0, 0.0
      excludes = Array.new
      count_itself = true
      relations.each {|relation|
        relation_node, relation_coeff = *relation
        seeded_coeff = seeded[relation_node]
        if seeded_coeff # related to seeded
          if relation_coeff < 0.0 # mutual exclusion
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
    seeded.delete_if {|node, node_coeff| exclusions.has_key?(node)}
    # Put the skipped back to pending, they might be accepted next time
    pending.merge(skipped); skipped.clear
    update_pending_coeff(candidate, false)
    exclusions.each {|exclusion| update_pending_coeff(exclusion, true)}
    self.coeff_stats = seeded.values.mean_sigma
  end

  def update_pending_coeff(node, is_exclude)
    relations = graph[node]
    relations.each {|relation|
      relation_node, relation_coeff = *relation
      if pending.hasKey?(relation_node)
        if (!is_exclude) # add coeff
          pending[relation_node] += relation_coeff
        else # substrct coeff
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
    return unless pending.empty?

    # Find the oldest one from top candidates (with top 20% highest coeff values)
    candidates = Array.new
    max_coeff = 0.0
    graph.each_pair {|node, relations|
      node_coeff = 0.0
      relations.each {|relation|
        relation_node, relation_coeff = *relation
        node_coeff += relation_coeff
      }
      max_coeff = node_coeff if (max_coeff < node_coeff)
      candidates << [node, node_coeff]
    }
    candidates = candidates.select {|candidate| candidate[1] >= max_coeff * 0.8}
    candidate = (candidates.max_by{|h| mpost_time_from_now(h[0])})[0] # use the oldest node

    # Seed this candidate as the fist node
    coeff = 1.0 # count it self as coeff = 1.0
    pending.delete(candidate)
    seeded[candidate] = coeff
    update_pending_coeff(candidate, false)
    self.coeff_stats = seeded.values.mean_sigma
  end

end
