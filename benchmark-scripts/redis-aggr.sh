#!/bin/bash
source benchmark-scripts/general-helper.sh

bootstrap;
cd /benchmark-scripts/redis-src
rm *.gcda
rm *.gcov
rm *.log
rm gmon.out

make test > mt.log 2>&1
./runtest-cluster > cluster.log 2>&1
wait
make test-sentinel > mtsential.log 2>&1

gcov -f -w -c -j * > gcov_fwcj.log 2>&1
sync
