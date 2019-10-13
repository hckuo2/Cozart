#!/bin/bash
source benchmark-scripts/general-helper.sh

bootstrap;
cd /benchmark-scripts/redis-src
rm *.gcda
rm *.gcov
rm *.log
rm gmon.out

make test > mt.log 2>&1
cd src/
gcov -f -w -c -j * > gcov_fwcj.log 2>&1
sync
