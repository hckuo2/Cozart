#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
pushd /benchmark-scripts/memcached
./autogen.sh && make
popd
mark_start;
pushd /benchmark-scripts/memcached
make test
write_modules
mark_end;

