#!/bin/bash
reqcnt=500

source benchmark-scripts/general-helper.sh
bootstrap;
/benchmark-scripts/memcached-src/memcached-debug -u root --port=9111 &
sleep 2;
for i in `seq 10`; do
    /benchmark-scripts/memtier_benchmark -p 9111 -P memcache_binary \
        --requests=$reqcnt --hide-histogram
    for f in /benchmark-scripts/memcached-src/*.gc*; do
        mv $f $f.$i
    done
done
pkill memcached-debug
sync
