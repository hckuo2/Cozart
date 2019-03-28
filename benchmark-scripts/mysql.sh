#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
mark_start;
mount_fs;
enable_network;
randomd
rm /var/log/mysql/error.log
sleep 3
service mysql restart || cat /var/log/mysql/error.log
sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write cleanup
sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write prepare
for i in `seq $itr`; do
    sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write run
done
sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write cleanup
service mysql stop
write_modules
mark_end;

