#!/bin/bash
source lib.sh

awk -F "," '{print $1}' | addr2line -e ./$1.vmlinux | awk '{print $1}' |
    remove-dot-dir | rebase-linuxdir | sort --version-sort | uniq
