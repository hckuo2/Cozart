#!/bin/bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/arm-softmmu/qemu-system-arm"
linuxversion="rpi-4.14.y"
linuxdir="linux-$linuxversion"
vanillamoddir="compiled-kernels/raspberry/vanilla/"
cores="4"
mem="1024"
machine="raspi2"
distro="raspberry"

rebase-linuxdir() {
    sed -r "s/.+$linuxdir/$linuxdir/"
}

remove-dot-dir() {
    sed 's/\/\.\//\//'
}

