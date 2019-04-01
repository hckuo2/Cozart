#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
mark_start;
service nginx start
sleep 3;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html;
done
service nginx stop
write_modules
mark_end;

