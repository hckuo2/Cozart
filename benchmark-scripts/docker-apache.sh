#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
bootstrap;
mark_start
docker_start
sleep 5;
docker container prune --force
docker run -dit --name my-apache-app -p 80:80 httpd:2.4
sleep 5;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 localhost:80/index.html;
done
docker stop my-apache-app
write_modules
mark_end

