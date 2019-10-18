#!/bin/bash
source /benchmark-scripts/general-helper.sh
bootstrap;
pwd

#rm -r /benchmark-scripts/php-src
#sync
#cp -r /benchmark-scripts/php-clean-src /benchmark-scripts/php-src
#sync
cd /benchmark-scripts/php-src
find . -name "*.gcda" -type f -delete
/benchmark-scripts/php-src/sapi/cli/php -d max_execution_time=5400 /benchmark-scripts/phpbench.php 2>&1 | tee /benchmark-scripts/php-src/log

sync
