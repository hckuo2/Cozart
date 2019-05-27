#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
cd /benchmark-scripts/memcached
make test
write_modules
mark_end;

