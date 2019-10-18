#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
bootstrap;

cd /benchmark-scripts/mysql-src
find . -name '*.gcda' -delete

rm /var/log/mysql/error.log /tmp/mysql.sock
/benchmark-scripts/mysql-src/bld/sql/mysqld --user=root 2>&1 | tee /benchmark-scripts/mysql-src/bld/slog &

sleep 10

sysbench --db-driver=mysql --test=oltp_read_write --mysql-socket=/tmp/mysql.sock run 2>&1 | tee /benchmark-scripts/mysql-src/bld/log

echo | pkill mysqld
sleep 10
sync

