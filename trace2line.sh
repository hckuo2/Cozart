#!/bin/bash

awk -F "," '{print $1}' | addr2line -e ./$1.vmlinux | awk '{print $1}' | uniq
