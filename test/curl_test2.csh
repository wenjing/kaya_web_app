#!/bin/csh -f

set url_root='http://0.0.0.0:3000'
set http_head='Accept: application/json'

echo "Chatter topic"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "content=my topic 1" ${url_root}/meets/1/chatters
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "content=my topic 2" ${url_root}/meets/1/chatters

echo "Comment"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "content=my comment 1" ${url_root}/chatters/1/comments
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "content=my comment too" ${url_root}/chatters/1/comments
curl -H "$http_head" -u bessy.moo.2@kaya-labs.com:password -X POST -d "content=my comment again" ${url_root}/chatters/2/comments
curl -H "$http_head" -u bessy.moo.3@kaya-labs.com:password -X POST -d "content=my comment hello" ${url_root}/chatters/2/comments

echo "Wrong meet chatter"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "content=my topic spoiler" ${url_root}/meets/3/chatters

echo "meet detail with chatters"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X GET ${url_root}/meets/1

echo "New user invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.mee.1@kaya-labs.com&message=invitation to a new user" ${url_root}/users/2/invitations

echo "Existing user invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.moo.2@kaya-labs.com&message=invitation to a exisitng user" ${url_root}/users/2/invitations

echo "New user meet invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.mee.2@kaya-labs.com&message=meet to a new user" ${url_root}/meets/1/invitations

echo "Existing user meet invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.moo.5@kaya-labs.com&message=meet to a existing user" ${url_root}/meets/1/invitations

echo "Existing meet user meet invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.moo.2@kaya-labs.com&message=meet to a existing user" ${url_root}/meets/1/invitations

echo "Multiple users meet invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.mee.3@kaya-labs.com,bessy.moo.4@kaya-labs.com&message=meet to both existing and new users" ${url_root}/meets/1/invitations

echo "Wrong user meet invitation"
curl -H "$http_head" -u bessy.moo.1@kaya-labs.com:password -X POST -d "invitee=bessy.mee.1@kaya-labs.com&message=my invitation spoiler" ${url_root}/meets/3/invitations

echo "Update user profile a.k.a confirmation"
curl -H "$http_head" -u admin@kaya-labs.com:password -X PUT -d "name=Diana Clarke&email=bessy.mee.1@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users/7
curl -H "$http_head" -u admin@kaya-labs.com:password -X PUT -d "name=Diana Clarke&email=bessy.mee.2@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users/8
curl -H "$http_head" -u admin@kaya-labs.com:password -X PUT -d "name=Diana Clarke&email=bessy.mee.3@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users/9

echo "Pending meets"
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/5/pending_meets
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/6/pending_meets
curl -H "$http_head" -u bessy.mee.2@kaya-labs.com:password -X GET ${url_root}/users/8/pending_meets
curl -H "$http_head" -u bessy.mee.3@kaya-labs.com:password -X GET ${url_root}/users/9/pending_meets

echo "Confirm a meet"
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X POST -d '' ${url_root}/meets/1/confirm
curl -H "$http_head" -u bessy.mee.2@kaya-labs.com:password -X POST -d '' ${url_root}/meets/1/confirm
curl -H "$http_head" -u bessy.mee.3@kaya-labs.com:password -X DELETE ${url_root}/meets/1/decline

echo "Check confirmation results"
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/5/meets
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/6/meets
curl -H "$http_head" -u bessy.mee.2@kaya-labs.com:password -X GET ${url_root}/users/8/meets
curl -H "$http_head" -u bessy.mee.3@kaya-labs.com:password -X GET ${url_root}/users/9/meets

echo "Pending meets again"
curl -H "$http_head" -u bessy.moo.4@kaya-labs.com:password -X GET ${url_root}/users/5/pending_meets
curl -H "$http_head" -u bessy.moo.5@kaya-labs.com:password -X GET ${url_root}/users/6/pending_meets
curl -H "$http_head" -u bessy.mee.2@kaya-labs.com:password -X GET ${url_root}/users/8/pending_meets
curl -H "$http_head" -u bessy.mee.3@kaya-labs.com:password -X GET ${url_root}/users/9/pending_meets
