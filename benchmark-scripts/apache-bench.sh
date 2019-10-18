#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
bootstrap;

cd /benchmark-scripts/test-apache
find /benchmark-scripts/test-apache -name "*.gcda" -type f -delete
rm /benchmark-scripts/test-apache/httpd-2.4.39/log
cd /

rm -rf /var/run/apache2
/benchmark-scripts/test-apache/httpd/prefork/bin/apachectl start
sleep 3;


for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html 2>&1 | tee /benchmark-scripts/test-apache/httpd-2.4.39/log
done
/benchmark-scripts/test-apache/httpd/prefork/bin/apachectl stop;
sync
