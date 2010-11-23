#reload!
[Mpost, Meet, Micropost, Relationship, MpostRecord].each {|db| db.delete_all}
User.connection.execute("delete from sqlite_sequence where name != \"users\"")

#set_debug(:kaya_tqueue, 1)
#set_debug(:kaya_timer, 2)
set_debug(:processer, 2)
#set_debug(:pool_before, 2)
#set_debug(:pool_cluster, 2)
#set_debug(:pool_cold, 2)
#set_debug(:pool_after, 2)
