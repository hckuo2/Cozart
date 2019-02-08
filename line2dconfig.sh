#!/bin/bash

awk -F ":" '{print $1}' | sort | uniq > touched-drivers.tmp;

while read line
do
    grep $line filename.db | awk '{print $2}' >> driver-config.tmp
done < touched-drivers.tmp

cat driver-config.tmp  | sort | uniq | python3 include-dep.py | sort | uniq
rm driver-config.tmp
