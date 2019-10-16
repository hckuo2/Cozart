#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
pushd benchmark-scripts/redis-src/
./runtest-cluster
popd
make -C benchmark-scripts/redis-src/ test test-sentinel
write_modules
mark_end;
