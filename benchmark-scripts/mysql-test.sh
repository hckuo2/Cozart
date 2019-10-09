#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
mkdir -p /home/hckuo2/mysqltest
chmod 777 -R /home/hckuo2/mysqltest
cd /usr/lib/mysql-test
runuser hckuo2 -c "./mysql-test-run --vardir=/home/hckuo2/mysqltest --force --test-progress --suite-timeout=7200 --testcase-timeout=600"
cd /
write_modules
mark_end;

