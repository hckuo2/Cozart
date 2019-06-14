#!/bin/bash

source constant.sh
for disk in $disks; do
	sudo umount --recursive $mnt
	sudo mount -o loop $disk $mnt
	sudo rsync -avzu --progress -h $@ $mnt
	sudo umount --recursive $mnt
done
