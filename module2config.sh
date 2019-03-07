#!/bin/bash
source lib.sh
distro=$1
tmp=$(mktemp)

get_module_name() {
    cut -d' ' -f1
}

name2config() {
    find $linuxdir -type f -name Makefile | xargs grep " $1\.o" \
        | grep --only-matching 'CONFIG_\([A-Z0-9_]\+\)'
}

get_module_name >> $tmp

echo "" > module.config.tmp
while read mod; do
    name2config $mod
done <$tmp

