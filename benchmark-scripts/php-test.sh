#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
bootstrap
mark_start;
make -C benchmark-scripts/php-src test
mark_end;
write_modules
