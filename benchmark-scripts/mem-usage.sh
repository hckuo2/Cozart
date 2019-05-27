#!/usr/bin/env bash
source /benchmark-scripts/general-helper.sh
mount -t proc proc /proc;
cat /proc/meminfo | head -n1 | cut -f2
