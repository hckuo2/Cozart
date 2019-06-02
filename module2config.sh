#!/bin/bash
source constant.sh
tmp=$(mktemp)

get_module_name() {
    cut -d' ' -f1
}

name2config() {
    find $linux -type f -name Makefile | xargs grep " $1\.o" \
        | grep --only-matching 'CONFIG_\([A-Z0-9_]\+\)'
}

get_module_name >> $tmp

touch module.config.tmp
truncate -s 0 module.config.tmp
while read mod; do
    name2config $mod
done <$tmp

