u1 = User.create(:name=>"user 1", :email=>"user1@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u2 = User.create(:name=>"user 2", :email=>"user2@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u3 = User.create(:name=>"user 3", :email=>"user3@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")
u4 = User.create(:name=>"user 4", :email=>"user4@kaya-labs.com", :password=>"password",
                 :password_confirmation=>"password")

p1 = Mpost.create(:time=>Time.now-1.day-5.second, :user_id=>u1.id, :lng=>120.00, :lat=>-30.001, :lerror=>10,
                  :user_dev=>"dev1", :devs=>"dev2,dev3,dev4,dev5")
p2 = Mpost.create(:time=>Time.now-1.day-3.second, :user_id=>u2.id, :lng=>120.00, :lat=>-30.002, :lerror=>20,
                  :user_dev=>"dev2", :devs=>"dev1,dev3,dev4,dev5")
p3 = Mpost.create(:time=>Time.now-1.day-1.second, :user_id=>u3.id, :lng=>120.00, :lat=>-30.003, :lerror=>30,
                  :user_dev=>"dev3", :devs=>"dev2,dev1,dev4,dev5")
p4 = Mpost.create(:time=>Time.now-1.day-4.second, :user_id=>u4.id, :lng=>120.00, :lat=>-30.004, :lerror=>40,
                  :user_dev=>"dev4", :devs=>"dev2,dev3,dev1,dev5")

m1 = Meet.new
m1.mposts << p1
m1.mposts << p2
m1.mposts << p3
m1.extract_information
m1.save
m1.users.size

m1.mposts << p4
m1.extract_information
m1.save
m1.users.size

q1 = Mpost.create(:time=>Time.now-5.second, :user_id=>u1.id, :lng=>120.00, :lat=>-30.001, :lerror=>10,
                  :user_dev=>"dev1", :devs=>"dev2,dev3,dev4,dev5")
q2 = Mpost.create(:time=>Time.now-3.second, :user_id=>u2.id, :lng=>120.00, :lat=>-30.002, :lerror=>20,
                  :user_dev=>"dev2", :devs=>"dev1,dev3,dev4,dev5")
q3 = Mpost.create(:time=>Time.now-1.second, :user_id=>u3.id, :lng=>120.00, :lat=>-30.003, :lerror=>30,
                  :user_dev=>"dev3", :devs=>"dev2,dev1,dev4,dev5")
q4 = Mpost.create(:time=>Time.now-4.second, :user_id=>u4.id, :lng=>120.00, :lat=>-30.004, :lerror=>40,
                  :user_dev=>"dev4", :devs=>"dev2,dev3,dev1,dev5")

#set_debug(:kaya_tqueue, 2)
#set_debug(:kaya_timer, 2)
set_debug(:processer, 2)
#set_debug(:pool_before, 2)
#set_debug(:pool_cluster, 2)
#set_debug(:pool_cold, 2)
#set_debug(:pool_after, 2)

processer = MeetProcesser.instance

pool = MeetPool.new
#pool.pending_mposts << q1
#pool.pending_mposts << q2
#pool.pending_mposts << q3
#pool.pending_mposts << q4
set_debug(:pool, 10)
r1 = pool.create_raw_cluster(:mpost=>q1)
pool.dump_debug(:pool)
r2 = pool.create_raw_cluster(:mposts=>[q2,q3])
pool.dump_debug(:pool)
r3 = pool.merge_clusters(r1, r2)
pool.dump_debug(:pool)
pool.add_to_raw_clusters_if_possible(q4)
pool.dump_debug(:pool)
r4 = pool.split_cluster([q1,q4], r3)
pool.dump_debug(:pool)
puts pool.earliest_mpost.trigger_time
pool.move_to_processed_clusters(r4)
pool.dump_debug(:pool)
puts pool.earliest_mpost.trigger_time
puts pool.meets

relation = MeetRelation.new
relation.populate_from_cluster(r4, &processer.method(:coeff_calculator))
puts relation.proceed(&processer.method(:pass_coeff_criteria_normal?))
puts relation.seeded.keys

#processer.process_meets
