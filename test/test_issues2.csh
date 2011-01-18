#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
#set url_root='http://kayameet.com'
set http_head='Accept: application/json'

#curl -H "$http_head" -d "name=Bessy Moo 1&email=bessy.moo.1@kaya-labs.com&password=password" ${url_root}/users
#curl -H "$http_head" -d "name=Bessy Moo 2&email=bessy.moo.2@kaya-labs.com&password=password" ${url_root}/users
#curl -H "$http_head" -d "name=Bessy Moo 3&email=bessy.moo.3@kaya-labs.com&password=password" ${url_root}/users
#curl -H "$http_head" -d "name=Bessy Moo 4&email=bessy.moo.4@kaya-labs.com&password=password" ${url_root}/users
#curl -H "$http_head" -d "name=Bessy Moo 5&email=bessy.moo.5@kaya-labs.com&password=password" ${url_root}/users


## First meet (1,2,3)
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:1&&user_dev=Bessy Moo 2&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 2:2&&user_dev=Bessy Moo 2&lerror=1" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-11-27T09:27:14-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 3:3&&user_dev=Bessy Moo 2&lerror=1" ${url_root}/mposts
#echo
#
## Second meet (1)
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-28T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 1:1&&user_dev=Bessy Moo 2&lerror=2" ${url_root}/mposts
#echo
#
## Third meet (2,3)
#curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "time=2010-11-29T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 2:2&&user_dev=Bessy Moo 2&lerror=1" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "time=2010-11-29T09:27:14-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 3:3&&user_dev=Bessy Moo 2&lerror=1" ${url_root}/mposts
#echo
#
## Fourth meet (4,5)
##curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X POST -d "time=2010-11-30T09:27:12-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 4:4&&user_dev=Bessy Moo 2&lerror=5" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X POST -d "time=2010-11-30T09:27:13-08:00&lng=-97.7428&lat=30.2669&devs=Bessy Moo 5:5&&user_dev=Bessy Moo 2&lerror=4" ${url_root}/mposts
#echo
#
## Ten more meet (1)
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:01:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:02:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:03:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:04:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:05:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:06:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:07:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:08:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:09:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "time=2010-11-27T09:10:12-08:00&lng=-97.7428&lat=30.2669&devs=&&user_dev=Bessy Moo 1:1&lerror=2" ${url_root}/mposts
#echo

#sleep 5

# Chatter
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "user_id=10&meet_id=214&content=some comments" ${url_root}/chatters
#echo

# Invite
#echo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "user_id=10&meet_id=214&invitee=hong.zhao@kaya-labs.com" ${url_root}/invitations
#echo


# Cursorize
echo
echo "Cursor"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "max_count=0" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "after_time=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:05:12-08:00&max_count=2" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "after_time=2010-11-27T09:05:12-08:00&max_count=3" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00&max_count=3" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00&max_count=100" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=0&to_index=4" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=5&to_index=9" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=10&to_index=100" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=0&max_count=5" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=5&max_count=5" -X GET ${url_root}/users/10/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=10&max_count=5" -X GET ${url_root}/users/10/meets

# Meet detail info
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/2

# Add your into meet
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "invitation[invitee]=bessy.moo.1@kaya-labs.com,bessy.moo.4.kaya-labs.com&invitation[message]=Add you into our meet in Bessy Jr's party, please check the site." -X POST ${url_root}/meets/9/invitations

# Invitation
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "invitation[invitee]=bessy.moo.1@kaya-labs.com,bessy.moo.5.kaya-labs.com&invitation[message]=This is very interesting iphone App, please give it a try" -X POST ${url_root}/users/10/invitations

# Chatter
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "chatter[content]=Congratulation to all" -X POST ${url_root}/meets/9/chatters

# Chatter with photo
#curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "chatter[content]=Bessy Jr's candle blower&" -X POST ${url_root}/meets/9/chatters

# Edit meet
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "mview[name]=Bessy Jr's birthday party&mview[location]=Saba Odori Cuisine" -X PUT ${url_root}/meets/9

# Delete meet
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X DELETE ${url_root}/meets/10

