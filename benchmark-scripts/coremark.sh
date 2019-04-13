#!/bin/bash
itr=1

source benchmark-scripts/general-helper.sh
bootstrap;
mark_start;
cd /benchmark-scripts/coremark
make
cat run1.log run2.log
cd /
mark_end;

