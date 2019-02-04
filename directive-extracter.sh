#!/bin/bash
find $1 | xargs grep -n "#if\|#else\|#endif" | grep -v "ifndef" | sed 's/\/\*.*//' | sort -V
