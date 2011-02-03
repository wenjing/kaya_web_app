#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

echo "Edit meet"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X PUT -d "name=My first meet&location=My office" ${url_root}/meets/10
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/10

echo "Delete meet"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X DELETE ${url_root}/meets/10
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/10

echo "Before delete chatter"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/1
echo "Delete chatter"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X DELETE ${url_root}/chatters/2
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X DELETE ${url_root}/chatters/3
echo "After delete chatter"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/1

echo "Password reset"
curl -H "$http_head" -X POST -d "email=bessy.mee.1@kaya-labs.com" ${url_root}/create_reset

echo "Old password still working"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/users/2/pending_meets
