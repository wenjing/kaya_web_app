require 'kaya_base'

class User
  attr_accessor :id, :name, :email, :password, :password_confirmation, :dev, :cookies

  def create
    return to_params(:name, :email, :password, :password_confirmation)
  end

  def signin
    return to_params(:email, :password)
  end
end

class UsersBuilder
  @@user_count = 10000

  def self.build(user_count=nil)
    user_count ||= @@user_count
    users = Array.new(user_count) {User.new}
    dev = "00:00:00:00:00:02"
    users.each_with_index {|user, no|
      serial = format("%05d", no+2)
      #user.name = "user_#{serial}"
      #user.email = "user_#{serial}@kaya-labs.com"
      #user.password = "password"
      #user.password_confirmation = "password"
      user.dev = dev
      dev = dev.succ
    }
    return users
  end
end
