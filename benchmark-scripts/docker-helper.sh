#!/bin/sh

DIR="$( cd "$( dirname "$0" )" && pwd )"

docker_start() {
    modprobe overlay;
    dockerd &
}
