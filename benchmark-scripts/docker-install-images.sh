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
docker pull tutum/unixbench
cd benchmark-scripts;
docker build -t phpbench . -f Dockerfile.php
docker build -t cassandra:single . -f Dockerfile.cassandra
