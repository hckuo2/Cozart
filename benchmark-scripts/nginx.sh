#!/bin/bash
itr=1
reqcnt=500

source benchmark-scripts/general-helper.sh
mark_start;
mount_procfs;
enable_network;
randomd
nginx &
sleep 3;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html;
done
pkill nginx
write_modules
mark_end;

