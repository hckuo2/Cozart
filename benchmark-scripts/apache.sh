#!/bin/sh

/sbin/ifconfig lo 127.0.0.1 netmask 255.0.0.0 up

rm -rf /var/run/apache2
mark_start;
apache2ctl start
sleep 3;
for i in `seq 10`; do
    ab -n 100000 -c 100 127.0.0.1:80/index.html;
done
apache2ctl stop;
mark_end;
