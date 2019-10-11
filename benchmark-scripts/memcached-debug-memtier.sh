#!/bin/bash
itr=1
reqcnt=500

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
/benchmark-scripts/memcached-src/memcached-debug -u root --port=9111 &
sleep 2;
for i in `seq $itr`; do
    /benchmark-scripts/memtier_benchmark -p 9111 -P memcache_binary \
        --requests=$reqcnt --hide-histogram
done
pkill memcached-debug
write_modules
mark_end;
