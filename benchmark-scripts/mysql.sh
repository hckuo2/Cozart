#!/bin/bash
itr=1
reqcnt=500

source benchmark-scripts/general-helper.sh
mark_start;
mount_procfs;
enable_network;
randomd
service mysql start
sleep 3;
for i in `seq $itr`; do
    mysqlslap --user=root --password=root --host=localhost  --auto-generate-sql --verbose --number-of-queries=$reqcnt --concurrency=20
done
service mysql stop
write_modules
mark_end;

