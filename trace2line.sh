#!/bin/bash

rebase-linuxdir() {
    sed -r 's/.+linux-([0-9])+\.([0-9])+\.([0-9])+\///'
}

awk -F "," '{print $1}' | addr2line -e ./$1.vmlinux | awk '{print $1}' | \
    sed 's/\/\.\//\//' | rebase-linuxdir | sort --version-sort | uniq
