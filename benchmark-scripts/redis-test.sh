#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
make -C benchmark-scripts/redis-src/ test
write_modules
mark_end;

