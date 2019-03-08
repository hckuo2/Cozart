#!/bin/bash

source lib.sh
distro=$1
tmp=$(mktemp)

get_module_file() {
    find $vanillamoddir -type f | grep --fixed-strings "/$1.ko"
}

get_module_name() {
    cut -d' ' -f1
}

get_module_addr() {
    cut -d' ' -f6
}

addrmod2lines() {
    modfile=$1
    addr2line -e $modfile | cut -d' ' -f1 | remove-dot-dir \
        | rebase-linuxdir
}

declare -a files
declare -a offsets

trace=$(</dev/stdin)
{
while read line;
do
    mod=$(echo $line | get_module_name)
    offset=$(echo $line | get_module_addr)
    modfile=$(get_module_file $mod)
    echo $trace | tr " " "\n" | python3 ./offset_addr.py $offset | addrmod2lines $modfile
done<modules.tmp
} | sort | uniq
