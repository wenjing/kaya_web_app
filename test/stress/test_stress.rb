$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'

require 'create_locations'
require 'create_meets'
require 'create_mposts'
require 'create_users'

root_url = "http://0.0.0.0:3000"
res = RestClient::Resource.new(root_url, {:open_timeout=>600, :timeout=>600})

admin = User.new
admin.email = "admin@kaya-labs.com"
admin.password = "password"
rsp = res["sessions"].post_json(admin.signin)
admin.id, admin.cookies = rsp.body_json("user")["id"], rsp.cookies
rsp = res["debug/run"].cookies(admin.cookies).post_json(
#              {:script=>"load \'./test/reset_db.rb\'"}) if admin.id
              {:script=>"load \'./test/reset_lite.rb\'"}) if admin.id
rsp = res["sessions"].post_json(admin.signin)
admin.id, admin.cookies = rsp.body_json("user")["id"], rsp.cookies
               
rsp = res["users"].cookies(admin.cookies).get_json
db_users = Array.new
rsp.body_json.each {|body|
  db_users << body["user"] unless body["user"]["admin"]
}

users = UsersBuilder.build(db_users.size)
users.each_with_index {|user, index|
  db_user = db_users[index]
  user.id = db_user["id"]
  user.name = db_user["name"]
  user.email = db_user["email"]
  #rsp = res["sessions"].post_json(user.signin)
  #user.cookies = rsp.cookies
}

past_mposts = Array.new
total_mposts = Array.new
error_missing = Array.new
error_plus = Array.new
error_minus = Array.new
error_mix = Array.new
prepare_time = 5.minutes
process_time = 2.minutes
offset_time = 2.minutes
location_count = 55
#interval = 1.hour
interval = 30.minutes
run_times= 6

run_times.times {
# Prepare data
require 'active_support/core_ext'
random_users = users.shuffle
from_time = Time.now + prepare_time # count in data preparation time
to_time = from_time + interval
locs = LocationsBuilder.build(from_time, to_time, location_count)
meets = Array.new
locs.parallel_each(0) {|loc| # create meets for each location
  meets.concat(MeetsBuilder.build(loc, random_users, meets.size))
}
meets.sort_by! {|meet| meet.time}
mposts = Array.new
meets.parallel_each(0) {|meet| # create mposts for each meet
  mposts.concat(MpostsBuilder.build(meet))
}
mposts.sort_by! {|mpost| mpost.post_time}
locs.parallel_each(0) {|loc| # check leaks between different meets in same location
  loc_mposts = Array.new
  loc.meets.each {|meet| loc_mposts.concat(meet.mposts)}
  loc_mposts.each {|mpost| MpostsBuilder.check_leaks(mpost, loc_mposts)}
}

# Stats
locs_area_stat = locs.group_by {|loc| loc.area_size/100*100}.transform {|x| x.size}
locs_cap_stat = locs.group_by {|loc| loc.capacity/10*10}.transform {|x| x.size}
meets_user_stat = meets.group_by {|meet| meet.users.size}.transform {|x| x.size}
meets_range_stat = meets.group_by {|meet|
  (meet.trigger_range[1].time-meet.trigger_range[0].time).round
}.transform {|x| x.size}
mposts_offset_stat = mposts.group_by {|mpost|
  offset = [0, 0.1, 0.5, 1, 5, 10, 1.minute.to_i,
            10.minutes.to_i, 1.hour.to_i, 10.hour.to_i, 1.day.to_i].reverse.each {|v|
                    break v if mpost.post_time-mpost.time >= v}
  offset = -1 if offset.is_a?(Array)
  offset
}.transform {|x| x.size}
mposts_peers_stat = mposts.group_by {|mpost|
  users_count = mpost.meet.users.size
  peers_count = mpost.peers.size
  percentiles = (1..10).to_a.map {|x| format("%3d%", x*10)}
  if users_count <= 1
    percentiles.last
  else
    no = (peers_count.to_f/users_count*percentiles.size).floor.at_most(percentiles.size-1)
    percentiles[no]
  end
}.transform {|x| x.size}
meets_leaks_stat = meets.group_by {|meet|
  mposts_count = meet.mposts.size
  leaks_count = (meet.mposts.select {|mpost| !mpost.leaks.empty?}).size
  percentiles = (0..10).to_a.map {|x| format("%3d%", x*2)}
  if mposts_count <= 0
    percentiles.first
  else
    no = (leaks_count.to_f/mposts_count*percentiles.size).floor.at_most(percentiles.size-1)
    percentiles[no]
  end
}.transform {|x| x.size}
 
#locs.each {|loc| loc.display("")}
puts "location area :"
PP.pp(locs_area_stat.sort_by_key)
puts "location capacity :"
PP.pp(locs_cap_stat.sort_by_key)
puts "meet user :"
PP.pp(meets_user_stat.sort_by_key)
puts "meet time range :"
PP.pp(meets_range_stat.sort_by_key)
puts "mpost post offset :"
PP.pp(mposts_offset_stat.sort_by_key)
puts "mpost peers :"
PP.pp(mposts_peers_stat.sort_by_key)
puts "meet leaks :"
PP.pp(meets_leaks_stat.sort_by_key)
puts format("total meets  : %d", meets.size)
puts format("total mposts : %d", mposts.size)
first, last = *mposts.minmax_by {|mpost| mpost.time}
puts format("from %s to %s", first.time.to_s, last.time.to_s)

# Post mposts
dot_count = 0
mpost_head = 0
mposts.concat(past_mposts)
while (Time.now < to_time+offset_time && mpost_head < mposts.size)
  mpost = mposts[mpost_head]
  if mpost.post_time <= Time.now
    #rsp = res["mposts"].cookies(admin.cookies).post_json(mpost.create)
    ures = RestClient::Resource.new(root_url+"/mposts", {:open_timeout=>600, :timeout=>600, 
                                                  :user=>mpost.user.email, :password=>"password"})
    rsp = ures.post_json(mpost.create)
    mpost.id = rsp.body_json("mpost")["id"] if rsp.ok?
    mpost_head += 1
    if mpost_head % 10 == 0
      print "."; dot_count += 1
      if dot_count >= 80
        dot_count = 0
        puts "#{mpost_head}/#{mposts.size} #{mpost.post_time.time_ampm}/#{Time.now.time_ampm}"
      end
    end
  else
    sleep(0.5)
  end
end
puts ""

# Check meets
sleep(process_time.to_i) # wait 3 minutes so all pending mposts can be processed
sent_mposts = mposts.reject {|mpost| !mpost.id}
total_mposts.concat(sent_mposts)
pending_mposts = mposts.select {|mpost| !mpost.id}
mpost_ids = sent_mposts.map {|mpost| mpost.id}
rsp = nil
sent_mposts.each_with_index {|mpost, index|
  # Get 100 mposts each time
  start_index = index/100*100
  offset_index = index-start_index
  if offset_index == 0
    this_ids = mpost_ids.slice(start_index...start_index+100)
    rsp = res["debug/mposts"].cookies(admin.cookies).get_json(:mpost_ids=>this_ids)
  end
  mm = rsp.body_json()[offset_index]["mpost"]["meet"]
  if !mm
    error_missing << mpost
  else
    mpost.mname = mm["name"]
    uus = mm["users"] # created meet users
    musers = mpost.meet.users # should be users
    is_super_set = musers.all? {|user| uus.any? {|uu| user.id == uu["id"]} ||
                                      pending_mposts.any? {|pp| user.id == pp.user.id }}
    is_sub_set = uus.all? {|uu| musers.any? {|user| user.id == uu["id"]} ||
                                pending_mposts.any? {|pp| pp.user.id == uu["id"]}}
    if (is_super_set && is_sub_set)
      # Perfect match
    elsif is_sub_set # meet is subset of what it should be
      error_minus << mpost
    elsif is_super_set # meet is superset to what it should be
      error_plus << mpost
    elsif
      error_mix << mpost
    end
  end
}
past_mposts = mposts.reject {|mpost| mpost.id}
} # run_times

error_mposts = [error_missing, error_plus, error_minus, error_mix].flatten
puts format("incorrect mposts !%d +%d -%d x%d in %d, %.2f%",
            error_missing.size, error_plus.size, error_minus.size,
            error_mix.size, total_mposts.size,
            error_mposts.size.to_f/total_mposts.size*100)
