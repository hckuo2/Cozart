#!/bin/bash
itr=1
reqcnt=5000

source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
randomd
mark_start;
php benchmark-scripts/phpbench.php
mark_end;
write_modules
