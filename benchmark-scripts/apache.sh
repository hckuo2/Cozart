#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
rm -rf /var/run/apache2
apache2ctl start
sleep 3;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html;
done
apache2ctl stop;
mark_end;
write_modules
