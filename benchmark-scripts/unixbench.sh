#!/bin/bash
itr=20

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
cd /byte-unixbench/UnixBench
make clean
make
./Run -i $itr
cd /
write_modules
mark_end;

