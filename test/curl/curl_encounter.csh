#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

curl -H "$http_head" -X POST -d "name=encounter test 1&email=encounter.test.1@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -X POST -d "name=encounter test 2&email=encounter.test.2@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -X POST -d "name=encounter test 3&email=encounter.test.3@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users

[4246,4247,4248].each {|v|
  v = User.find(v)
  v.meets.each {|u| u.destroy}
  v.mviews.each {|u| u.destroy}
  v.mposts.each {|u| u.destroy}
}

# Peer mode solo
curl -H "$http_head" -u encounter.test.1@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 1:4246:from encounter test 1:1303351012" ${url_root}/mposts

# Peer mode private
curl -H "$http_head" -u encounter.test.1@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 1:4246:from encounter test 1:1303351112&devs=encounter test 2:4247:from encounter test 2:1303351112" ${url_root}/mposts
curl -H "$http_head" -u encounter.test.2@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 2:4247:from encounter test 2:1303351212&devs=encounter test 1:4246:from encounter test 1:1303351110" ${url_root}/mposts

# Group mode private
curl -H "$http_head" -u encounter.test.1@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 1:4246:from encounter test 1:1303351312&devs=encounter test 2:4247:from encounter test 2:1303351212" ${url_root}/mposts
curl -H "$http_head" -u encounter.test.2@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 2:4247:from encounter test 2:1303351412&devs=encounter test 1:4246:from encounter test 1:1303351210,encounter test 3:4248:from encounter test 3:1303351213" ${url_root}/mposts
curl -H "$http_head" -u encounter.test.3@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 3:4248:from encounter test 3:1303351512&devs=encounter test 2:4247:from encounter test 2:1303351211" ${url_root}/mposts

# Cirkle creater
curl -H "$http_head" -u encounter.test.1@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 1:4246:creater encounter test 1:0:1303351010" ${url_root}/mposts

# Cirkle hoster
curl -H "$http_head" -u encounter.test.2@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 2:4247:from encounter test 2:1303351452&devs=encounter test 1:4246:hoster encounter test 1:32294:1303350010,encounter test 3:4248:from encounter test 3:1303350013" ${url_root}/mposts
curl -H "$http_head" -u encounter.test.3@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 3:4248:from encounter test 3:1303351452&devs=encounter test 1:4246:hoster encounter test 1:32294:1303350012,encounter test 2:4247:from encounter test 2:1303350010" ${url_root}/mposts
sleep 1
curl -H "$http_head" -u encounter.test.1@kaya-labs.com:password -X POST \
     -d "time=2010-11-27T09:27:13-08:00&lng=-97.7428&lat=30.2669&lerror=2&user_dev=encounter test 1:4246:hoster encounter test 1:32294:1303351452&devs=encounter test 2:4247:from encounter test 2:1303350011,encounter test 3:4248:from encounter test 3:1303350014" ${url_root}/mposts
