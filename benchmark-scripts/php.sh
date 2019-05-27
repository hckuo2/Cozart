#!/bin/bash
itr=20
reqcnt=100000

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
randomd
mark_start;
for i in `seq $itr`; do
    php benchmark-scripts/phpbench.php
done
mark_end;
write_modules
