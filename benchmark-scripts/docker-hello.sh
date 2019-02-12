#!/bin/bash

source benchmark-scripts/general-helper.sh
source benchmark-scripts/docker-helper.sh
mark_start
mount_fs
haveged &
enable_network
rm -rf run/docker* var/run/docker*
dockerd &
docker run hello-world
mark_end
