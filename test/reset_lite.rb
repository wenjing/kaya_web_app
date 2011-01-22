#reload!
[User, Mpost, Meet, Chatter, Invitation, Mview, MpostRecord].each {|db| db.delete_all}
User.connection.execute("delete from sqlite_sequence where name != \"users\"")
