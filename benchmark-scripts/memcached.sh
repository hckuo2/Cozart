#!/bin/bash
itr=1
reqcnt=500

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
memcached -u root &
sleep 2;
for i in `seq $itr`; do
    /benchmark-scripts/memtier_benchmark -p 11211 -P memcache_binary \
        --requests=$reqcnt --hide-histogram
done
pkill memcached
write_modules
mark_end;

