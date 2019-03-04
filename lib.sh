#!/bin/bash

workdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
qemudir="$workdir/qemu"
qemubin="$qemudir/x86_64-softmmu/qemu-system-x86_64"
vanilla="compiled-kernels/allyes"
kerneldir="fiasco\\/"

rebase-kerneldir() {
    sed -r "s/.+$kerneldir/$kerneldir/"
}

