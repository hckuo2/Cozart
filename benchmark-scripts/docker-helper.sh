#!/bin/sh

DIR="$( cd "$( dirname "$0" )" && pwd )"

docker_start() {
    dockerd &
}
