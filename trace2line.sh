#!/bin/bash
source lib.sh

addr2line -e ./$1.vmlinux | awk '{print $1}' |
    remove-dot-dir | rebase-linuxdir | sort --version-sort | uniq
