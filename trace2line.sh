#!/bin/bash

cd linux-4.19.16;
cat ../trace | awk -F "," "{print $1}" | addr2line -e ../vmlinux.vanilla | xargs realpath --relative-to=$(pwd) | uniq
cd ..
