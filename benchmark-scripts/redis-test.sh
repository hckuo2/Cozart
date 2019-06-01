#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
redis-server &
sleep 2;
redis-cli FLUSHALL
redis-benchmark -n 100 --csv
redis-cli shutdown
write_modules
mark_end;

