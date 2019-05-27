#!/bin/bash
itr=20
reqcnt=10000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
docker_start
sleep 5;
docker container prune --force;
docker run -dit --name my-memcached-app -p 11211:11211 memcached:1.5
sleep 5;
for i in `seq $itr`; do
    /benchmark-scripts/memtier_benchmark -p 11211 -P memcache_binary \
        --requests=$reqcnt --hide-histogram
done
docker stop my-memcached-app
write_modules
mark_end

