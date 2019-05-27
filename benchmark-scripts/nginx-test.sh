#!/bin/bash

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
cd benchmark-scripts/nginx-tests
TEST_NGINX_MODULES=/usr/lib/nginx/modules TEST_NGINX_BINARY=`which nginx` prove .
write_modules
mark_end;

