#!/bin/bash
source helper.sh;
make trace-processor
trace-kernel() {
    $qemubin -trace exec_tb_block -nographic -cdrom hello.iso 2> trace.tmp;
        # -initrd ../initramfs-vanilla \
    echo "Getting line information..."
    cat trace.tmp | ./bin/trace-parser | sort | uniq | ./trace2line.sh > lines.tmp
    echo "Getting kernel config imformation..."
    cat lines.tmp | ./line2kconfig.sh > kernel.config.tmp
    # echo "Getting driver config imformation..."
    # cat lines.tmp | ./line2dconfig.sh > driver.config.tmp
    # echo "Getting final config imformation..."
    # cat kernel.config.tmp driver.config.tmp | sort | uniq > imm0.config.tmp
    # cd $kerneldir && cp ../imm0.config.tmp .config && make olddefconfig && \
        # mv .config ../imm1.config.tmp && cd ..;
    # python3 filter-config.py $originalconfig "imm1.config.tmp" \
        # > $kerneldir/.config;
}
trace-kernel "$1";

