#!/bin/bash
itr=1

source benchmark-scripts/general-helper.sh
mark_start;
mount_procfs;
mount_fs;
cd /byte-unixbench/UnixBench
./Run -i $itr
cd /
write_modules
mark_end;

