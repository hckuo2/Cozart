#!/bin/bash
apache() {
    echo apache-vanilla,apache-cozart
    paste -d ',' \
        <(grep Requests apache.vanilla.benchresult | awk '{print $4}') \
        <(grep Requests apache.cozart.benchresult | awk '{print $4}')
}

nginx() {
    echo nginx-vanilla,nginx-cozart
    paste -d ',' \
        <(grep Requests nginx.vanilla.benchresult | awk '{print $4}') \
        <(grep Requests nginx.cozart.benchresult | awk '{print $4}')
}

redis() {
    echo redis-get-vanilla,redis-get-cozart,redis-set-vanilla,redis-set-cozart
    paste -d ',' \
        <(grep GET redis.vanilla.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep GET redis.cozart.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET redis.vanilla.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET redis.cozart.benchresult | cut -d',' -f2 | tr -d '"')
}

memcached() {
    echo memcached-get-vanilla,memcached-get-cozart,memcached-set-vanilla,memcached-set-cozart
    paste -d ',' \
        <(grep Gets memcached.vanilla.benchresult | awk '{print $2}') \
        <(grep Gets memcached.cozart.benchresult | awk '{print $2}') \
        <(grep Sets memcached.vanilla.benchresult | awk '{print $2}') \
        <(grep Sets memcached.cozart.benchresult | awk '{print $2}')
}

mysql() {
    echo mysql-vanilla,mysql-cozart
    paste -d ',' \
        <(grep "total:" mysql.vanilla.benchresult | awk '{print $2}') \
        <(grep "total:" mysql.cozart.benchresult | awk '{print $2}')
}

cassandra() {
    echo cassandra-vanilla,cassandra-cozart
    paste -d ',' \
        <(grep "Op rate" cassandra.vanilla.benchresult | grep READ | awk '{print $4}' | tr -d ',') \
        <(grep "Op rate" cassandra.cozart.benchresult | grep READ | awk '{print $4}' | tr -d ',')
}
docker-apache() {
    echo docker-apache-vanilla,docker-apache-cozart
    paste -d ',' \
        <(grep Requests docker-apache.vanilla.benchresult | awk '{print $4}') \
        <(grep Requests docker-apache.cozart.benchresult | awk '{print $4}')
}
docker-nginx() {
    echo nginx-vanilla,nginx-cozart
    paste -d ',' \
        <(grep Requests docker-nginx.vanilla.benchresult | awk '{print $4}') \
        <(grep Requests docker-nginx.cozart.benchresult | awk '{print $4}')
}

docker-redis() {
    echo docker-redis-get-vanilla,docker-redis-get-cozart,docker-redis-set-vanilla,docker-redis-set-cozart
    paste -d ',' \
        <(grep GET docker-redis.vanilla.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep GET docker-redis.cozart.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET docker-redis.vanilla.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET docker-redis.cozart.benchresult | cut -d',' -f2 | tr -d '"')
}

docker-memcached() {
    echo docker-memcached-get-vanilla,docker-memcached-get-cozart,docker-memcached-set-vanilla,docker-memcached-set-cozart
    paste -d ',' \
        <(grep Gets docker-memcached.vanilla.benchresult | awk '{print $2}') \
        <(grep Gets docker-memcached.cozart.benchresult | awk '{print $2}') \
        <(grep Sets docker-memcached.vanilla.benchresult | awk '{print $2}') \
        <(grep Sets docker-memcached.cozart.benchresult | awk '{print $2}')
}

docker-mysql() {
    echo docker-mysql-vanilla,docker-mysql-cozart
    paste -d ',' \
        <(grep "total:" docker-mysql.vanilla.benchresult | awk '{print $2}') \
        <(grep "total:" docker-mysql.cozart.benchresult | awk '{print $2}')
}

docker-cassandra() {
    echo docker-cassandra-vanilla,docker-cassandra-cozart
    paste -d ',' \
        <(grep "Op rate" docker-cassandra.vanilla.benchresult | grep READ | awk '{print $4}' | tr -d ',') \
        <(grep "Op rate" docker-cassandra.cozart.benchresult | grep READ | awk '{print $4}' | tr -d ',')
}

paste -d ',' <($1) <($2) <($3) <($4) <($5) <($6) <($7)

