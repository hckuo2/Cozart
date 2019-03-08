#!/bin/bash
awk -F ":" '{print $1}' | sort | uniq >touched-files.tmp
db=$(<filename.db)
touched=$(<touched-files.tmp)

tmp=$(mktemp)

cozart-search-filename() {
    key=$(echo $1 | cut -d' ' -f1)
    config=$(echo $1 | cut -d' ' -f2)
    if grep --word-regexp --fixed-strings $key touched-files.tmp > /dev/null; then
        echo $config
    fi
}
export -f cozart-search-filename

parallel --will-cite cozart-search-filename :::: filename.db >> $tmp

cat $tmp | sort | uniq
rm $tmp
