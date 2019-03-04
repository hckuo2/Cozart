#!/bin/bash
source lib.sh

awk -F "," '{print $1}' | addr2line -e $vanilla/fiasco.debug | awk '{print $1}' \
    | rebase-kerneldir | sort | uniq
