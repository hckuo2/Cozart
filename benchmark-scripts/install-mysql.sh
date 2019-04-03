#!/bin/bash
source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
apt -y remove dbconfig-mysql
apt -y remove --purge mysql*
apt -y autoremove
apt -y autoclean
rm -r /etc/mysql /var/lib/mysql
apt install -y sysbench mysql-server
service mysql start
mysql_secure_installation
mysql -uroot -proot -e "create database sbtest;"
sysbench --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write prepare
service mysql stop
sync;
