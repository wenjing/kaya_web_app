require 'active_support/core_ext'
require 'kaya_base'

class Mpost
  attr_accessor :id, :time, :lng, :lat, :lerror, :user, :peers, :leaks,
                :meet, :post_time, :mname, :duration, :strength, :loc_x, :loc_y

  def create
    return to_params(:time, :lng, :lat, :lerror).merge(
                       :devs=>((peers.concat(leaks).map {|peer| peer.dev}).join(",")),
                       :user_dev=>user.dev, :user_id=>user.id, :note=>meet.name)
  end

  def pending?
    return !id
  end
  def checked?
    return meet
  end
  def correct?
    return mname && meet && mname == meet.name
  end

  def display(indent)
    puts format("#{indent}#%d %s", user.id, user.name)
    puts format("#{indent} mname   : %s", mname)
    puts format("#{indent} time    : %+ds(%s) %+ds",
                (time-meet.time).round,
                (duration>0 ? format("%d", duration.round) : "--"),
                (post_time-meet.time).round)
    puts format("#{indent} location: lng=%f lat=%f error=%.2f", lng, lat, lerror)
    puts format("#{indent} device  : strength=%d x=%d y=%d", strength, loc_x, loc_y)
    puts format("#{indent} peers   : %d (%s)",
                peers.size, peers.map {|p| "##{p.id}"}.join(","))
    puts format("#{indent} leaks   : %d (%s)",
                leaks.size, leaks.map {|p| "##{p.id}"}.join(","))
  end
end

class MpostsBuilder
  @@trigger_time_offset_dist = [5, 1, 45]
  @@post_time_offset = (-90..0).to_a.concat([0.1, 0.2, 0.5, 1, 5, 10, 60, 600, 3600, 1.day.to_i])
  @@duplicate_post_offset = [-3000, 30]
  @@double_post_offset = [-3000, 30]
  @@resend_post_offset = [-3000, 30]
  @@resend_lerror_ratio = [0.0, 0.6]
  @@device_signal_duration = [8, 12]
  @@device_always_on_prob = [0.3]
  @@device_strength_dist = [10, 6, 30]
  @@latlng_per_lerror = 3.5e-6
  @@min_peers_ratio = [0.3, 0.6]
  @@max_peers_ratio = [0.8, 1.0]
  @@max_leaks_ratio = [0.0, 0.2]

  def self.build(meet)
    meet.mposts = Array.new
    loc = meet.loc
    area_size = meet.users.size * loc.peer_distance**2
    meet.users.each {|user|
      trigger_time = meet.time + @@trigger_time_offset_dist.random_dist
      device_duration = @@device_always_on_prob.random_prob == 0 ?
                          -1.0 : @@device_signal_duration.random
      device_strength = @@device_strength_dist.random_dist.ceil
      loc_x, loc_y = meet.x_range.random.floor, meet.y_range.random.floor
      double_post_offset = 0.0
      while double_post_offset >= 0.0
        mpost = Mpost.new
        mpost.user = user
        mpost.meet = meet;
        mpost.lerror = loc.lerror.ceil
        ll_error = mpost.lerror*@@latlng_per_lerror
        mpost.lng = loc.lng+[-ll_error,ll_error].random
        mpost.lat = loc.lat+[-ll_error,ll_error].random
        mpost.time = trigger_time + double_post_offset
        post_time_offset = @@post_time_offset.random.at_least(0.0)
        mpost.post_time = mpost.time + post_time_offset
        mpost.duration = device_duration
        mpost.strength = device_strength
        mpost.loc_x = loc_x
        mpost.loc_y = loc_y
        meet.mposts << mpost

        duplicate_post_offset = @@duplicate_post_offset.random
        meet.mposts << duplicate_post(mpost, duplicate_post_offset) if duplicate_post_offset > 0.0

        resend_post_offset = @@resend_post_offset.random
        meet.mposts << resend_post(mpost, resend_post_offset,
                                   @@resend_lerror_ratio.random) if resend_post_offset > 0.0

        double_post_offset = @@double_post_offset.random
      end
      meet.mposts << double_post(mpost, double_post_offset) if double_post_offset > 0.0
    }
    meet.mposts.each {|mpost| check_peers(mpost, meet.mposts)}
    return meet.mposts
  end

  def self.check_peers(mpost, mposts)
    mpost.peers = []
    users = mpost.meet.users
    return unless users.size > 1

    peers = Array.new
    hiden_peers = Array.new
    mposts.each {|peer|
      if mpost.user != peer.user
        distance = sqrt((mpost.loc_x-peer.loc_x)**2+(mpost.loc_y-peer.loc_y)**2)
        user_range = (mpost.time.to_r..(mpost.time+mpost.duration).to_r)
        peer_range = (peer.time.to_r..(peer.time+mpost.duration).to_r)
        if ((mpost.strength+peer.strength)/2 >= distance &&
            mpost.duration < 0 || peer.duration < 0 || user_range.overlap(peer_range))
          peers << peer.user
        else
          hiden_peers << peer.user
        end
      end
    }
    min_peers = ((users.size-1) * @@min_peers_ratio.random).floor.at_least(1)
    max_peers = ((users.size-1) * @@max_peers_ratio.random).ceil.at_least(1)
    if peers.size < min_peers
      peers.concat(hiden_peers.first(min_peers-peers.size))
    elsif peers.size > max_peers
      peers.slice!(0...(peers.size-max_peers))
    end
    mpost.peers = peers
  end

  def self.check_leaks(mpost, mposts)
    mpost.leaks = []
    users = mpost.meet.users
    leaks = Array.new
    mposts.each {|leak|
      if mpost.meet != leak.meet 
        distance = sqrt((mpost.loc_x-leak.loc_x)**2+(mpost.loc_y-leak.loc_y)**2)
        user_range = (mpost.time.to_r..(mpost.time+mpost.duration).to_r)
        leak_range = (leak.time.to_r..(leak.time+mpost.duration).to_r)
        if ((mpost.strength+leak.strength)/2 >= distance &&
            (mpost.duration < 0 || leak.duration < 0 || user_range.overlap(leak_range)))
          leaks << leak.user
        end
      end
    }
    max_leaks = (users.size * @@max_leaks_ratio.random).ceil
    if leaks.size > max_leaks
      leaks.slice!(0...(leaks.size-max_leaks))
    end
    mpost.leaks = leaks
  end

  def self.duplicate_post(mpost, time_offset)
    duplicate_mpost = mpost.dup
    duplicate_mpost.post_time += time_offset
    return duplicate_mpost
  end

  def self.resend_post(mpost, post_time_offset, lerror_ratio)
    resend_mpost = mpost.dup
    resend_mpost.post_time += post_time_offset
    resend_mpost.lerror = (mpost.lerror * lerror_ratio).ceil
    ll_error = resend_mpost.lerror*@@latlng_per_lerror
    resend_mpost.lng = mpost.meet.loc.lng+[-ll_error,ll_error].random
    resend_mpost.lat = mpost.meet.loc.lat+[-ll_error,ll_error].random
    return resend_mpost
  end

end
