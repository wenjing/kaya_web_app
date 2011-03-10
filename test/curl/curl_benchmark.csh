#!/bin/csh -f
#this script benchmarks mpost operations. use GET stats to verify delay.
#curl -H 'Accept: application/json' -u admin@kaya-labs.com:password -X GET www.kayameet.com/debug/stats
#Adam Chu. 2/20/11
set url_root='http://www.kayameet.com'
set http_head='Accept: application/json'
set now=`date "+%Y-%m-%dT%H:%M:%S-08:00"`
set cmd="echo curl"

set limit = 1000
set round = 0
set i = 0
set j = 0
set k = 0
set ui = 0
set uj = 0
set uk = 0

echo starting at $now

while ($round < $limit)
	@ i = 3 * $round  + 1
	@ j = $i + 1
	@ k = $i + 2
	@ ui= 3 * $round + 1232
	@ uj= $ui + 1
	@ uk= $ui + 2
	curl -s -output curl_benchmark_test.log -H "$http_head" -u $i.test@kaya-labs.com:password -X POST -d "time=$now&lng=-97.7428&lat=30.2669&devs=$j Test:$uj,$k Test:$uk&user_dev=$i Test:$ui&lerror=1" ${url_root}/mposts 2>&1 ~/curl_benchmark_test.log
	curl -s -output curl_benchmark_test.log -H "$http_head" -u $j.test@kaya-labs.com:password -X POST -d "time=$now&lng=-97.7428&lat=30.2669&devs=$i Test:$ui,$k Test:$uk&user_dev=$j Test:$uj&lerror=1" ${url_root}/mposts 2>&1 ~/curl_benchmark_test.log
	curl -s -output curl_benchmark_test.log -H "$http_head" -u $k.test@kaya-labs.com:password -X POST -d "time=$now&lng=-97.7428&lat=30.2669&devs=$i Test:$ui,$j Test:$uj&user_dev=$k Test:$uk&lerror=1" ${url_root}/mposts 2>&1 ~/curl_benchmark_test.log

	@ round = $round + 1

	if (!($round % 30)) then
		set now = `date "+%Y-%m-%dT%H:%M:%S-08:00"`
		echo next round $round starting at $now
	endif
end
