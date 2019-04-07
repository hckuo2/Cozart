#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
docker_start
sleep 5;
docker container prune --force;
docker run -dit --name my-redis-app -p 6379:6379 redis:4.0
sleep 5;
redis-cli FLUSHALL
for i in `seq $itr`; do
    redis-benchmark -n $reqcnt -t SET,GET --csv
done
docker stop my-redis-app
write_modules
mark_end

