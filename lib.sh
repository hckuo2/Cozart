#!/bin/bash
workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/x86_64-softmmu/qemu-system-x86_64"
linuxversion="4.18.0"
linuxdir="linux-$linuxversion"
vanillamoddir="vanilla-modules"

rebase-linuxdir() {
    sed -r "s/.+$linuxdir/$linuxdir/"
}

remove-dot-dir() {
    sed 's/\/\.\//\//'
}

