#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

find /benchmark-scripts/mysql-src -iname "*.gcda" -type f -delete
rm -rf /home/hckuo2/mysqltest
mkdir -p /home/hckuo2/mysqltest
chmod 777 -R /home/hckuo2/mysqltest
cd /benchmark-scripts/mysql-src/bld/mysql-test

runuser hckuo2 -c "./mysql-test-run --vardir=/home/hckuo2/mysqltest --force --test-progress --suite-timeout=7200 --testcase-timeout=600"
sleep 10; # wait for .gcda files
sync
