#!/bin/bash

source benchmark-scripts/general-helper.sh
mark_start;
mount_procfs;
enable_network;
sleep 3;
redis-server &
sleep 2;
for i in `seq 1`; do
    redis-benchmark -n 10000 -t SET,GET --csv
done
redis-cli shutdown
write_modules
mark_end;

