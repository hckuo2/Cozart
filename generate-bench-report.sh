#!/bin/bash
apache() {
    echo apache-vanilla apache-cozart
    paste -d ' ' \
        <(grep Requests benchresult.apache.vanilla.tmp | awk '{print $4}') \
        <(grep Requests benchresult.apache.cozart.tmp | awk '{print $4}')
}

nginx() {
    echo nginx-vanilla nginx-cozart
    paste -d ' ' \
        <(grep Requests benchresult.nginx.vanilla.tmp | awk '{print $4}') \
        <(grep Requests benchresult.nginx.cozart.tmp | awk '{print $4}')
}

redis() {
    echo redis-get-vanilla redis-get-cozart redis-set-vanilla redis-set-cozart
    paste -d ' ' \
        <(grep GET benchresult.redis.vanilla.tmp | cut -d',' -f2 | tr -d '"') \
        <(grep GET benchresult.redis.cozart.tmp | cut -d',' -f2 | tr -d '"') \
        <(grep SET benchresult.redis.vanilla.tmp | cut -d',' -f2 | tr -d '"') \
        <(grep SET benchresult.redis.cozart.tmp | cut -d',' -f2 | tr -d '"')
}

memcached() {
    echo memcached-get-vanilla memcached-get-cozart memcached-set-vanilla memcached-set-cozart
    paste -d ' ' \
        <(grep Gets benchresult.memcached.vanilla.tmp | awk '{print $2}') \
        <(grep Gets benchresult.memcached.cozart.tmp | awk '{print $2}') \
        <(grep Sets benchresult.memcached.vanilla.tmp | awk '{print $2}') \
        <(grep Sets benchresult.memcached.cozart.tmp | awk '{print $2}')
}

mysql() {
    echo mysql-vanilla mysql-cozart
    paste -d ' ' \
        <(grep "total:" benchresult.mysql.vanilla.tmp | awk '{print $2}') \
        <(grep "total:" benchresult.mysql.cozart.tmp | awk '{print $2}')
}

cassandra() {
    echo cassandra-vanilla cassandra-cozart
    paste -d ' ' \
        <(grep "Op rate" benchresult.cassandra.vanilla.tmp | grep READ | awk '{print $4}' | tr -d ',') \
        <(grep "Op rate" benchresult.cassandra.cozart.tmp | grep READ | awk '{print $4}' | tr -d ',')
}
paste -d ' ' <($1) <($2) <($3) <($4) <($5) <($6) <($7)
