#!/bin/bash
source benchmark-scripts/general-helper.sh

bootstrap;
cd /benchmark-scripts/redis-src
rm *.gcda
rm *.gcov
rm *.log
rm gmon.out

make test 2>&1 | mt.log
./runtest-cluster 2>&1 | tee cluster.log
wait
make test-sentinel 2>&1 | tee mtsentinel.log

gcov -f -w -c -j * 2>&1 | tee gcov_fwcj.log
sync
