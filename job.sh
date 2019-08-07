#!/bin/bash
set -e
source constant.sh

trace() {
    make toggle-trace-mode
    for app in $@; do echo "Tracing $app"
        make clean
        if [[ $app == "boot" ]]; then
            ./trace-kernel.sh /benchmark-scripts/$app.sh;
        else
            ./trace-kernel.sh /benchmark-scripts/$app.sh true;
        fi
        mkdir -p config-db/$linux/$base
        cp final.config.tmp config-db/$linux/$base/$app.config
    done
}

decompose_app() {
    # this function is a helper for application stacks and has no effect for
    # single application
    echo $1 | tr '+' ' '
}

compose() {
    for app in $@; do
        echo "Aggregate $app"
        ./aggregate-config.sh \
            config-db/$linux/$base/base.config \
            config-db/$linux/$base/base-choice.config \
            config-db/$linux/$base/disable.config \
            config-db/$linux/$base/boot.config \
            $(locate_config_file $(decompose_app $app))
        cd $linux
        make clean
        make -j`nproc` LOCALVERSION=-$linux-$base-$app
        mkdir -p $kernelbuild/$linux/$base/$app
        INSTALL_PATH=$kernelbuild/$linux/$base/$app make install
        INSTALL_MOD_PATH=$kernelbuild/$linux/$base/$app make modules_install
        cd $workdir
        make install-kernel-modules
    done
    find $kernelbuild -iname "*.old" | xargs rm -f
}

compose-fc() {
    for app in $@; do
        echo "Aggregate $app"
        ./aggregate-config.sh \
            config-db/hypervisors/fc.config \
            $(locate_config_file $(decompose_app $app))
        cd $linux
        make clean
        make -j`nproc` LOCALVERSION=-fc-$app
        mkdir -p $kernelbuild/fc/$app
        INSTALL_PATH=$kernelbuild/fc/$app make install
        cd $workdir
    done
    find $kernelbuild -iname "*.old" | xargs rm -f
}

benchmark() {
    make toggle-benchmark-mode
    for app in $@; do
        echo "Benchmark $app on cozarted kernel"
        qemu-system-x86_64 -cpu $cpu -enable-kvm -smp $cores -m $mem \
            -kernel $kernelbuild/$linux/$base/$app-test/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > $app.cozart.benchresult;

        echo "Benchmark $app on base kernel"
       qemu-system-x86_64 -cpu $cpu -enable-kvm -smp $cores -m $mem \
            -kernel $kernelbuild/$linux/$base/base/vmlinuz* \
            -drive file="$(pwd)/qemu-disk.ext4",if=ide,format=raw \
            -nographic -no-reboot \
            -append "panic=-1 console=ttyS0 root=/dev/sda rw init=/benchmark-scripts/$app.sh" \
            > $app.base.benchresult;

       dos2unix --force $app.*.benchresult
    done
}

action=$1

shift

$action $@;

