#!/bin/bash
awk -F ":" '{print $1}' | sort | uniq >touched-files.tmp
awk -f substr-join.awk touched-files.tmp filename.db | sort | uniq
