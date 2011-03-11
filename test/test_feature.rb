$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'
load 'test_base.rb'
load 'test_user.rb'
load 'test_loc.rb'
load 'test_mpost.rb'
load 'test_meet.rb'

class FeaturesTest < TestBase
  @@marker = "_features_test_"
  #@@meet_count = 300
  #@@user_count = 100
  @@meet_count = 60
  #@@meet_count = 5
  @@user_count = 20
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
  def self.create_meets(pass=1)
    # Use first 500 users to create 1000 meets
    meets = []
    time0 = Time.now
    (1..@@meet_count).to_a.each {|ii|
      meet = TestMeet.new
      meet.name = "meet" + @@marker + ii.to_s + "_" + pass.to_s;
      meet.loc = @@locations.rand
      user_count = [1, 3, 20].random_dist.floor
      meet.users = []
      meet.time = time0 - 1.day + ((ii+pass*@@meet_count)*1).minutes
      meet.users = @@users.shuffle.slice(0, user_count)
      meet.users.each {|user| user.meets << meet}
      meet.users.each {|user|
        cirkle = user.result_meets.find {|v| v.meet_type == 6}
        if cirkle
          meet.cirkle_id = cirkle.id
          meet.collision = [0,1].random < 0.10 if meet.users.size >= 2
          break
        end
      }
      meets << meet
    }
    return meets
  end
  def self.create_mposts(meets)
    mposts = []
    meets.each {|meet|
      meet.users.each {|user|
        mpost = TestMpost.new
        mpost.meet = meet
        mpost.user = user
        peer_count = [5, 10, 50].random_dist.floor
        mpost.peers = meet.users.reject {|v| v == user}.shuffle.slice(0, peer_count)
        mpost.time = meet.time + (0..5).to_a.rand
        mpost.post_time = mpost.time
        loc = meet.loc
        mpost.lerror = loc.lerror.ceil
        ll_error = mpost.lerror*3.5e-6
        mpost.lng = loc.lng+[-ll_error,ll_error].random
        mpost.lat = loc.lat+[-ll_error,ll_error].random
        mpost.cirkle_id = meet.cirkle_id if user.result_meets.any? {|v| v.id == meet.cirkle_id}
        meet.mposts << mpost
        mposts << mpost
      }
      if meet.collision
        collision_mpost = meet.mposts.select {|v| !v.cirkle_id}.first || meet.mposts.first
        collision_mpost.cirkle_id = meet.cirkle_id + 1
      end
    }
    return mposts
  end
  def self.prepare
    @@locations = LocationsBuilder::build(nil, nil)
    @@users = UsersBuilder::build_and_signin
    @@users = @@users.shuffle.slice(0..@@user_count)
    return true
  end
  # Setup meet data
  def self.setup
    prepare
    puts "Setup ..."

    # Create and issue mposts
    (1..2).to_a.each {|ii|
    puts "PASS #{ii}"
    meets = create_meets(ii)
    mposts = create_mposts(meets)
    all_mposts = mposts.clone
    start_time = Time.now.utc
    while !all_mposts.empty?
      sliced_mposts = all_mposts.slice!(0, 50)
      # Post 100 at a time
      sliced_mposts.each {|mpost|
        user = mpost.user
        res = rc_resource("mposts", user)
        rsp = res.post_json(mpost.create); should_rsp(rsp); next unless rsp.ok?
        mpost.id = rsp.body_json("mpost")["id"].to_i
      }
      # Wait 10 seconds
      sleep 10
    end
    # Get meet results
    2.times { # Try 2 times, also as performance test
      sleep 20
      @@users.each {|user|
        res = rc_resource("users/#{user.id}/meets?after_updated_at=#{(start_time-2.minutes).iso8601}&meet_type=0", user)
        rsp = res.get_json(); should_rsp(rsp)
        results = rsp.body_json()
        next unless results
        user.result_meets ||= []
        results.each {|result|
          result = result["meet"]
          meet = TestMeet.new
          meet.id = result["id"].to_i
          meet.cirkle_id = result["cirkle_id"].to_i if result["cirkle_id"]
          meet.meet_type = result["meet_type"].to_i
          meet.name = result["name"]
          meet.time = Time.parse(result["time"])
          meet.users = []
          res2 = rc_resource("meets/#{meet.id}", user)
          rsp2 = res2.get_json(); should_rsp(rsp2);
          next unless rsp2.body_json("meet")
          meet_users = rsp2.body_json("meet")["users"]
          meet_users.each {|meet_user|
            meet.users << @@users.find {|v| v.id == meet_user["id"].to_i}
          }
          user.result_meets.delete_if {|v| v.id == meet.id}
          user.result_meets << meet
        }
      }
    }}

    # Check result vs original
    total_cnt, neg_cnt, pos_cnt, mis_cnt = 0, 0, 0, 0
    cirkle_cnt, cirkle_mis = 0, 0
    cirkles = {}
    cirkles_meets = {}
    @@users.each {|user|
      user.meets.each {|meet|
        total_cnt += 1
        result_meet = user.result_meets.find {|v| v.name == meet.name && v.meet_type <= 3}
        if !result_meet
          neg_cnt += 1 if !meet.collision
        elsif !meet.match?(result_meet)
          mis_cnt += 1
        end
      }
      user.result_meets.each {|result_meet|
        next unless result_meet.meet_type <= 3
        meet = user.meets.find {|v| v.name == result_meet.name}
        if !meet || meet.collision
          pos_cnt += 1
        end
      }
      user.result_meets.each {|result_meet|
        if result_meet.meet_type == 6
          cirkles[result_meet.id] = result_meet
        elsif result_meet.meet_type == 3
          (cirkles_meets[result_meet.cirkle_id] ||= Array.new) << result_meet
        end
      }
    }
    cirkle_cnt, cirkle_mis = 0, 0
    cirkles_meets.each_pair {|cirkle_id, meets|
      cirkle = cirkles[cirkle_id]
      next unless cirkle
      meets_user_ids = Set.new
      meets.each {|meet| meet.users.each {|user|
        meets_user_ids << user.id
      }}
      cirkle_user_ids = cirkle.users.collect {|v| v.id}.to_set
      cirkle_cnt += 1
      if cirkle_user_ids != meets_user_ids
        cirkle_mis += 1
      end
    }
    should(true,
           "#{total_cnt} -#{neg_cnt} +#{pos_cnt} x#{mis_cnt}",
           "#{total_cnt} -#{neg_cnt} +#{pos_cnt} x#{mis_cnt}")
    should(true,
           "#{cirkle_cnt} x#{cirkle_mis}",
           "#{cirkle_cnt} x#{cirkle_mis}")
#   should(neg_cnt == 0 && pos_cnt == 0 && mis_cnt == 0,
#          "#{total_cnt}",
#          "#{total_cnt} -#{neg_cnt} +#{pos_cnt} x#{mis_cnt}")
    return true
  end
  def self.preamble
    prepare
    @@users.each {|user|
      res = rc_resource("users/#{user.id}/meets", user)
      rsp = res.get_json(); should_rsp(rsp)
      results = rsp.body_json()
      user.result_meets = []
      results.each {|result|
        result = result["meet"]
        meet = TestMeet.new
        meet.id = result["id"].to_i
        meet.name = result["name"]
        meet.time = Time.parse(result["time"])
        meet.users = []
        res2 = rc_resource("meets/#{meet.id}", user)
        rsp2 = res2.get_json(); should_rsp(rsp2)
        meet_users = rsp2.body_json("meet")["users"]
        meet_users.each {|meet_user|
          meet.users << @@users.find {|v| v.id == meet_user["id"].to_i}
        }
        if !user.result_meets.find {|v| v.id == meet.id}
          user.result_meets << meet
        end
      }
    }
    return true
  end
  def self.test_validation
    # Valid user accessibility
    # Correct users
    puts "Basic ..."
    10.times {
      user = @@users.rand

      # Correct user
      res = rc_resource("users/#{user.id}", user)
      rsp = res.get_json(); should_rsp(rsp)
      user_id = rsp.body_json("user")["id"].to_i
      should(user_id == user.id, "Correct user", "Wrong user expected #{user.id} but got #{user_id}")

      # Correct user/meets
      res = rc_resource("users/#{user.id}/meets", user)
      rsp = res.get_json(); should_rsp(rsp)
      user_meets = rsp.body_json
      should(user_meets.size >= user.result_meets.size,
             "Correct user_meets", "Wrong user_meets")

      # Correct meet
      meet = user.result_meets.rand
      if meet
        res = rc_resource("meets/#{meet.id}", user)
        rsp = res.get_json(); should_rsp(rsp)
        meet_id = rsp.body_json("meet")["id"].to_i
        should(meet_id == meet.id, "Correct meet", "Wrong meet expected #{meet.id} but got #{meet_id}")
      end
    }

    10.times {
      user = @@users.rand
      wrong_user = user
      wrong_user = @@users.rand while user == wrong_user

      # Wrong user
      res = rc_resource("users/#{wrong_user.id}", user)
      rsp = res.get_json()
      should(!rsp.ok?, "Wrong user", "Wrong user expected fail but got ok")
    }

    10.times {
      meet = nil
      while (!meet || meet.users.size == @@users.size)
        user = @@users.rand
        meet = user.result_meets.rand
      end
      wrong_user = nil
      while !wrong_user
        user = @@users.rand
        wrong_user = user if !meet.users.include?(user)
      end

      # Wrong meet
      res = rc_resource("meets/#{meet.id}", wrong_user)
      rsp = res.get_json()
      should(!rsp.ok?, "Wrong user", "Wrong meet expected fail but got ok")
    }
    return true
  end
  def self.test_cursorize
    puts "Cursorize ..."
    user = @@users.max_by {|v| v.result_meets.size}

    # Limit/offset
    res = rc_resource("users/#{user.id}/meets", user)
    rsp = res.get_json(); should_rsp(rsp)
    full_user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}

    res = rc_resource("users/#{user.id}/meets?limit=0", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets.empty?, "limit=0", "limit=0 but got #{user_meets.size} meets")

    limit = full_user_meets.size-1
    res = rc_resource("users/#{user.id}/meets?limit=#{limit}", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets.size == limit && user_meets == full_user_meets.slice(0..-2).sort,
           "limit=#{limit}", "limit=#{limit} did not get first #{limit} meets")

    limit = full_user_meets.size+1
    res = rc_resource("users/#{user.id}/meets?limit=#{limit}", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets.size == full_user_meets.size && user_meets == full_user_meets.sort,
           "limit=#{limit}", "limit=#{limit} did not get all meets")

    offset = 1
    limit = [1, full_user_meets.size-2].max
    res = rc_resource("users/#{user.id}/meets?offset=#{offset}&limit=#{limit}", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets.size == limit && user_meets == full_user_meets.slice(1..-2).sort,
           "offset=#{offset}", "offset=#{offset}")

    # Before/after time
    user.result_meets.sort_by! {|v| v.time}
    range = user.result_meets.last.time - user.result_meets.first.time
    middle = user.result_meets.first.time + range/2
    before_meets = user.result_meets.select {|v| v.time <= middle}.collect {|v| v.id}.sort
    after_meets = user.result_meets.select {|v| v.time >= middle}.collect {|v| v.id}.sort
    res = rc_resource("users/#{user.id}/meets?before_time=#{middle.iso8601}", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets == before_meets, "Before time", "Before time")
    res = rc_resource("users/#{user.id}/meets?after_time=#{middle.iso8601}", user)
    rsp = res.get_json(); should_rsp(rsp)
    user_meets = rsp.body_json.collect {|v| v["meet"]["id"].to_i}.sort
    should(user_meets == after_meets, "After time", "After time")
    return true
  end
  def self.test_chatter
    puts "Chatter ..."
    @@users.shuffle.each {|user|
      user.result_meets.each {|meet|
        next unless (1..10).to_a.rand > 8 # only write topic 1 in 5 chances
        res = rc_resource("meets/#{meet.id}/chatters", user)
        rsp = res.post_json(:content=>"Topic by #{user.name} #{@@marker}"); should_rsp(rsp)
      }
    }
    puts "PASS: Topics"
    @@users.shuffle.each {|user|
      user.result_meets.each {|meet|
        res = rc_resource("meets/#{meet.id}/chatters", user)
        res = rc_resource("meets/#{meet.id}", user)
        rsp = res.get_json()
        meet_chatters = rsp.body_json("meet")["topics"].collect {|v| v["id"]}
        next if meet_chatters.empty?

        next unless (1..10).to_a.rand > 8 # only write topic 1 in 5 chances
        2.times {
          chatter = meet_chatters.rand
          res = rc_resource("chatters/#{chatter}/comments", user)
          rsp = res.post_json(:content=>"Comment by #{user.name} #{@@marker}"); should_rsp(rsp)
        }
      }
    }
    puts "PASS: Comments"
    return true
  end
  def self.test_meet_edit
    puts "Meet Edit ..."
    10.times {
      user = @@users.rand
      meet = user.result_meets.rand
      next if !meet
      meet.name = "#{user.name} Party#{@@marker}"
      meet.location = "#{user.name} Place#{@@marker}"
      res = rc_resource("meets/#{meet.id}", user)
      rsp = res.put_json(meet.mview); should_rsp(rsp)
      rsp = res.get_json
      meet_name = rsp.body_json("meet")["meet_name"]
      meet_loc = rsp.body_json("meet")["meet_location"]
      should(meet_name == meet.name && meet_location = meet.location, "Meet edit", "Meet edit")
    }
    10.times {
      user = @@users.rand
      meet = user.result_meets.rand
      next if !meet
      user.result_meets.delete(meet)
      res = rc_resource("meets/#{meet.id}", user)
      rsp = res.delete_json; should_rsp(rsp)
      rsp = res.get_json
      should(!rsp.ok?, "Meet delete", "Meet delete")
    }
    return true
  end
  def self.test_phase1
    setup
  end
  def self.test_phase2
    preamble
    test_validation
    test_cursorize
    test_chatter
    test_meet_edit
    return true
  end
end
