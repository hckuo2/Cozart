#!/bin/bash

source benchmark-scripts/general-helper.sh
mark_start;
randomd
rm -rf /var/run/apache2
/sbin/ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
apache2ctl start
sleep 3;
for i in `seq 1`; do
    ab -n 10000 -c 100 127.0.0.1:80/index.html;
done
apache2ctl stop;
mark_end;
