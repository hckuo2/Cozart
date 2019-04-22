#!/bin/bash
itr=20

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
docker_start
sleep 5;
docker container prune --force
sleep 5;
for i in `seq $itr`; do
    docker run -it --rm phpbench
done
write_modules
mark_end

