#!/bin/bash
source helper.sh;
kerneldir="linux-4.19.16"
originalconfig="ubuntu.config"

make trace-processor
distro=$1

trace-kernel() {
    $qemubin -trace exec_tb_block -smp 2 -m 8G -cpu kvm64 \
        -drive file="$workdir/qemu-disk.ext4,if=ide,format=raw" \
        -kernel $distro.bzImage -nographic -no-reboot \
        -append "nokaslr panic=-1 console=ttyS0 root=/dev/sda rw"\
             2> trace.tmp;
        # -initrd ../initramfs-vanilla \
    echo "Getting line information..."
    cat trace.tmp | ./bin/trace-parser | sort | uniq | ./trace2line.sh $distro > lines.tmp
    echo "Getting kernel config imformation..."
    cat lines.tmp | ./line2kconfig.sh > kernel.config.tmp
    echo "Getting driver config imformation..."
    cat lines.tmp | ./line2dconfig.sh > driver.config.tmp
    echo "Getting final config imformation..."
    cat kernel.config.tmp driver.config.tmp | sort | uniq > imm0.config.tmp
    cd $kerneldir && cp ../imm0.config.tmp .config && make olddefconfig && \
        mv .config ../imm1.config.tmp && cd ..;
    python3 filter-config.py $originalconfig "imm1.config.tmp" \
        > $kerneldir/.config;
}
trace-kernel "$1";

