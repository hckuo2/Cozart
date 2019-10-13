#!/bin/bash

source benchmark-scripts/general-helper.sh
bootstrap;

cd /benchmark-scripts/memcached-src

rm *.gcda
rm *.gcov
rm *.log
rm gmon.out

./memcached-debug -u root -p 9132 &  > ser.log 2>&1
sleep 2;

../memtier_benchmark -p 9132 -P memcache_binary --requests=500  > ben.log 2>&1

gcov -a *  > gcov_fwcj.log 2>&1
pkill memcached-debug
sync
