#!/bin/bash
source helper.sh;

make trace-processor

trace-kernel() {
for itr in $(seq 10)
do
    $qemubin -trace exec_tb_block -smp 2 -m 8G -cpu kvm64 \
        -drive file="$workdir/qemu-disk.ext4,if=ide,format=raw" \
        -kernel "$bzImage" -nographic -no-reboot \
        -append "panic=-1 nokaslr console=ttyS0 root=/dev/sda rw init=/bench/native/run-$1.sh" \
        2>&1 1>stdout | ./bin/trace-parser > "uninverted-traces/$1.trace.$itr";
            # 2>&1 1>stdout | ./bin/trace-parser | ./bin/trace-inverter > traces-blk/$1.trace
done
    cat uninverted-traces/ls.trace.* | uniq | sort -k1 -n | ./bin/trace-inverter > traces-blk/ls.trace;
}
granularity=fake make select-blk;
trace-kernel "$1";

