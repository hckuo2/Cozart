#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
mount_fs
randomd
enable_network
mark_start
rm -rf /run/docker* /var/run/docker*
docker_start
docker container prune --force;
docker run -dit --name my-cassandra-app -p 7000:7000 -p 7199:7199 \
    -p 7001:7001 -p 9042:9042 -p 9160:9160 cassandra:single

until docker logs --tail 5 my-cassandra-app | grep "CQL clients on"; do
    echo "Waiting for cassandra"
    sleep 3
done

cassandra-stress write n=$reqcnt -node localhost -rate threads=4
for i in `seq $itr`; do
    cassandra-stress mixed n=$reqcnt -node localhost -rate threads=4
done
docker stop my-cassandra-app
write_modules
mark_end
