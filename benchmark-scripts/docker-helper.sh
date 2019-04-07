#!/bin/sh

DIR="$( cd "$( dirname "$0" )" && pwd )"

docker_start() {
    rm -rf /run/docker* /var/run/docker*
    dockerd & > dockerd.log
    printf 'waiting for dockerd '
    until docker ps; do
        sleep 1;
        printf '.'
    done
}
