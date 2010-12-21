#reload!
[User, Mpost, Meet, Micropost, Relationship, MpostRecord].each {|db| db.delete_all}
#User.connection.execute("delete from sqlite_sequence where name!=users")
User.connection.execute("delete from sqlite_sequence")
admin = User.create(:name=>"admin", :email=>"admin@kaya-labs.com",
                    :password=>"password", :password_confirmation=>"password")
admin.toggle!(:admin)

class UsersBuilder
  #@@user_count = 10000
  @@user_count = 10000

  def self.build
    users = Array.new(@@user_count) {User.new}
    users.each_with_index {|user, no|
      serial = format("%05d", no+2)
      user.name = "user #{serial}"
      user.email = "user_#{serial}@kaya-labs.com"
      user.password = "password"
      user.password_confirmation = "password"
    }
    return users
  end
end

users = UsersBuilder.build
users.each {|user| user.save}              

#set_debug(:kaya_tqueue, 1)
#set_debug(:kaya_timer, 2)
#set_debug(:processer, 2)
#set_debug(:pool_before, 2)
#set_debug(:pool_cluster, 2)
#set_debug(:pool_cold, 2)
#set_debug(:pool_after, 2)
