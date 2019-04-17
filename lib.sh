#!/bin/bash
workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/x86_64-softmmu/qemu-system-x86_64"
linuxversion="xenial"
linuxdir="linux-$linuxversion"
distro="ubuntu-xenial"
vanillamoddir="compiled-kernels/$distro/vanilla/"
# cpu="Skylake-Server"
cpu="kvm64"
cores="4"
mem="8G"

rebase-linuxdir() {
    sed -r "s/.+$linuxdir/$linuxdir/"
}

remove-dot-dir() {
    sed 's/\/\.\//\//'
}

