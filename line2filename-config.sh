#!/bin/bash
awk -F ":" '{print $1}' | sort | uniq >touched-files.tmp
tmp=$(mktemp)
cut -d' ' -f1 filename.db > $tmp
grep -o -F -f $tmp touched-files.tmp | sort -k 1,1 | uniq | join -j 1 - <(sort -k 1,1 filename.db) | cut -d' ' -f2 \
    | sort | uniq
