#!/bin/bash
find $1 -type f | xargs grep -n "#if\|#else\|#endif" | grep -v "ifndef" \
    | sed 's/\/\*.*//' | sort -V
