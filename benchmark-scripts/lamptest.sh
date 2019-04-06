#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
randomd
cp benchmark-scripts/lamptest.php /var/www/html/lamptest.php
rm -rf /var/run/apache2
service mysql start
apache2ctl start
sleep 3;
curl localhost:80/lamptest.php;
echo done
apache2ctl stop;
service mysql stop;
