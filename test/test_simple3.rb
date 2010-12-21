User.delete_all
Mpost.delete_all
Meet.delete_all
User.connection.execute("delete from sqlite_sequence")

u1 = User.create(:name=>"user 1", :email=>"user1@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u2 = User.create(:name=>"user 2", :email=>"user2@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u3 = User.create(:name=>"user 3", :email=>"user3@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u4 = User.create(:name=>"user 4", :email=>"user4@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")

p1 = u1.mposts.create(:time=>Time.now-1.day-5.second, :user_id=>u1.id, :lng=>120.00, :lat=>-30.001, :lerror=>10,
                  :user_dev=>"user 1:1", :devs=>"user 2:2,user 3:3,user 4:4")
p2 = u2.mposts.create(:time=>Time.now-1.day-3.second, :user_id=>u2.id, :lng=>120.00, :lat=>-30.002, :lerror=>20,
                  :user_dev=>"user 2:2", :devs=>"user 1:1,user 3:3,user 4:4")
p3 = u3.mposts.create(:time=>Time.now-1.day-1.second, :user_id=>u3.id, :lng=>120.00, :lat=>-30.003, :lerror=>30,
                  :user_dev=>"user 3:3", :devs=>"user 2:2,user 1:1,user 4:4")
p4 = u4.mposts.create(:time=>Time.now-1.day-4.second, :user_id=>u4.id, :lng=>120.00, :lat=>-30.004, :lerror=>40,
                  :user_dev=>"user 4:4", :devs=>"user 2:2,user 3:3,user 1:1")

x5 = u4.mposts.create(:time=>Time.now-1.day+20.minute, :user_id=>u4.id, :lng=>120.00, :lat=>-30.004, :lerror=>40,
                  :user_dev=>"user 4:4", :devs=>"user 2:2,user 3:3,user 1:1")

q1 = u1.mposts.create(:time=>Time.now-5.second, :user_id=>u1.id, :lng=>120.00, :lat=>-30.001, :lerror=>10,
                  :user_dev=>"user 1:1", :devs=>"user 2:2,user 3:3,user 4:4")
q2 = u2.mposts.create(:time=>Time.now-3.second, :user_id=>u2.id, :lng=>120.00, :lat=>-30.002, :lerror=>20,
                  :user_dev=>"user 2:2", :devs=>"user 1:1,user 3:3,user 4:4")
q3 = u3.mposts.create(:time=>Time.now-1.second, :user_id=>u3.id, :lng=>120.00, :lat=>-30.003, :lerror=>30,
                  :user_dev=>"user 3:3", :devs=>"user 2:2,user 1:1,user 4:4")
q4 = u4.mposts.create(:time=>Time.now-4.second, :user_id=>u4.id, :lng=>120.00, :lat=>-30.004, :lerror=>40,
                  :user_dev=>"user 4:4", :devs=>"user 2:2,user 3:3,user 1:1")

y5 = u1.mposts.create(:time=>Time.now-5.second-3.minute, :user_id=>u1.id, :lng=>120.00, :lat=>-30.001, :lerror=>10,
                  :user_dev=>"user 1:1", :devs=>"user 2:2,user 3:3,user 4:4")

require 'kaya_base'
KayaBase
#set_debug(:kaya_tqueue, 1)
#set_debug(:kaya_timer, 1)
#set_debug(:processer, 2)
#set_debug(:pool_before, 2)
#set_debug(:pool_cluster, 2)
#set_debug(:pool_cold, 2)
#set_debug(:pool_after, 2)

require 'meet_processer'
wrapper = MeetWrapper.new

wrapper.process_mposts([p1.id], Time.now.getutc)
wrapper.process_mposts([p2.id], Time.now.getutc)
wrapper.process_mposts([p3.id], Time.now.getutc)
wrapper.process_mposts([p4.id], Time.now.getutc)

wrapper.process_mposts([x5.id], Time.now.getutc)

wrapper.process_mposts([q1.id], Time.now.getutc)
wrapper.process_mposts([q2.id], Time.now.getutc)
wrapper.process_mposts([q3.id], Time.now.getutc)
wrapper.process_mposts([q4.id], Time.now.getutc)

wrapper.process_mposts([y5.id], Time.now.getutc)

processer = MeetProcesser.instance
#puts Time.now
#sleep(6)
#processer.process_meets(true)
#
#puts Time.now
#sleep(6)
#processer.process_meets(true)
#
#puts Time.now
#sleep(6)
#processer.process_meets(true)
#
#puts Time.now
#sleep(6)
#processer.process_meets(true)
#
sleep(2)
Meet.find(:all).each {|meet| puts meet.inspect}
sleep(5)
Meet.find(:all).each {|meet| puts meet.inspect}
sleep(10)
Meet.find(:all).each {|meet| puts meet.inspect}
#puts processer.empty?
#puts processer.elapse_time
#processer.dump_debug

puts u1.meets.inspect
puts u2.meets.inspect
puts u3.meets.inspect
puts u4.meets.inspect
