#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
docker_start
sleep 5;
docker container prune --force;
docker run -dit --health-cmd='mysqladmin ping --silent' --name my-mysql-app -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root mysql:5.7
sleep 5;
while [ $(docker inspect --format "{{json .State.Health.Status }}" my-mysql-app) != "\"healthy\"" ]; do
    printf ".";
    sleep 3;
done
sleep 90;
mysql -h 0.0.0.0 -uroot -proot -e "create database sbtest;"
sysbench --mysql-host=0.0.0.0 --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write prepare
for i in `seq $itr`; do
    sysbench --mysql-host=0.0.0.0 --mysql-user=root --mysql-password=root --db-driver=mysql --test=oltp_read_write run
done
docker stop my-mysql-app
write_modules
mark_end

