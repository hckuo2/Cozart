#!/bin/bash
set -e
source lib.sh

trace() {
    make toggle-trace-mode
    for app in $@; do
        echo "Tracing $app"
        ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh true;
        cp final.config.tmp config-db/ubuntu/$app.config
    done
}

aggregate() {
    for app in $@; do
        echo "Aggregate $app"
        ./aggregate-config.sh ubuntu boot $app
        cd $linuxdir
        make clean
        make -j`nproc` LOCALVERSION=-ubuntu-$app
        INSTALL_PATH=$workdir/compiled-kernels/ubuntu/$app make install
        cd $workdir
        make install-kernel-modules
    done
    rm $workdir/compiled-kernels/**/*.old;
}

benchmark() {
    make toggle-benchmark-mode
    for app in $@; do
        echo "Benchmark $app on vanilla kernel"
        qemu/x86_64-softmmu/qemu-system-x86_64 -cpu kvm64 -enable-kvm -smp 2 -m 8G \
            -kernel $workdir/compiled-kernels/ubuntu/vanilla/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > benchresult.$app.vanilla.tmp;
        echo "Benchmark $app on cozarted kernel"
        qemu/x86_64-softmmu/qemu-system-x86_64 -cpu kvm64 -enable-kvm -smp 2 -m 8G \
            -kernel $workdir/compiled-kernels/ubuntu/$app/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > benchresult.$app.cozart.tmp;
    done
}
action=$1

shift

$action $@;

