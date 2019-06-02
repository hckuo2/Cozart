#!/bin/bash
source constant.sh

addr2line -e $kernelbuild/$linux/$base/base/vmlinux | awk '{print $1}' |
    remove-dot-dir | rebase-linuxdir | sort --version-sort | uniq
