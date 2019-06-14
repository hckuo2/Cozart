#!/bin/bash
export workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
export qemudir="$workdir/qemu"
export qemubin="$qemudir/x86_64-softmmu/qemu-system-x86_64"
export mnt="$workdir/mnt"
export disk="$workdir/qemu-disk.ext4"
export cpu="kvm64"
export cores="4"
export mem="8G"
export whoami=$(whoami)
export kernelbuild="$workdir/kernelbuild"

# Cozart constants
# A Linux version has multiple base configurations.
# A base configuration has multiple applications.
#

export linux="linux-5.1.9"
# default is the kernel defconfig

export base="fedora30"

rebase-linuxdir() {
    sed -r "s/.+$linux/$linux/"
}

remove-dot-dir() {
    sed 's/\/\.\//\//'
}

