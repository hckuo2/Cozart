#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
rm /var/log/mysql/error.log
service mysql restart || cat /var/log/mysql/error.log
sleep 10
for i in `seq $itr`; do
    sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write run
done
service mysql stop
write_modules
mark_end;

