#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
pushd /benchmark-scripts/memcached-src
make test
write_modules
mark_end;

