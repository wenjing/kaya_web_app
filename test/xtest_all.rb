$LOAD_PATH << '.'
$LOAD_PATH << './test'
$LOAD_PATH << './lib'

root_url = "http://0.0.0.0:3000"
rest_options = {:open_timeout=>600, :timeout=>600}

class User
  attr_accessor :id, :name, :email, :password, :cookies
  def initialize(name, email, password)
    self.name = name
    self.email = email
    self.password = password
  end
  def create
    return to_params(:name, :email, :password, :password_confirmation)
  end
  def signin
    return to_params(:email, :password)
  end
  def credential
    return {:user=>email, :password=>"password"}
  end
  def password_confirmation
    return password
  end
  def dev
    return "#{name}:#{id}"
  end
end

# Create admin and cleanup database
admin = User.new
admin.name, admin.email, admin.password = "admin", "admin@kaya-labs.com", "password"
ares = RestClient::Resource.new(root_url+"debug/run", rest_options.merge(admin.credential))
rsp = ares.post_json({:script=>"load \'./test/reset_all.rb\'"})

require 'random_data' 
ures = RestClient::Resource.new(root_url+"users", rest_options)
users = Array.new
(1..10).each {|user_id|
  user = User.new
  user.name, user.email, user.password = Random.full_name, Random.email, Random.alphanumeric(8)
  rsp = ures.post_json(user.create)
  user.id = rsp.body_json("user")["id"] if rsp.ok?
  users << user
}

class Mpost
  attr_accessor :id, :time, :lng, :lat, :lerror, :user, :peers, :host_id, :host_mode

  def initialize(id, time, lng, lat, lerror, user, peers, host_mode=0, host_id=nil)
    self.id = id
    self.time = time
    self.lng = lng
    self.lat = lat
    self.lerror = lerror
    self.user = user
    self.peers = peers
    self.host_mode = host_mode
    self.host_id = host_id
  end
  def create
    params = to_params(:time, :lng, :lat, :lerror).merge(
                       :devs=>((peers.map {|peer| peer.dev}).join(",")),
                       :user_dev=>user.dev, :user_id=>user.id)
    params.merge(:host_id=>host_id) if host_id
    params.merge(:host_mode=>(host_mode||0))
    return params
  end
end

# Test peer (hostless) mode
mposts = Array.new
user = users[0]
mpost = Mpost.new
mpost = 
pres = RestClient::Resource.new(root_url+"/mposts", rest_options.merge(user.credential))

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
