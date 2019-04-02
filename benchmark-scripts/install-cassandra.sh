#!/bin/bash
source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;

echo "deb http://www.apache.org/dist/cassandra/debian 311x main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list
apt install curl gnupg
apt-key adv --keyserver pool.sks-keyservers.net --recv-key A278B781FE4B2BDA
curl https://www.apache.org/dist/cassandra/KEYS | apt-key add -
apt-key adv --keyserver pool.sks-keyservers.net --recv-key A278B781FE4B2BDA
apt update
apt install cassandra -y
cassandra-stress write n=$reqcnt -node localhost -rate threads=4
