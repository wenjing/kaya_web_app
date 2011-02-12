require 'test_base'

class TestUser
  attr_accessor :id, :name, :email, :password, :cookies, :meets, :result_meets
  def initialize
    self.meets = []
    self.result_meets = []
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

class UsersBuilder < TestBase
  @@user_count = 500
  def self.build_admin
    admin = User.create(:name=>"admin", :email=>"admin@kaya-labs.com",
                        :password=>"password", :password_confirmation=>"password")
    admin.toggle!(:admin)
  end
  def self.build
    users = Array.new(@@user_count) {TestUser.new}
    users.each_with_index {|user, no|
      serial = format("%05d", no+1)
      user.name = "User No.#{serial}"
      user.email = "user_#{serial}@kaya-labs.com"
      user.password = "password"
    }
    return users
  end
  @@users = build
  def self.build_and_save
    db_users = []
    @@users.each {|user|
      db_user = User.create(user.create)
      db_users << user
    }
    return db_users
  end
  def self.destroy_all
    @@users.each {|user|
      db_user = User.find_by_email(user.email)
      db_user.destroy if db_user
    }
    User.find_by_email("admin@kaya-labs.com").destroy
  end
  def self.build_and_signin
    @@users.each {|user|
      res = rc_resource("sessions", user)
      rsp = res.post_json(user.signin)
      user.id = rsp.body_json("user")["id"].to_i
      user.cookies = rsp.cookies
    }
    return @@users
  end
end
