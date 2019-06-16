#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
bootstrap
mark_start;
echo n | make -C benchmark-scripts/php-src test
mark_end;
write_modules
