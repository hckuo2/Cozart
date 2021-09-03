#!/bin/sh
export PATH=$PATH:/usr/local/mysql/bin/
export PATH=$PATH:/usr/local/sbin/
export PATH=$PATH:/usr/sbin/
export PATH=$PATH:/sbin
mount_fs() {
    mount -t proc proc /proc;
    mount -t sysfs sys sys/
    mount -o bind /dev dev/
    mkdir -p /tmp;
    mount -t tmpfs tmpfs /tmp;
    cgroupfs-mount;
}

enable_network() {
    depmod
    modprobe e1000;
    hostname qemu
    echo "127.0.0.1  localhost.localdomain localhost" > /etc/hosts
    echo "127.0.1.1  qemu.localdomain qemu" >> /etc/hosts
    echo "nameserver 10.0.2.3" > /etc/resolv.conf;
    /sbin/ifconfig lo 127.0.0.1 netmask 255.0.0.0 up;
    /sbin/ifconfig eth0 up 10.0.2.15 netmask 255.255.255.0 up;
    /sbin/route add default gw 10.0.2.2;
    sleep 5;
}

mark_start() {
    ./mark
}

mark_end() {
    ./mark 1
}

randomd() {
    haveged start
}

write_modules() {
    cat /proc/modules > modules
    sync
}

bootstrap() {
    mount_fs;
    enable_network;
    randomd;
    write_modules;
    sleep 3;
}
