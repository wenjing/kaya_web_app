Factory.define :user do |user|
  user.name                  "Michael Hartl"
  user.email                 "mhartl@example.com"
  user.password              "foobar"
  user.password_confirmation "foobar"
end

Factory.sequence :email do |n|
  "person-#{n}@example.com"
end

Factory.define :micropost do |micropost|
  micropost.content "Foo bar"
  micropost.association :user
end

Factory.define :mpost do |mpost|
  mpost.time  Time.now.iso8601
  mpost.lat  37.793621
  mpost.lng  -122.395899
  mpost.lerror  50
  mpost.user_dev  "11:22:33:44:55:66, aa:bb:cc:dd:ee:ff"
  mpost.devs  "11:22:33:44:55:66, aa:bb:cc:dd:ee:ff"
  mpost.association :user
end
