#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
bootstrap;

find /benchmark-scripts/nginx-src -name "*.gcda" -type f -delete

/benchmark-scripts/nginx-src/objs/nginx
sleep 3;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html 2>&1 | tee /benchmark-scripts/nginx-src/benchlog
done
pkill nginx
sync
