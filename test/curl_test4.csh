#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

# Collision
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-12-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 2:3&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-12-27T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 3:4&&user_dev=Bessy Moo 2:3&lerror=1" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-12-27T09:27:14-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 3:4&lerror=1&collision=1" ${url_root}/mposts

# Create host meet
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-12-30T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 1:2&lerror=2" ${url_root}/mposts

# Join host meet
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-12-30T10:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 2:3&lerror=2&host_mode=2&host_id=Jun Li:2:Bessy Moo 1' party:16" ${url_root}/mposts
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-12-30T11:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 3:4&lerror=2&host_mode=2&host_id=Jun Li:2:Bessy Moo 1' party:16" ${url_root}/mposts

# Joint meet
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X POST -d "time=2010-12-30T11:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:2&&user_dev=Bessy Moo 4:5&lerror=2&host_mode=4&host_id=Bessy Moo:1296626195_1:16" ${url_root}/mposts