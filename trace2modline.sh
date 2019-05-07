#!/bin/bash

source lib.sh
distro=$1
tmp=$(mktemp)

get_module_file() {
    if ! find $vanillamoddir -type f | grep "/$1.ko" ;
    then
        mod=$(echo $1 | tr "_" "-")
        find $vanillamoddir -type f | grep "/$mod.ko"
    fi
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
    if [ -z "$modfile" ]
    then
        >&2 echo "Can not locate file for $mod"
    else
        echo $trace | tr " " "\n" | python3 ./offset_addr.py $offset | addrmod2lines $modfile
    fi
done<modules.tmp
} | sort | uniq
