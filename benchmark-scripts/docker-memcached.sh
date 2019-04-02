#!/bin/bash
itr=1
reqcnt=500

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
mark_start
mount_fs
randomd
enable_network
rm -rf /run/docker* /var/run/docker*
docker_start
sleep 5;
docker system prune --all --force;
docker run -dit --name my-memcached-app -p 11211:11211 memcached:1.5
for i in `seq $itr`; do
    /benchmark-scripts/memtier_benchmark -p 11211 -P memcache_binary \
        --requests=$reqcnt --hide-histogram
done
docker stop my-memcached-app
write_modules
mark_end

