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
    offset=$2
    addr=$3
    echo $(( addr - offset )) \
        | addr2line -e $modfile | cut -d' ' -f1 | remove-dot-dir \
        | rebase-linuxdir
}

declare -a files
declare -a offsets

i=0
while read line;
do
    mod=$(echo $line | get_module_name)
    offset=$(echo $line | get_module_addr)
    modfile=$(get_module_file $mod)
    files[$i]=$modfile
    offsets[$i]=$offset
    (( i++ ))
done <modules.tmp

modidx=0
while read line;
do
    addr=$(echo $line | awk -F "," '{print "0x" $1}')
    f=${files[$modidx]}
    o=${offsets[$modidx]}
    nexto=${offsets[((modidx+1))]}
    [[ $addr -lt $o ]] && continue
    [[ $addr -ge $nexto ]] && (( modidx++ ))
    addrmod2lines $f $o $addr
done | sort | uniq
