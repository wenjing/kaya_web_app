#!/bin/csh -f
#Do not rerun this script - it's already done!
#Adam Chu 2/20/11
set url_root='http://www.kayameet.com'
set http_head='Accept: application/json'
set limit = 3000
set i = 0
while ($i < $limit)
	@ i++
	curl -H "$http_head" -u admin@kaya-labs.com:password -d "name=$i Test&email=$i.test@kaya-labs.com&password=password&password_confirmation=password" ${url_root}/users >> ./test.result
	sleep 1
end

