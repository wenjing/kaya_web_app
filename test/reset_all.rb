#reload!
[User, Mpost, Meet, Micropost, Relationship, MpostRecord].each {|db| db.delete_all}
User.connection.execute("delete from sqlite_sequence")
admin = User.create(:name=>"admin", :email=>"admin@kaya-labs.com",
                    :password=>"password", :password_confirmation=>"password")
admin.toggle!(:admin)
