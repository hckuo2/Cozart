#!/bin/bash
workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/aarch64-softmmu/qemu-system-aarch64"
linuxversion="rpi-4.14.y"
linuxdir="linux-$linuxversion"
vanillamoddir="compiled-kernels/raspberry/vanilla/"
cpu="cortex-a15"
cores="4"
mem="1024"
machine="raspi3"
distro="raspberry"

rebase-linuxdir() {
    sed -r "s/.+$linuxdir/$linuxdir/"
}

remove-dot-dir() {
    sed 's/\/\.\//\//'
}

