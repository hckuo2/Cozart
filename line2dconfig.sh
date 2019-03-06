#!/bin/bash
tmp=$(mktemp)
awk -F ":" '{print $1}' | sort | uniq >touched-drivers.tmp

while read line; do
	grep -w --fixed-strings $line filename.db | awk '{print $2}' >>$tmp
done <touched-drivers.tmp

cat $tmp | sort | uniq
rm $tmp
