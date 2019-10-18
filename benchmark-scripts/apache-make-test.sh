#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

find /benchmark-scripts/test-apache -name "*.gcda" -type f -delete
rm /benchmark-scripts/test-apache/httpd-2.4.39/log

sync
sleep 2;

cd /benchmark-scripts/test-apache/mod_perl-2.0.11/Apache-Test
runuser aptester -c "t/TEST" 2>&1 | tee /benchmark-scripts/test-apache/httpd-2.4.39/log

sync
