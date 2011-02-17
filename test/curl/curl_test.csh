#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

echo "Mpost processing status"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/1
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/2

echo "Correct user"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/users/2
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/users/3
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/users/4
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/5
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/6

echo
echo "Correct user_meet"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/users/2/meets
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/users/3/meets
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/users/4/meets
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/5/meets
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/6/meets

echo
echo "Correct mpost"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/1
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/mposts/2
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/mposts/3
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/4
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/mposts/5
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/mposts/6
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/mposts/7
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/mposts/8
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/9
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/10

echo
echo "Correct meet"
# Get first (1,2,3)
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/1
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/meets/1
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/meets/1

# Get first (1)
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/2

# Get third (2,3)
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X GET ${url_root}/meets/3
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/meets/3

# Get fourth (2,3)
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/meets/4
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/meets/4

# Woops, wrong user
echo
echo "Wrong user"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/users/4
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/2
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/6

# Woops, wrong mpost
echo
echo "Wrong mpost"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/mposts/2
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/mposts/5
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/mposts/1

# Woops, wrong meet
echo
echo "Wrong meet"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/3
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/meets/2
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X GET ${url_root}/meets/2

# Woops, wrong user_meets
echo
echo "Wrong user_meet"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/users/4/meets
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/2/meets
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/6/meets

# Cursorize
echo
echo "Cursor"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "max_count=0" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_updated_at=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/2/meets
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "after_updated_at=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "after_time=2010-11-27T09:05:12-08:00" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:05:12-08:00&max_count=2" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "after_time=2010-11-27T09:05:12-08:00&limit=3" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00&limit=3" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "before_time=2010-11-27T09:30:12-08:00&after_time=2010-11-27T09:00:00-08:00&limit=100" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=0&to_index=4" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=5&to_index=9" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=10&to_index=100" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=0&limit=5" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=5&limit=5" -X GET ${url_root}/users/2/meets
echo
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -d "from_index=10&max_count=5" -X GET ${url_root}/users/2/meets
