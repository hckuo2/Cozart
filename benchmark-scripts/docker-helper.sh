#!/bin/sh

DIR="$( cd "$( dirname "$0" )" && pwd )"

docker_start() {
    dockerd &
    printf 'waiting for dockerd '
    until docker ps; do
        sleep 1;
        printf '.'
    done
}
