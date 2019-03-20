#!/bin/bash
reqcnt=1000

source benchmark-scripts/general-helper.sh
mark_start;
mount_procfs;
mount_fs
enable_network;
randomd
cassandra -R &> /cassandra.log
sleep 5
cassandra-stress write n=$reqcnt -node localhost
cassandra-stress read n=$reqcnt -node localhost
write_modules
mark_end;
