#!/bin/bash
itr=1

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
mark_start;
cd /byte-unixbench/UnixBench
make clean
make
./Run -i $itr
cd /
write_modules
mark_end;

