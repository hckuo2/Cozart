#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
mark_start;
redis-server --save "" --appendonly no &
sleep 2;
redis-cli FLUSHALL
for i in `seq $itr`; do
    redis-benchmark -n $reqcnt -t SET,GET --csv
done
redis-cli shutdown
write_modules
mark_end;

