#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
mount_fs
randomd
enable_network
mark_start
rm -rf /run/docker* /var/run/docker*
docker_start
sleep 5;
docker container prune --force;
docker run -dit --health-cmd='mysqladmin ping --silent' --name my-mysql-app -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:5.7

while [ $(docker inspect --format "{{json .State.Health.Status }}" my-mysql-app) != "\"healthy\"" ]; do
    printf ".";
    sleep 1;
done

mysql -h 0.0.0.0 -uroot -proot -e "create database sbtest;"
sysbench --mysql-host=0.0.0.0 --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write prepare
for i in `seq $itr`; do
    sysbench --mysql-host=0.0.0.0 --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write run
done
docker stop my-mysql-app
write_modules
mark_end

