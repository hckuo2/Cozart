#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;

#rm -r /benchmark-scripts/php-src
#sync
#cp -r /benchmark-scripts/php-clean-src /benchmark-scripts/php-src
sync


cd /benchmark-scripts/php-src
find . -name "*.gcda" -type f -delete
echo $(pwd)

echo n | make test 2>&1 | tee /benchmark-scripts/php-src/log

sync
