#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET ${url_root}/users/1/cirkles

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET ${url_root}/users/1/news

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/cirkles?after_time=2011-02-01T00:05:03Z"

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/news?after_time=2011-02-01T00:05:03Z"

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/news?after_time=2011-02-01T00:05:03Z&limit=10"

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/news?cirkle_id=12762"

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/news?user_id=1"

curl -H "$http_head" -u bessy.moo@kaya-labs.com:password -X GET "${url_root}/users/1/news?user_id=5"
