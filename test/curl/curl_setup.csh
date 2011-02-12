#!/bin/csh -f

#Judith Williams
#Kenneth Baker
#Jessica Anderson
#Simon White
#Ronald Jackson
#Victoria White
#Diana Clarke
#David Harrison
#Kenneth Jeffries
#Felicity Johnson

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

curl -H "$http_head" -u admin@kaya-labs.com:password -d "script=load './test/reset_all.rb'" ${url_root}/debug/run

curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Judith Williams&email=bessy.moo.1@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Kenneth Baker&email=bessy.moo.2@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Jessica Anderson&email=bessy.moo.3@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Simon White&email=bessy.moo.4@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Victoria White&email=bessy.moo.5@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Kenneth Jeffries&email=bessy.moo.a@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users
curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=Felicity Johnson&email=bessy.moo.b@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users

# First meet (1,2,3)
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 2:3&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 3:4&&user_dev=Bessy Moo 2:3&lerror=1" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:14-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 3:4&lerror=1" ${url_root}/mposts

# Second meet (1)
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-28T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts

# Third meet (2,3)
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-11-29T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 3:4&&user_dev=Bessy Moo 2:3&lerror=1" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-11-29T09:27:14-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 2:3&&user_dev=Bessy Moo 3:4&lerror=1" ${url_root}/mposts

# Fourth meet (4,5)
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X POST -d "time=2010-11-30T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 5:6&&user_dev=Bessy Moo 4:5&lerror=5" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X POST -d "time=2010-11-30T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 4:5&&user_dev=Bessy Moo 5:6&lerror=4" ${url_root}/mposts

# Ten more meet (1)
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:01:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:02:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:03:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:04:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:05:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:06:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:07:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:08:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:09:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:10:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
