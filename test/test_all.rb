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
rsp = res["admin/run"].cookies(admin.cookies).post_json(
                {:script=>"load \'./test/reset_db.rb\'"}) if admin.id
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
}


mpost_count = 0
error_mposts = Array.new
mposts = Array.new
run_hours = 24
(1..24).time {

# Prepare data
require 'active_support/core_ext'
random_users = users.shuffle
mposts.reject! {|mpost| mpost.id}
from_time = Time.now + 1.minutes # give it a break
to_time = from_time + 1.hour
locs = LocationsBuilder.build(from_time, to_time, 55)
meets = Array.new
locs.each {|loc|
  meets.concat(MeetsBuilder.build(loc, random_users, meets.size))
}
meets.each {|meet|
  mposts.concat(MpostsBuilder.build(meet))
}
locs.sort_by! {|loc| loc.area_size}
meets.sort_by! {|meet| meet.time}
mposts.sort_by! {|mpost| mpost.post_time}

# Post mposts
mpost_head = 0
while (Time.now < to_time+1.minute && mpost_head < mposts.size)
  mpost = mposts[mpost_head]
  if mpost.post_time < Time.now
    rsp = res["mpost"].cookies(admin.cookies).post_json(mpost.create)
    mpost.id = rsp.body_json("user")["id"]
    mpost_head += 1
  else
    sleep(0.5)
  end
end

sleep(5.minutes.to_i) # wait 5 minutes so all pending mposts can be processed
# Check meets
done_mposts.slice(0..mpost_head-1).reject {|mpost| !mpost.id}
mpost_ids = done_mposts.map {|mpost| mpost.id}
rsp = res["admin/mposts"].cookies(admin.cookies).get_json(:mpost_ids=>mpost_ids)
done_mposts.each_with_index {|mpost, index|
  mpost.mname = rsp.body_json("mpost")[index]["meet"]["name"]
  error_mposts << mpost unless mpost.correct?
  mpost_count += 1
}

if need_debug
locs.each {|loc| loc.display("")}

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
    no = (peers_count.to_f/users_count*percentiles.size).floor
    no = [percentiles.size-1, no].min
    percentiles[no]
  end
}.transform {|x| x.size}

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
puts format("total meets  : %d", meets.size)
puts format("total mposts : %d", mposts.size)
end

}

print "incorrect mposts ? in ?, ?%", error_mposts.size, mpost_count,
                                     error_mposts.size.to_f/mpost_count*100
