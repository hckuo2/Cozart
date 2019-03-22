#!/bin/bash
itr=1

source benchmark-scripts/general-helper.sh
mark_start;
mount_fs;
cd /byte-unixbench/UnixBench
make clean
make
./Run -i $itr
cd /
write_modules
mark_end;

