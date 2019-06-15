#!/bin/bash
source constant.sh
sudo umount --recursive $mnt
sudo mount -o loop $disk $mnt
sudo rsync -avzu --progress -h $@ $mnt
sudo umount --recursive $mnt
