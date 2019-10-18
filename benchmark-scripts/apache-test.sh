#!/bin/bash
source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
cd /benchmark-scripts/test-apache/mod_perl-2.0.11/Apache-Test
runuser aptester -c "t/TEST"
cd /
mark_end;
write_modules
