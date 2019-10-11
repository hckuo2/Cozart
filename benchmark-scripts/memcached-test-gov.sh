#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

pushd /benchmark-scripts/memcached-src

for i in $(seq 10); do
    make test
    gcov -a *
    for f in *.gcov; do
        mv $f $f.$i
    done
done
