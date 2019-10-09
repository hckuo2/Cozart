#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

pushd /benchmark-scripts/memcached-src
make test
gcov -a *
