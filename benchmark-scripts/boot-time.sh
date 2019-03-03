#!/bin/bash
mount -t proc proc /proc
echo -e "\nBoot took $(cut -d' ' -f1 /proc/uptime) seconds\n"
