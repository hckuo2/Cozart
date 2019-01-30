#!/bin/bash

awk -F "," '{print $1}' | addr2line -e ./$1.vmlinux | xargs realpath --relative-to=linux-4.19.16 | uniq
