#!/bin/bash
set -e
source lib.sh

trace() {
    make toggle-trace-mode
    for app in $@; do
        echo "Tracing $app"
        if [[ $app == "boot" ]]; then
            ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh;
        else
            ./trace-kernel.sh ubuntu /benchmark-scripts/$app.sh true;
        fi
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
        mkdir -p $workdir/compiled-kernels/ubuntu/$app
        INSTALL_PATH=$workdir/compiled-kernels/ubuntu/$app make install
        INSTALL_MOD_PATH=$workdir/compiled-kernels/ubuntu/$app make modules_install
        cd $workdir
        make install-kernel-modules
    done
    find $workdir/compiled-kernels -iname "*.old" | xargs rm -f
}

benchmark() {
    make toggle-benchmark-mode
    for app in $@; do
        echo "Benchmark $app on cozarted kernel"
        sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
        qemu/x86_64-softmmu/qemu-system-x86_64 -cpu $cpu -enable-kvm -smp $cores -m $mem \
            -kernel $workdir/compiled-kernels/ubuntu/$app/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > benchresult.$app.cozart.tmp;

        echo "Benchmark $app on vanilla kernel"
        sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
        qemu/x86_64-softmmu/qemu-system-x86_64 -cpu $cpu -enable-kvm -smp $cores -m $mem \
            -kernel $workdir/compiled-kernels/ubuntu/vanilla/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > benchresult.$app.vanilla.tmp;
    done
    dos2unix --force benchresult.*
}
action=$1

shift

$action $@;

