#!/bin/bash
find $1 -name '*.c' -o -name '*.h' | xargs grep -n "#if\|#endif" | sed 's/\/\*.*//' | sort
