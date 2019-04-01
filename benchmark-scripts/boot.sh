#!/bin/bash
source benchmark-scripts/general-helper.sh
mount_fs;
enable_network;
randomd
write_modules
echo "Boot success!"
exit 0

