#!/bin/bash
source lib.sh

find $1 -name '*.cpp' -o -name '*.h' -o -name '*.c' -o -name '*.S' \
    | xargs grep -n "#if\|#else\|#endif" | grep -v "ifndef" \
    | sed 's/\/\*.*//' | rebase-kerneldir | sort -V | uniq
