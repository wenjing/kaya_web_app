#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

curl -H "$http_head" -u user_00040@kaya-labs.com:password -X GET ${url_root}/users/453/cirkles

curl -H "$http_head" -u user_00040@kaya-labs.com:password -X GET ${url_root}/users/453/news

curl -H "$http_head" -u user_00040@kaya-labs.com:password -X GET "${url_root}/users/453/news?cirkle_id=3"

curl -H "$http_head" -u user_00040@kaya-labs.com:password -X GET "${url_root}/users/453/news?user_id=453"

curl -H "$http_head" -u user_00040@kaya-labs.com:password -X GET "${url_root}/users/453/news?user_id=444"
