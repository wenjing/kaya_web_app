$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'
load 'test_base.rb'
load 'test_user.rb'
load 'test_loc.rb'
load 'test_mpost.rb'
load 'test_meet.rb'

class StressTest < TestBase
  @@marker = "_stress_test_"
  #@@meet_count = 300
  #@@user_count = 100
  @@meet_count = 100
  @@user_count = 50
  @@meet_interval = 30 # meet interval to prevent mpost conflict
  @@meet_period = 5 # time lag between first and last mposts of same meet
  def self.setting(meet_count, user_count, root_url)
    @@meet_count = meet_count
    @@user_count = user_count
    TestBase::root_url = root_url
  end
  def self.test_locally
    TestBase::root_url = "http://localhost:3000/"
  end
  def self.destroy_all # all record created here carry _features_test_ marker
    super(/.*#{@@marker}.*/)
  end
  def self.create_meets
    meets = []
    start_time = 0
    ii = 0
    while meets.size < @@meet_count
      users = @@users.shuffle
      start_time += @@meet_interval
      while (!users.empty? && meets.size < @@meet_count)
        meet = TestMeet.new
        ii += 1
        meet.name = "meet" + @@marker + ii.to_s;
        meet.time = start_time + (0..@@meet_interval-2*@@meet_period).to_a.rand
        meet.loc = @@locations.rand
        user_count = [1, 3, 10].random_dist.floor
        meet.users = users.slice!(0, user_count)
        meet.users.each {|user| user.meets << meet}
        meets << meet
      end
    end
    return meets
  end
  def self.create_mposts(meets)
    mposts = []
    meets.each {|meet| meet.users.each {|user|
      mpost = TestMpost.new
      mpost.meet = meet
      mpost.user = user
      peer_count = [5, 10, 50].random_dist.floor
      mpost.peers = meet.users.reject {|v| v == user}.shuffle.slice(0, peer_count)
      mpost.post_time = meet.time + (0..@@meet_period).to_a.rand
      loc = meet.loc
      mpost.lerror = loc.lerror.ceil
      ll_error = mpost.lerror*3.5e-6
      mpost.lng = loc.lng+[-ll_error,ll_error].random
      mpost.lat = loc.lat+[-ll_error,ll_error].random
      meet.mposts << mpost
      mposts << mpost
    }}
    return mposts
  end
  def self.prepare
    @@locations = LocationsBuilder::build(nil, nil)
    @@users = UsersBuilder::build_and_signin
    @@users = @@users.shuffle.slice(0..@@user_count)
    return true
  end
  # Run stress test
  def self.run(dry=false)
    puts "Stress ..."
    prepare
    # Create and issue mposts
    meets = create_meets
    mposts = create_mposts(meets)
    mposts.sort_by! {|v| v.post_time}
    duration = mposts.last.post_time - mposts.first.post_time
    start_time = Time.now
    puts "Starting at #{start_time}"
    puts "  #{mposts.size} mposts #{meets.size} meets in #{duration} seconds (#{format("%.2f mp/s %.2f m/s", mposts.size.to_f/duration, meets.size.to_f/duration)})"
    puts "  Expected finish at #{start_time + duration}"
    ii = 0
    while ii < mposts.size
      mpost = mposts[ii]
      offset_time = Time.now - start_time
      if offset_time < mpost.post_time
        sleep 1
        next
      end
      ii += 1
      mpost.time = start_time.getutc + mpost.post_time
      user = mpost.user
      if !dry
        res = rc_resource("mposts", user)
        rsp = res.post_json(mpost.create); should_rsp(rsp)
        mpost.id = rsp.body_json("mpost")["id"].to_i unless !rsp.ok?
        print "." if ii % 100 == 1
      else
        # Check issued mposts content without acutally issuing them
        print "\r#{(Time.now-start_time).floor}>#{mpost.post_time} #{mpost.create}"
      end
    end
    puts ""
    puts "  Finished posting at #{Time.now.utc}"
    return true
  end
end
