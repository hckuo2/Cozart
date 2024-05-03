#!/bin/bash
source constant.sh
#Would you like to setup VALIDATE PASSWORD plugin? NO
#New password: root

#Re-enter new password: root

#Remove anonymous users? (Press y|Y for Yes, any other key for No) : NO
#Disallow root login remotely? (Press y|Y for Yes, any other key for No) : NO
#Remove test database and access to it? (Press y|Y for Yes, any other key for No) : NO
#Reload privilege tables now? (Press y|Y for Yes, any other key for No) : Y



$qemubin -cpu $cpu -enable-kvm -smp $cores -m $mem \
            -kernel $kernelbuild/$linux/$base/base/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/install-mysql.sh"

