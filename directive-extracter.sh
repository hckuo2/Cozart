#!/bin/bash
source constant.sh
find $1 -name '*.c' -o -name '*.h' -o -name "*.S" | xargs grep -n "#if\|#else\|#endif" | sed 's/\/\*.*//' | rebase-linuxdir | sort -t: -k1,1 -k2n,2
