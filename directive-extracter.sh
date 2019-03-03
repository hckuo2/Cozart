#!/bin/bash
source lib.sh
find $1 -name '*.c' -o -name '*.h' -o -name "*.S" | xargs grep -n "#if\|#else\|#endif" | sed 's/\/\*.*//' | rebase-linuxdir | sort -V
