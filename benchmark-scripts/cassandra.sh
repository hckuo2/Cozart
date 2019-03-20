#!/bin/bash
reqcnt=1000

source benchmark-scripts/general-helper.sh
mark_start;
mount_fs
enable_network;
randomd
# cleanup
rm -rf /var/lib/cassandra/commitlog/*
rm -rf /var/lib/cassandra/data/*
rm -rf /var/lib/cassandra/saved_caches/*
rm -rf /var/log/cassandra/*

cassandra -R &> /cassandra.log
sleep 15
cassandra-stress write n=$reqcnt -node localhost
cassandra-stress read n=$reqcnt -node localhost
write_modules
mark_end;
