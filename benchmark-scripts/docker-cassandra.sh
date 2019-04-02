#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
mark_start
mount_fs
randomd
enable_network
rm -rf /run/docker* /var/run/docker*
docker_start
docker system prune --all --force;
docker run -dit --health-cmd="nodetool status" --name my-cassandra-app -p 7000:7000 -p 7199:7199 \
    -p 7001:7001 -p 9042:9042 -p 9160:9160 cassandra:3.11

while [ $(docker inspect --format "{{json .State.Health.Status }}" my-cassandra-app) != "\"healthy\"" ]; do
    printf ".";
    sleep 1;
done


cassandra-stress write n=$reqcnt -node localhost -rate threads=4
for i in `seq $itr`; do
    cassandra-stress mixed n=$reqcnt -node localhost -rate threads=4
done
docker stop my-cassandra-app
write_modules
mark_end
