#!/bin/bash

source benchmark-scripts/general-helper.sh
bootstrap;

find /benchmark-scripts/nginx-src -name "*.gcda" -type f -delete

cd benchmark-scripts/nginx-tests
runuser aptester -c "TEST_NGINX_BINARY=../nginx-src/objs/nginx prove ." 2>&1 | tee /benchmark-scripts/nginx-src/testlog

sync
