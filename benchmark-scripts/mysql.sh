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
    sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write prepare
    sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write run
    sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write cleanup
done
service mysql stop
write_modules
mark_end;

