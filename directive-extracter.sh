#!/bin/bash
find $1 -name '*.c' -o -name '*.h' -o -name "*.S" | xargs grep -n "#if\|#else\|#endif" | sed 's/\/\*.*//' | sort -V
