#!/bin/bash

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
rm -rf /run/docker* /var/run/docker*
docker_start
docker pull httpd:2.4
docker pull nginx:1.15
docker pull mysql:5.7
docker pull memcached:1.5
docker pull redis:4.0
docker pull cassandra:3.11
docker pull tutum/unixbench
