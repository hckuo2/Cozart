#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
make -C benchmark-scripts/redis-src/ test test-sentinel
benchmark-scripts/redis-src/runtest-cluster
write_modules
mark_end;

