#!/bin/bash

echo apache-vanilla apache-cozart \
    redis-get-vanilla redis-get-cozart redis-set-vanilla redis-set-cozart \
    memcached-get-vanilla memcached-get-cozart memcached-set-vanilla memcached-set-cozart

paste -d ' ' \
    <(grep Requests benchresult.apache.vanilla.tmp | awk '{print $4}') \
    <(grep Requests benchresult.apache.cozart.tmp | awk '{print $4}') \
    <(grep GET benchresult.redis.vanilla.tmp | cut -d',' -f2 | tr -d '"') \
    <(grep GET benchresult.redis.cozart.tmp | cut -d',' -f2 | tr -d '"') \
    <(grep SET benchresult.redis.vanilla.tmp | cut -d',' -f2 | tr -d '"') \
    <(grep SET benchresult.redis.cozart.tmp | cut -d',' -f2 | tr -d '"') \
    <(grep Gets benchresult.memcached.vanilla.tmp | awk '{print $2}') \
    <(grep Gets benchresult.memcached.cozart.tmp | awk '{print $2}') \
    <(grep Sets benchresult.memcached.vanilla.tmp | awk '{print $2}') \
    <(grep Sets benchresult.memcached.cozart.tmp | awk '{print $2}')

