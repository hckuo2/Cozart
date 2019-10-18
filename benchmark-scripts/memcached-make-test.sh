#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

cd /benchmark-scripts/memcached-src

rm *.gcda
rm *.gcov
rm *.log
rm gmon.out
sync
for i in `seq 1`; do
    make test > t.log 2>&1
    gcov -f -w -c -j * 2>&1 | tee gcov_fwcj.log
done
sync
