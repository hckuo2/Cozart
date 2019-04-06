#!/bin/bash

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
rm -rf /run/docker* /var/run/docker*
docker_start
sleep 5;
docker container prune --force;
docker run hello-world;
write_modules
mark_end
