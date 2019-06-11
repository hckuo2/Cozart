#!/bin/bash
apache() {
    echo apache-base,apache-cozart
    paste -d ',' \
        <(grep Requests apache.base.benchresult | awk '{print $4}') \
        <(grep Requests apache.cozart.benchresult | awk '{print $4}')
}

nginx() {
    echo nginx-base,nginx-cozart
    paste -d ',' \
        <(grep Requests nginx.base.benchresult | awk '{print $4}') \
        <(grep Requests nginx.cozart.benchresult | awk '{print $4}')
}
redis() { echo redis-get-base,redis-get-cozart,redis-set-base,redis-set-cozart
    paste -d ',' \
        <(grep GET redis.base.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep GET redis.cozart.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET redis.base.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET redis.cozart.benchresult | cut -d',' -f2 | tr -d '"')
}

memcached() {
    echo memcached-get-base,memcached-get-cozart,memcached-set-base,memcached-set-cozart
    paste -d ',' \
        <(grep Gets memcached.base.benchresult | awk '{print $2}') \
        <(grep Gets memcached.cozart.benchresult | awk '{print $2}') \
        <(grep Sets memcached.base.benchresult | awk '{print $2}') \
        <(grep Sets memcached.cozart.benchresult | awk '{print $2}')
}

mysql() {
    echo mysql-base,mysql-cozart
    paste -d ',' \
        <(grep "total:" mysql.base.benchresult | awk '{print $2}') \
        <(grep "total:" mysql.cozart.benchresult | awk '{print $2}')
}

cassandra() {
    echo cassandra-base,cassandra-cozart
    paste -d ',' \
        <(grep "Op rate" cassandra.base.benchresult | grep READ | awk '{print $4}' | tr -d ',') \
        <(grep "Op rate" cassandra.cozart.benchresult | grep READ | awk '{print $4}' | tr -d ',')
}

php() {
    echo php-base,php-cozart
    paste -d ',' \
        <(grep "Total time" php.base.benchresult | awk '{print $4}' | tr -d ',') \
        <(grep "Total time" php.cozart.benchresult | awk '{print $4}' | tr -d ',')
}

docker-apache() {
    echo docker-apache-base,docker-apache-cozart
    paste -d ',' \
        <(grep Requests docker-apache.base.benchresult | awk '{print $4}') \
        <(grep Requests docker-apache.cozart.benchresult | awk '{print $4}')
}
docker-nginx() {
    echo nginx-base,nginx-cozart
    paste -d ',' \
        <(grep Requests docker-nginx.base.benchresult | awk '{print $4}') \
        <(grep Requests docker-nginx.cozart.benchresult | awk '{print $4}')
}

docker-redis() {
    echo docker-redis-get-base,docker-redis-get-cozart,docker-redis-set-base,docker-redis-set-cozart
    paste -d ',' \
        <(grep GET docker-redis.base.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep GET docker-redis.cozart.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET docker-redis.base.benchresult | cut -d',' -f2 | tr -d '"') \
        <(grep SET docker-redis.cozart.benchresult | cut -d',' -f2 | tr -d '"')
}

docker-memcached() {
    echo docker-memcached-get-base,docker-memcached-get-cozart,docker-memcached-set-base,docker-memcached-set-cozart
    paste -d ',' \
        <(grep Gets docker-memcached.base.benchresult | awk '{print $2}') \
        <(grep Gets docker-memcached.cozart.benchresult | awk '{print $2}') \
        <(grep Sets docker-memcached.base.benchresult | awk '{print $2}') \
        <(grep Sets docker-memcached.cozart.benchresult | awk '{print $2}')
}

docker-mysql() {
    echo docker-mysql-base,docker-mysql-cozart
    paste -d ',' \
        <(grep "total:" docker-mysql.base.benchresult | awk '{print $2}') \
        <(grep "total:" docker-mysql.cozart.benchresult | awk '{print $2}')
}

docker-cassandra() {
    echo docker-cassandra-base,docker-cassandra-cozart
    paste -d ',' \
        <(grep "Op rate" docker-cassandra.base.benchresult | grep READ | awk '{print $4}' | tr -d ',') \
        <(grep "Op rate" docker-cassandra.cozart.benchresult | grep READ | awk '{print $4}' | tr -d ',')
}

paste -d ',' <($1) <($2) <($3) <($4) <($5) <($6) <($7)

